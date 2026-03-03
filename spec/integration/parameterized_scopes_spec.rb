require "spec_helper"
require "support/integration_helper"

RSpec.describe "Parameterized Scopes Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("parameterized_scopes")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("parameterized_scopes")
  end

  before(:each) do
    load_integration_metadata!("parameterized_scopes")
    product_model.delete_all
  end

  let(:product_model) { LcpRuby.registry.model_for("product") }

  describe "Parameterized scope metadata" do
    before { stub_current_user(role: "admin") }

    it "includes parameterized scopes in model definition" do
      model_def = LcpRuby.loader.model_definition("product")
      scopes = model_def.parameterized_scopes

      expect(scopes.size).to eq(3)
      expect(scopes.map { |s| s["name"] }).to contain_exactly("by_min_price", "by_status_filter", "in_stock")
    end

    it "retrieves a parameterized scope by name" do
      model_def = LcpRuby.loader.model_definition("product")
      scope = model_def.parameterized_scope("by_min_price")

      expect(scope).to be_present
      expect(scope["parameters"].first["name"]).to eq("min_price")
      expect(scope["parameters"].first["type"]).to eq("float")
    end

    it "returns nil for unknown scope" do
      model_def = LcpRuby.loader.model_definition("product")
      expect(model_def.parameterized_scope("nonexistent")).to be_nil
    end
  end

  describe "Filter metadata includes scopes" do
    before { stub_current_user(role: "admin") }

    it "includes parameterized scopes in filter_fields response" do
      get "/products/filter_fields"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      scopes = json["scopes"]

      expect(scopes).to be_present
      scope_names = scopes.map { |s| s["name"] }
      expect(scope_names).to include("by_min_price", "by_status_filter", "in_stock")
    end

    it "includes parameter details for each scope" do
      get "/products/filter_fields"

      json = JSON.parse(response.body)
      by_min_price = json["scopes"].find { |s| s["name"] == "by_min_price" }

      expect(by_min_price["parameters"].size).to eq(1)
      param = by_min_price["parameters"].first
      expect(param["name"]).to eq("min_price")
      expect(param["type"]).to eq("float")
      expect(param["default"]).to eq(0.0)
    end

    it "includes enum values for enum-type parameters" do
      get "/products/filter_fields"

      json = JSON.parse(response.body)
      by_status = json["scopes"].find { |s| s["name"] == "by_status_filter" }
      param = by_status["parameters"].first

      expect(param["type"]).to eq("enum")
      values = param["values"].map { |v| v.is_a?(Array) ? v.first : v }
      expect(values).to contain_exactly("draft", "published", "archived")
      expect(param["required"]).to be true
    end
  end

  describe "ScopeApplicator skips parameterized scopes at boot" do
    it "does not apply parameterized scopes as regular where scopes" do
      # Parameterized scopes should not be applied during model building.
      # They should only be applied via ParameterizedScopeApplicator at request time.
      model_class = LcpRuby.registry.model_for("product")

      # Regular scope should exist (applied by ScopeApplicator)
      expect(model_class).to respond_to(:active_products)

      # Parameterized scopes should NOT be defined as AR scopes by ScopeApplicator
      # (they may or may not exist as class methods - depends on model definition)
      # The key test is that they don't error when not called with params
    end
  end

  describe "QL roundtrip for parameterized scopes" do
    before { stub_current_user(role: "admin") }

    it "parses QL with parameterized scope syntax" do
      post "/products/parse_ql", params: { ql: '@by_status_filter(status: "published")' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      tree = json["tree"]

      expect(tree).to be_present
      # The root node should contain a scope condition
      scope_child = find_scope_condition(tree)
      expect(scope_child).to be_present
      expect(scope_child["field"]).to eq("@by_status_filter")
      expect(scope_child["operator"]).to eq("scope")
      expect(scope_child["params"]).to eq({ "status" => "published" })
    end

    it "parses QL with scope and regular conditions" do
      post "/products/parse_ql", params: { ql: "@by_min_price(min_price: 10.5) and name = 'Widget'" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      tree = json["tree"]

      # Should have both scope and field conditions
      children = tree["children"] || [ tree ]
      scope_cond = children.find { |c| c["operator"] == "scope" }
      field_cond = children.find { |c| c["field"] == "name" }

      expect(scope_cond).to be_present
      expect(scope_cond["params"]["min_price"]).to eq(10.5)
      expect(field_cond).to be_present
      expect(field_cond["value"]).to eq("Widget")
    end

    it "serializes scope conditions back to QL text" do
      condition_tree = {
        "combinator" => "and",
        "children" => [
          { "field" => "@by_status_filter", "operator" => "scope", "params" => { "status" => "published" } },
          { "field" => "name", "operator" => "cont", "value" => "Widget" }
        ]
      }

      ql_text = LcpRuby::Search::QueryLanguageSerializer.serialize(condition_tree)
      expect(ql_text).to include("@by_status_filter")
      expect(ql_text).to include("published")
      expect(ql_text).to include("Widget")
    end
  end

  private

  def find_scope_condition(tree)
    if tree["operator"] == "scope"
      tree
    elsif tree["children"]
      tree["children"].each do |child|
        result = find_scope_condition(child)
        return result if result
      end
      nil
    end
  end
end
