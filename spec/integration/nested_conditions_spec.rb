require "spec_helper"
require "support/integration_helper"

RSpec.describe "Nested Field Conditions", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("nested_conditions_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("nested_conditions_test")
  end

  before(:each) do
    load_integration_metadata!("nested_conditions_test")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("line_item").delete_all
    LcpRuby.registry.model_for("order").delete_all
  end

  let(:order_model) { LcpRuby.registry.model_for("order") }
  let(:line_item_model) { LcpRuby.registry.model_for("line_item") }

  describe "data-lcp-condition-scope attribute" do
    it "renders data-lcp-condition-scope on nested rows" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-condition-scope")
    end

    it "renders data-lcp-condition-scope on template row" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      # The template row should also have the scope attribute
      body = response.body
      template_section = body[/data-lcp-nested-template.*?<\/div>/m]
      expect(template_section).to include("data-lcp-condition-scope")
    end
  end

  describe "field-level visible_when on nested fields" do
    it "renders data-lcp-visible-field attributes on conditional fields" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-lcp-visible-field="item_type"')
    end

    it "renders data-lcp-visible-operator on conditional fields" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-lcp-visible-operator="eq"')
      expect(response.body).to include('data-lcp-visible-operator="in"')
    end

    it "renders data-lcp-visible-value on conditional fields" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-lcp-visible-value="discount"')
      expect(response.body).to include('data-lcp-visible-value="service,discount"')
    end

    it "hides discount_percent field when item_type defaults to product (server-side)" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      # discount_percent has visible_when: item_type eq discount
      # Default item_type is "product", so field should be hidden initially
      expect(response.body).to include("display: none")
    end

    it "marks conditional fields with data-lcp-conditional attribute" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-lcp-conditional="field"')
    end
  end

  describe "col_span on nested fields" do
    it "renders grid-column span for col_span fields" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("grid-column: span 2")
    end
  end

  describe "hint on nested fields" do
    it "renders hint text below nested field input" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-field-hint")
      expect(response.body).to include("Enter discount percentage")
    end
  end

  describe "prefix on nested fields" do
    it "renders prefix with input group on nested fields" do
      get "/orders/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-input-group")
      expect(response.body).to include("lcp-input-prefix")
      expect(response.body).to include("Note:")
    end
  end

  describe "backward compatibility" do
    it "existing todo nested fields still work" do
      load_integration_metadata!("todo")
      stub_current_user(role: "admin")

      get "/lists/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-nested-section")
      expect(response.body).to include("Add Item")
      expect(response.body).to include("lcp-nested-row")
      expect(response.body).to include("data-lcp-condition-scope")
    end
  end

  describe "CRUD with conditional nested fields" do
    it "creates order with line items" do
      expect {
        post "/orders", params: {
          record: {
            title: "Test Order",
            line_items_attributes: {
              "0" => { item_type: "product", description: "Widget", quantity: 2, unit_price: 9.99 },
              "1" => { item_type: "discount", description: "Coupon", discount_percent: 10.0 }
            }
          }
        }
      }.to change { order_model.count }.by(1)
        .and change { line_item_model.count }.by(2)

      expect(response).to have_http_status(:redirect)
      order = order_model.last
      expect(order.line_items.count).to eq(2)
    end

    it "renders edit form with existing line items and conditions" do
      order = order_model.create!(title: "Edit Order")
      line_item_model.create!(
        description: "Discount Item",
        item_type: "discount",
        discount_percent: 15.0,
        order_id: order.id
      )

      get "/orders/#{order.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Discount Item")
      expect(response.body).to include("data-lcp-condition-scope")
    end
  end
end
