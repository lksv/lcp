require "spec_helper"
require "support/integration_helper"

RSpec.describe "Advanced Search Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("advanced_search")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("advanced_search")
  end

  before(:each) do
    load_integration_metadata!("advanced_search")
    product_model.delete_all
    category_model.delete_all
  end

  let(:product_model) { LcpRuby.registry.model_for("product") }
  let(:category_model) { LcpRuby.registry.model_for("category") }

  describe "Quick search with ?qs= param" do
    before { stub_current_user(role: "admin") }

    it "filters by string field" do
      product_model.create!(name: "Red Widget")
      product_model.create!(name: "Blue Gadget")

      get "/products", params: { qs: "Widget" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Red Widget")
      expect(response.body).not_to include("Blue Gadget")
    end

    it "filters by text field (description)" do
      product_model.create!(name: "Product AAA", description: "Amazing product for everyone")
      product_model.create!(name: "Product BBB", description: "Basic item")

      get "/products", params: { qs: "Amazing" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Product AAA")
      expect(response.body).not_to include("Product BBB")
    end

    it "returns no results for non-matching query" do
      product_model.create!(name: "Red Widget")

      get "/products", params: { qs: "ZZZ_NONEXISTENT" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Red Widget")
    end

    it "returns all results when qs is empty" do
      product_model.create!(name: "Alpha Product")
      product_model.create!(name: "Beta Product")

      get "/products", params: { qs: "" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alpha Product")
      expect(response.body).to include("Beta Product")
    end
  end

  describe "Type-aware quick search" do
    before { stub_current_user(role: "admin") }

    it "matches integer field with numeric query" do
      product_model.create!(name: "Qty100 Product", quantity: 100)
      product_model.create!(name: "Qty200 Product", quantity: 200)

      # "100" matches quantity=100 AND also matches "Qty100" in name via LIKE
      get "/products", params: { qs: "100" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Qty100 Product")
    end

    it "matches enum by stored value" do
      product_model.create!(name: "Published Product", status: "published")
      product_model.create!(name: "Draft Product", status: "draft")

      get "/products", params: { qs: "published" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Published Product")
    end

    it "matches by SKU string field" do
      product_model.create!(name: "Product Alpha", sku: "SKU-001")
      product_model.create!(name: "Product Beta", sku: "SKU-002")

      get "/products", params: { qs: "SKU-001" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Product Alpha")
      expect(response.body).not_to include("Product Beta")
    end
  end

  describe "Ransack filter via ?f[...] params" do
    before { stub_current_user(role: "admin") }

    it "filters with equals operator" do
      product_model.create!(name: "Widget Alpha", status: "published")
      product_model.create!(name: "Widget Beta", status: "draft")

      get "/products", params: { f: { status_eq: "published" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Widget Alpha")
      expect(response.body).not_to include("Widget Beta")
    end

    it "filters with contains operator" do
      product_model.create!(name: "Super Widget")
      product_model.create!(name: "Basic Gadget")

      get "/products", params: { f: { name_cont: "Widget" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Super Widget")
      expect(response.body).not_to include("Basic Gadget")
    end

    it "filters with numeric comparison" do
      product_model.create!(name: "Cheap Product", price: 9.99)
      product_model.create!(name: "Expensive Product", price: 199.99)

      get "/products", params: { f: { price_gteq: "100" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Expensive Product")
      expect(response.body).not_to include("Cheap Product")
    end

    it "combines multiple filter conditions" do
      product_model.create!(name: "Published Cheap", status: "published", price: 10.0)
      product_model.create!(name: "Published Expensive", status: "published", price: 500.0)
      product_model.create!(name: "Draft Cheap", status: "draft", price: 10.0)

      get "/products", params: { f: { status_eq: "published", price_gteq: "100" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Published Expensive")
      expect(response.body).not_to include("Published Cheap")
      expect(response.body).not_to include("Draft Cheap")
    end
  end

  describe "Association filter" do
    before { stub_current_user(role: "admin") }

    it "filters by association field" do
      electronics = category_model.create!(name: "Electronics")
      clothing = category_model.create!(name: "Clothing")

      product_model.create!(name: "Laptop", category_id: electronics.id)
      product_model.create!(name: "T-Shirt", category_id: clothing.id)

      get "/products", params: { f: { category_name_cont: "Electronics" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Laptop")
      expect(response.body).not_to include("T-Shirt")
    end
  end

  describe "Nested association filter (depth 2)" do
    before { stub_current_user(role: "admin") }

    it "filters by self-referential parent association field" do
      technology = category_model.create!(name: "Technology")
      business = category_model.create!(name: "Business")
      web_dev = category_model.create!(name: "Web Development", parent_id: technology.id)
      startups = category_model.create!(name: "Startups", parent_id: business.id)

      product_model.create!(name: "Web Framework", category_id: web_dev.id)
      product_model.create!(name: "Startup Tool", category_id: startups.id)
      product_model.create!(name: "Top Level Product", category_id: technology.id)

      get "/products", params: { f: { category_parent_name_cont: "Tech" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Web Framework")
      expect(response.body).not_to include("Startup Tool")
      expect(response.body).not_to include("Top Level Product")
    end

    it "filters by nested association with equals operator" do
      parent = category_model.create!(name: "Electronics")
      child = category_model.create!(name: "Phones", parent_id: parent.id)

      product_model.create!(name: "iPhone", category_id: child.id)
      product_model.create!(name: "Headphones", category_id: parent.id)

      get "/products", params: { f: { category_parent_name_eq: "Electronics" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("iPhone")
      expect(response.body).not_to include("Headphones")
    end

    it "combines nested association filter with direct field filter" do
      tech = category_model.create!(name: "Technology")
      web = category_model.create!(name: "Web Dev", parent_id: tech.id)

      product_model.create!(name: "Published Web Tool", category_id: web.id, status: "published")
      product_model.create!(name: "Draft Web Tool", category_id: web.id, status: "draft")

      get "/products", params: { f: { category_parent_name_cont: "Tech", status_eq: "published" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Published Web Tool")
      expect(response.body).not_to include("Draft Web Tool")
    end

    it "returns all records when nested association filter value matches nothing" do
      parent = category_model.create!(name: "Electronics")
      child = category_model.create!(name: "Phones", parent_id: parent.id)
      product_model.create!(name: "iPhone", category_id: child.id)

      get "/products", params: { f: { category_parent_name_cont: "NONEXISTENT" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("iPhone")
    end

    it "includes nested association field in filter metadata" do
      product_model.create!(name: "Test Product")

      get "/products"

      metadata_match = response.body.match(/data-lcp-filter-metadata="([^"]*)"/)
      metadata = JSON.parse(CGI.unescapeHTML(metadata_match[1]))

      parent_field = metadata["fields"].find { |f| f["name"] == "category.parent.name" }
      expect(parent_field).not_to be_nil
      expect(parent_field["group"]).to eq("Category > Parent")
      expect(parent_field["type"]).to eq("string")
    end
  end

  describe "Predefined filter + Ransack filter combined" do
    before { stub_current_user(role: "admin") }

    it "applies predefined filter and Ransack filter together" do
      product_model.create!(name: "Active Published", active: true, status: "published", price: 50.0)
      product_model.create!(name: "Active Draft", active: true, status: "draft", price: 50.0)
      product_model.create!(name: "Inactive Published", active: false, status: "published", price: 50.0)

      get "/products", params: { filter: "active", f: { status_eq: "published" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Active Published")
      expect(response.body).not_to include("Active Draft")
      expect(response.body).not_to include("Inactive Published")
    end
  end

  describe "Quick search + Ransack filter combined" do
    before { stub_current_user(role: "admin") }

    it "applies both quick search and Ransack filter" do
      product_model.create!(name: "Widget Pro", status: "published")
      product_model.create!(name: "Widget Basic", status: "draft")
      product_model.create!(name: "Gadget Pro", status: "published")

      get "/products", params: { qs: "Widget", f: { status_eq: "published" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Widget Pro")
      expect(response.body).not_to include("Widget Basic")
      expect(response.body).not_to include("Gadget Pro")
    end
  end

  describe "Empty params don't break queries" do
    before { stub_current_user(role: "admin") }

    it "handles empty f params gracefully" do
      product_model.create!(name: "Test Product")

      get "/products", params: { f: { name_cont: "" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Product")
    end

    it "handles nil f params gracefully" do
      product_model.create!(name: "Test Product")

      get "/products"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Product")
    end
  end

  describe "Permission-restricted filtering" do
    it "allows filtering on readable fields for viewer" do
      stub_current_user(role: "viewer")

      product_model.create!(name: "Visible Widget", status: "published")
      product_model.create!(name: "Visible Gadget", status: "draft")

      get "/products", params: { f: { status_eq: "published" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Widget")
      expect(response.body).not_to include("Visible Gadget")
    end

    it "rejects filtering on non-readable fields for viewer" do
      stub_current_user(role: "viewer")

      product_model.create!(name: "Product A", price: 100.0)
      product_model.create!(name: "Product B", price: 200.0)

      # price is not in viewer's readable fields, so Ransack should reject it
      get "/products", params: { f: { price_gteq: "150" } }

      expect(response).to have_http_status(:ok)
      # Both products should appear since the price filter is ignored
      expect(response.body).to include("Product A")
      expect(response.body).to include("Product B")
    end
  end

  describe "Custom filter_* method interception" do
    before { stub_current_user(role: "admin") }

    it "calls custom filter method when defined on model" do
      product_model.create!(name: "High Value Product", price: 500.0)
      product_model.create!(name: "Low Value Product", price: 10.0)

      # Define a custom filter method on the model
      product_model.define_singleton_method(:filter_min_price) do |scope, value, _evaluator|
        scope.where("price >= ?", value.to_f)
      end

      get "/products", params: { f: { min_price: "100" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("High Value Product")
      expect(response.body).not_to include("Low Value Product")
    end
  end

  describe "Ransackable attributes authorization" do
    it "exposes all columns without auth_object" do
      load_integration_metadata!("advanced_search")
      model = LcpRuby.registry.model_for("product")
      expect(model.ransackable_attributes).to include("name", "price", "quantity", "status")
    end

    it "restricts to readable fields with evaluator" do
      load_integration_metadata!("advanced_search")
      model = LcpRuby.registry.model_for("product")
      perm_def = LcpRuby.loader.permission_definition("product")
      user = OpenStruct.new(id: 1, lcp_role: ["viewer"])
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "product")

      attrs = model.ransackable_attributes(evaluator)
      expect(attrs).to include("name", "status", "sku")
      expect(attrs).not_to include("price", "quantity", "weight")
    end

    it "includes association in ransackable_associations" do
      load_integration_metadata!("advanced_search")
      model = LcpRuby.registry.model_for("product")
      expect(model.ransackable_associations).to include("category")
    end
  end

  describe "Advanced filter partial rendering" do
    it "renders the advanced filter partial when enabled" do
      stub_current_user(role: "admin")
      product_model.create!(name: "Test Product")

      get "/products"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-advanced-filter")
      expect(response.body).to include("data-lcp-filter-metadata")
      expect(response.body).to include("data-lcp-filter-action")
    end

    it "does NOT render the advanced filter partial when search is disabled" do
      stub_current_user(role: "admin")
      product_model.create!(name: "Test Product")

      # Override the category presenter (search not configured with advanced_filter)
      category_model.create!(name: "Test Category")
      get "/categories"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("data-lcp-filter-metadata")
    end

    it "includes filter metadata JSON with expected field structure" do
      stub_current_user(role: "admin")
      product_model.create!(name: "Test Product")

      get "/products"

      # Extract metadata JSON from the data attribute
      metadata_match = response.body.match(/data-lcp-filter-metadata="([^"]*)"/)
      expect(metadata_match).not_to be_nil

      metadata_json = CGI.unescapeHTML(metadata_match[1])
      metadata = JSON.parse(metadata_json)

      expect(metadata["fields"]).to be_an(Array)
      expect(metadata["fields"].length).to be > 0

      # Check a direct field
      name_field = metadata["fields"].find { |f| f["name"] == "name" }
      expect(name_field).not_to be_nil
      expect(name_field["type"]).to eq("string")
      expect(name_field["operators"]).to be_an(Array)
      expect(name_field["operators"]).to include("eq", "cont")
      expect(name_field["group"]).to be_nil

      # Check an enum field
      status_field = metadata["fields"].find { |f| f["name"] == "status" }
      expect(status_field).not_to be_nil
      expect(status_field["type"]).to eq("enum")
      expect(status_field["enum_values"]).to be_an(Array)
      expect(status_field["enum_values"].first).to eq(["draft", "Draft"])

      # Check operator labels
      expect(metadata["operator_labels"]).to be_a(Hash)
      expect(metadata["operator_labels"]["eq"]).to eq("equals")

      # Check config
      expect(metadata["config"]["max_conditions"]).to eq(10)
    end

    it "includes association fields in metadata with correct group" do
      stub_current_user(role: "admin")
      product_model.create!(name: "Test Product")

      get "/products"

      metadata_match = response.body.match(/data-lcp-filter-metadata="([^"]*)"/)
      metadata = JSON.parse(CGI.unescapeHTML(metadata_match[1]))

      category_field = metadata["fields"].find { |f| f["name"] == "category.name" }
      expect(category_field).not_to be_nil
      expect(category_field["group"]).to eq("Category")
      expect(category_field["type"]).to eq("string")
    end

    it "restricts visible fields in metadata based on viewer permissions" do
      stub_current_user(role: "viewer")
      product_model.create!(name: "Test Product")

      get "/products"

      metadata_match = response.body.match(/data-lcp-filter-metadata="([^"]*)"/)
      metadata = JSON.parse(CGI.unescapeHTML(metadata_match[1]))

      field_names = metadata["fields"].map { |f| f["name"] }
      expect(field_names).to include("name")
      expect(field_names).to include("status")
      # price is not in viewer's readable fields
      expect(field_names).not_to include("price")
      # category_id FK is not readable by viewer
      expect(field_names).not_to include("category.name")
    end

    it "includes filter count badge when active filters exist" do
      stub_current_user(role: "admin")
      product_model.create!(name: "Test Product", status: "published")

      get "/products", params: { f: { status_eq: "published" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-filter-count")
    end
  end

  describe "Filter presets in metadata" do
    before { stub_current_user(role: "admin") }

    it "includes presets in filter metadata" do
      product_model.create!(name: "Test Product")

      get "/products"

      metadata_match = response.body.match(/data-lcp-filter-metadata="([^"]*)"/)
      metadata = JSON.parse(CGI.unescapeHTML(metadata_match[1]))

      expect(metadata["presets"]).to be_an(Array)
      expect(metadata["presets"].length).to eq(2)

      first_preset = metadata["presets"][0]
      expect(first_preset["name"]).to eq("expensive_active")
      expect(first_preset["label"]).to eq("Expensive & active")
      expect(first_preset["conditions"]).to be_an(Array)
      expect(first_preset["conditions"].length).to eq(2)
      expect(first_preset["conditions"][0]["field"]).to eq("price")
      expect(first_preset["conditions"][0]["operator"]).to eq("gteq")
    end

    it "applies preset conditions as Ransack params" do
      product_model.create!(name: "Expensive Active", price: 200.0, active: true)
      product_model.create!(name: "Cheap Active", price: 10.0, active: true)
      product_model.create!(name: "Expensive Inactive", price: 200.0, active: false)

      # Simulate what the JS does: translate preset conditions to Ransack params
      get "/products", params: { f: { price_gteq: "100", active_true: "1" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Expensive Active")
      expect(response.body).not_to include("Cheap Active")
      expect(response.body).not_to include("Expensive Inactive")
    end

    it "applies single-condition preset" do
      product_model.create!(name: "Draft Widget", status: "draft")
      product_model.create!(name: "Published Widget", status: "published")

      # Simulate the "Draft products" preset
      get "/products", params: { f: { status_eq: "draft" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Draft Widget")
      expect(response.body).not_to include("Published Widget")
    end
  end

  describe "Custom field filtering with ?cf[...] params" do
    before do
      stub_current_user(role: "admin")

      # Create custom field definitions for product model
      cfd_model = LcpRuby.registry.model_for("custom_field_definition")
      cfd_model.delete_all

      cfd_model.create!(
        target_model: "product",
        field_name: "color",
        custom_type: "string",
        label: "Color",
        active: true,
        filterable: true,
        position: 0
      )

      cfd_model.create!(
        target_model: "product",
        field_name: "priority",
        custom_type: "integer",
        label: "Priority",
        active: true,
        filterable: true,
        position: 1
      )

      cfd_model.create!(
        target_model: "product",
        field_name: "tier",
        custom_type: "enum",
        label: "Tier",
        active: true,
        filterable: true,
        position: 2,
        enum_values: [
          { "value" => "basic", "label" => "Basic" },
          { "value" => "premium", "label" => "Premium" }
        ]
      )

      cfd_model.create!(
        target_model: "product",
        field_name: "internal_notes",
        custom_type: "text",
        label: "Internal Notes",
        active: true,
        filterable: false,
        position: 3
      )

      LcpRuby::CustomFields::Registry.mark_available!
      LcpRuby::CustomFields::Registry.reload!("product")
    end

    it "filters by custom field eq" do
      product_model.create!(name: "Red Product", custom_data: { "color" => "red" })
      product_model.create!(name: "Blue Product", custom_data: { "color" => "blue" })

      get "/products", params: { cf: { color_eq: "red" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Red Product")
      expect(response.body).not_to include("Blue Product")
    end

    it "filters by custom field cont" do
      product_model.create!(name: "Product A", custom_data: { "color" => "dark red" })
      product_model.create!(name: "Product B", custom_data: { "color" => "blue" })

      get "/products", params: { cf: { color_cont: "red" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Product A")
      expect(response.body).not_to include("Product B")
    end

    it "filters by integer custom field with comparison" do
      product_model.create!(name: "High Priority", custom_data: { "priority" => "10" })
      product_model.create!(name: "Low Priority", custom_data: { "priority" => "1" })

      get "/products", params: { cf: { priority_gteq: "5" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("High Priority")
      expect(response.body).not_to include("Low Priority")
    end

    it "ignores non-filterable custom fields" do
      product_model.create!(name: "With Notes", custom_data: { "internal_notes" => "secret" })
      product_model.create!(name: "Without Notes", custom_data: {})

      get "/products", params: { cf: { internal_notes_eq: "secret" } }

      expect(response).to have_http_status(:ok)
      # Filter should be ignored since field is not filterable
      expect(response.body).to include("With Notes")
      expect(response.body).to include("Without Notes")
    end

    it "combines Ransack filters with custom field filters" do
      product_model.create!(name: "Published Red", status: "published", custom_data: { "color" => "red" })
      product_model.create!(name: "Published Blue", status: "published", custom_data: { "color" => "blue" })
      product_model.create!(name: "Draft Red", status: "draft", custom_data: { "color" => "red" })

      get "/products", params: { f: { status_eq: "published" }, cf: { color_eq: "red" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Published Red")
      expect(response.body).not_to include("Published Blue")
      expect(response.body).not_to include("Draft Red")
    end

    it "includes custom fields in filter metadata JSON" do
      product_model.create!(name: "Test Product")

      get "/products"

      metadata_match = response.body.match(/data-lcp-filter-metadata="([^"]*)"/)
      metadata = JSON.parse(CGI.unescapeHTML(metadata_match[1]))

      cf_fields = metadata["fields"].select { |f| f["custom_field"] }
      cf_names = cf_fields.map { |f| f["name"] }
      expect(cf_names).to include("cf[color]", "cf[priority]", "cf[tier]")
      # non-filterable field should not appear
      expect(cf_names).not_to include("cf[internal_notes]")

      tier_field = cf_fields.find { |f| f["name"] == "cf[tier]" }
      expect(tier_field["enum_values"]).to eq([["basic", "Basic"], ["premium", "Premium"]])
      expect(tier_field["group"]).to eq("Custom Fields")
    end
  end

  describe "Query Language parse_ql endpoint" do
    before do
      stub_current_user(role: "admin")
    end

    it "parses valid QL and returns tree" do
      post "/products/parse_ql", params: { ql: "status = 'published' and price >= 100" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["tree"]["children"].size).to eq(2)
      expect(json["tree"]["children"][0]["field"]).to eq("status")
      expect(json["tree"]["children"][0]["operator"]).to eq("eq")
      expect(json["tree"]["children"][1]["field"]).to eq("price")
      expect(json["tree"]["children"][1]["operator"]).to eq("gteq")
    end

    it "parses QL with OR group" do
      post "/products/parse_ql", params: { ql: "(status = 'draft' or status = 'review')" }

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["tree"]["combinator"]).to eq("or")
      expect(json["tree"]["children"].size).to eq(2)
    end

    it "preserves nested AND within OR in QL" do
      post "/products/parse_ql", params: { ql: "(status = 'draft' and price > 100) or (status = 'review' and price > 200)" }

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      tree = json["tree"]
      expect(tree["combinator"]).to eq("or")
      expect(tree["children"].size).to eq(2)
      expect(tree["children"][0]["combinator"]).to eq("and")
      expect(tree["children"][1]["combinator"]).to eq("and")
    end

    it "returns error for invalid QL" do
      post "/products/parse_ql", params: { ql: "name BADOP 'value'" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["error"]).to be_present
      expect(json["position"]).to be_a(Integer)
    end

    it "handles empty QL" do
      post "/products/parse_ql", params: { ql: "" }

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["tree"]["children"]).to eq([])
    end
  end

  describe "filter_fields endpoint" do
    before { stub_current_user(role: "admin") }

    it "returns JSON with field list" do
      get "/products/filter_fields"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fields"]).to be_an(Array)
      expect(json["fields"].length).to be > 0

      name_field = json["fields"].find { |f| f["name"] == "name" }
      expect(name_field).not_to be_nil
      expect(name_field["type"]).to eq("string")
      expect(name_field["operators"]).to include("eq", "cont")
    end
  end

  describe "PresenterDefinition convenience methods" do
    it "returns advanced_filter_config" do
      load_integration_metadata!("advanced_search")
      presenter = LcpRuby.loader.presenter_definitions["product"]

      expect(presenter.advanced_filter_config).to be_a(Hash)
      expect(presenter.advanced_filter_config["enabled"]).to be true
      expect(presenter.advanced_filter_config["max_conditions"]).to eq(10)
    end

    it "returns advanced_filter_enabled?" do
      load_integration_metadata!("advanced_search")
      presenter = LcpRuby.loader.presenter_definitions["product"]
      expect(presenter.advanced_filter_enabled?).to be true
    end

    it "returns false when search is disabled" do
      load_integration_metadata!("advanced_search")
      presenter = LcpRuby.loader.presenter_definitions["product"]
      # Override search_config to disabled
      allow(presenter).to receive(:search_config).and_return("enabled" => false)
      expect(presenter.advanced_filter_enabled?).to be_falsey
    end
  end
end
