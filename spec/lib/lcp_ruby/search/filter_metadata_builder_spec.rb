require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::Search::FilterMetadataBuilder do
  before(:each) do
    LcpRuby.reset!
    LcpRuby::Dynamic.constants.each { |c| LcpRuby::Dynamic.send(:remove_const, c) }
  end

  let(:category_model_hash) do
    {
      "name" => "category",
      "label" => "Category",
      "fields" => [
        { "name" => "name", "type" => "string" }
      ],
      "options" => { "label_method" => "name" }
    }
  end

  let(:product_model_hash) do
    {
      "name" => "product",
      "label" => "Product",
      "fields" => [
        { "name" => "name", "type" => "string" },
        { "name" => "description", "type" => "text" },
        { "name" => "price", "type" => "decimal", "column_options" => { "precision" => 10, "scale" => 2 } },
        { "name" => "quantity", "type" => "integer" },
        { "name" => "active", "type" => "boolean" },
        { "name" => "release_date", "type" => "date" },
        { "name" => "status", "type" => "enum", "enum_values" => [
          { "value" => "draft", "label" => "Draft" },
          { "value" => "published", "label" => "Published" }
        ] },
        { "name" => "sku", "type" => "string" }
      ],
      "associations" => [
        { "type" => "belongs_to", "name" => "category", "target_model" => "category", "foreign_key" => "category_id", "required" => false }
      ],
      "options" => { "label_method" => "name" }
    }
  end

  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(product_model_hash) }
  let(:category_model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(category_model_hash) }

  let(:permission_hash) do
    {
      "model" => "product",
      "roles" => {
        "admin" => {
          "crud" => %w[index show create update destroy],
          "fields" => { "readable" => "all", "writable" => "all" },
          "actions" => "all",
          "scope" => "all",
          "presenters" => "all"
        },
        "viewer" => {
          "crud" => %w[index show],
          "fields" => { "readable" => %w[name status sku], "writable" => [] },
          "scope" => "all",
          "presenters" => %w[product]
        }
      }
    }
  end

  let(:permission_definition) { LcpRuby::Metadata::PermissionDefinition.from_hash(permission_hash) }

  let(:admin_user) { OpenStruct.new(id: 1, lcp_role: ["admin"]) }
  let(:viewer_user) { OpenStruct.new(id: 2, lcp_role: ["viewer"]) }

  let(:admin_evaluator) { LcpRuby::Authorization::PermissionEvaluator.new(permission_definition, admin_user, "product") }
  let(:viewer_evaluator) { LcpRuby::Authorization::PermissionEvaluator.new(permission_definition, viewer_user, "product") }

  # Register category model definition in loader
  before do
    loader = instance_double(LcpRuby::Metadata::Loader)
    allow(LcpRuby).to receive(:loader).and_return(loader)
    allow(loader).to receive(:model_definition).with("category").and_return(category_model_definition)
    allow(loader).to receive(:model_definition).with("product").and_return(model_definition)
  end

  describe "with explicit filterable_fields" do
    let(:presenter_hash) do
      {
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true,
            "max_conditions" => 10,
            "max_association_depth" => 2,
            "filterable_fields" => %w[name price status category.name],
            "field_options" => {
              "status" => { "operators" => %w[eq not_eq] },
              "price" => { "operators" => %w[eq gt gteq lt lteq between] }
            }
          }
        }
      }
    end

    let(:presenter_definition) { LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash) }

    it "returns only the specified filterable fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      expect(field_names).to eq(%w[name price status category.name])
    end

    it "applies field_options operator overrides" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      status_field = result[:fields].find { |f| f[:name] == "status" }
      expect(status_field[:operators]).to eq(%w[eq not_eq])

      price_field = result[:fields].find { |f| f[:name] == "price" }
      expect(price_field[:operators]).to eq(%w[eq gt gteq lt lteq between])
    end

    it "includes enum_values for enum fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      status_field = result[:fields].find { |f| f[:name] == "status" }
      expect(status_field[:enum_values]).to eq([["draft", "Draft"], ["published", "Published"]])
    end

    it "sets correct types for fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      name_field = result[:fields].find { |f| f[:name] == "name" }
      expect(name_field[:type]).to eq("string")

      price_field = result[:fields].find { |f| f[:name] == "price" }
      expect(price_field[:type]).to eq("decimal")
    end

    it "sets group label for association fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      category_field = result[:fields].find { |f| f[:name] == "category.name" }
      expect(category_field[:group]).to eq("Category")
      expect(category_field[:type]).to eq("string")
    end

    it "sets nil group for direct fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      name_field = result[:fields].find { |f| f[:name] == "name" }
      expect(name_field[:group]).to be_nil
    end

    it "filters out fields not readable by viewer" do
      builder = described_class.new(presenter_definition, model_definition, viewer_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      # filterable_fields: [name, price, status, category.name]
      # viewer can read: [name, status, sku] — sku not in filterable_fields
      expect(field_names).to include("name", "status")
      # price is not in viewer's readable fields, so it should be excluded
      expect(field_names).not_to include("price")
    end

    it "excludes association fields when FK is not readable" do
      builder = described_class.new(presenter_definition, model_definition, viewer_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      # viewer cannot read category_id, so category.name should be excluded
      expect(field_names).not_to include("category.name")
    end
  end

  describe "with auto-detected fields (no filterable_fields)" do
    let(:presenter_hash) do
      {
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true
          }
        }
      }
    end

    let(:presenter_definition) { LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash) }

    it "includes all non-excluded direct fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      expect(field_names).to include("name", "description", "price", "quantity", "active", "release_date", "status", "sku")
    end

    it "excludes system fields (id, created_at, updated_at)" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      expect(field_names).not_to include("id", "created_at", "updated_at")
    end

    it "includes belongs_to association label_method field" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      expect(field_names).to include("category.name")
    end
  end

  describe "operator labels and metadata" do
    let(:presenter_hash) do
      {
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true,
            "max_conditions" => 5,
            "default_combinator" => "or"
          }
        }
      }
    end

    let(:presenter_definition) { LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash) }

    it "includes operator labels" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:operator_labels]).to be_a(Hash)
      expect(result[:operator_labels]["eq"]).to eq("equals")
      expect(result[:operator_labels]["cont"]).to eq("contains")
    end

    it "includes no_value_operators" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:no_value_operators]).to include("present", "blank", "null", "not_null")
    end

    it "includes multi_value_operators" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:multi_value_operators]).to eq(%w[in not_in])
    end

    it "includes range_operators" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:range_operators]).to eq(%w[between])
    end

    it "includes parameterized_operators" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:parameterized_operators]).to eq(%w[last_n_days])
    end

    it "includes config from advanced_filter_config" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:config][:max_conditions]).to eq(5)
      expect(result[:config][:default_combinator]).to eq("or")
      expect(result[:config][:allow_or_groups]).to be true
    end

    it "defaults config values when not set" do
      minimal_presenter = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => { "enabled" => true, "advanced_filter" => { "enabled" => true } }
      )
      builder = described_class.new(minimal_presenter, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:config][:max_conditions]).to eq(10)
      expect(result[:config][:default_combinator]).to eq("and")
      expect(result[:config][:allow_or_groups]).to be true
    end
  end

  describe "custom type resolution" do
    before do
      LcpRuby::Types::TypeRegistry.register("email", LcpRuby::Types::TypeDefinition.new(
        name: "email", base_type: "string", transforms: ["strip", "downcase"]
      ))
    end

    let(:model_with_custom_type_hash) do
      {
        "name" => "contact",
        "label" => "Contact",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "email", "type" => "email" }
        ],
        "options" => { "label_method" => "name" }
      }
    end

    let(:contact_model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_with_custom_type_hash) }

    let(:contact_perm_hash) do
      {
        "model" => "contact",
        "roles" => {
          "admin" => {
            "crud" => %w[index show create update destroy],
            "fields" => { "readable" => "all", "writable" => "all" },
            "actions" => "all",
            "scope" => "all",
            "presenters" => "all"
          }
        }
      }
    end

    let(:contact_perm_def) { LcpRuby::Metadata::PermissionDefinition.from_hash(contact_perm_hash) }
    let(:contact_evaluator) { LcpRuby::Authorization::PermissionEvaluator.new(contact_perm_def, admin_user, "contact") }

    let(:contact_presenter_hash) do
      {
        "name" => "contact",
        "model" => "contact",
        "slug" => "contacts",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true,
            "filterable_fields" => %w[name email]
          }
        }
      }
    end

    let(:contact_presenter) { LcpRuby::Metadata::PresenterDefinition.from_hash(contact_presenter_hash) }

    it "resolves custom type to base type" do
      allow(LcpRuby.loader).to receive(:model_definition).with("contact").and_return(contact_model_definition)

      builder = described_class.new(contact_presenter, contact_model_definition, contact_evaluator)
      result = builder.build

      email_field = result[:fields].find { |f| f[:name] == "email" }
      expect(email_field[:type]).to eq("string")
      # Should have string operators
      expect(email_field[:operators]).to include("cont", "eq")
    end
  end

  describe "max_association_depth enforcement" do
    let(:presenter_hash) do
      {
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true,
            "max_association_depth" => 1,
            "filterable_fields" => %w[name category.name]
          }
        }
      }
    end

    let(:presenter_definition) { LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash) }

    it "includes fields within max_association_depth" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      expect(field_names).to include("category.name")
    end

    it "excludes fields beyond max_association_depth" do
      # depth 0 means no associations allowed
      restricted_presenter = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true,
            "max_association_depth" => 0,
            "filterable_fields" => %w[name category.name]
          }
        }
      )

      builder = described_class.new(restricted_presenter, model_definition, admin_evaluator)
      result = builder.build

      field_names = result[:fields].map { |f| f[:name] }
      expect(field_names).not_to include("category.name")
    end
  end

  describe "default operators per type" do
    let(:presenter_hash) do
      {
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true,
            "filterable_fields" => %w[name price active release_date status]
          }
        }
      }
    end

    let(:presenter_definition) { LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash) }

    it "assigns string operators to string fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      name_field = result[:fields].find { |f| f[:name] == "name" }
      expect(name_field[:operators]).to include("eq", "cont", "start", "end", "in")
    end

    it "assigns numeric operators to decimal fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      price_field = result[:fields].find { |f| f[:name] == "price" }
      expect(price_field[:operators]).to include("eq", "gt", "gteq", "lt", "lteq", "between")
    end

    it "assigns boolean operators to boolean fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      active_field = result[:fields].find { |f| f[:name] == "active" }
      expect(active_field[:operators]).to include("true", "not_true", "false", "not_false")
    end

    it "assigns temporal operators to date fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      date_field = result[:fields].find { |f| f[:name] == "release_date" }
      expect(date_field[:operators]).to include("eq", "between", "last_n_days", "this_week", "this_month")
    end

    it "assigns enum operators to enum fields" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      status_field = result[:fields].find { |f| f[:name] == "status" }
      expect(status_field[:operators]).to include("eq", "not_eq", "in", "not_in")
    end
  end

  describe "presets passthrough" do
    let(:presenter_hash) do
      {
        "name" => "product",
        "model" => "product",
        "slug" => "products",
        "search" => {
          "enabled" => true,
          "advanced_filter" => {
            "enabled" => true,
            "presets" => [
              { "name" => "expensive", "label" => "Expensive", "conditions" => [{ "field" => "price", "operator" => "gteq", "value" => 100 }] }
            ]
          }
        }
      }
    end

    let(:presenter_definition) { LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash) }

    it "passes through presets from config" do
      builder = described_class.new(presenter_definition, model_definition, admin_evaluator)
      result = builder.build

      expect(result[:presets]).to be_a(Array)
      expect(result[:presets].first["name"]).to eq("expensive")
    end
  end
end
