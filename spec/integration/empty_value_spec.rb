require "spec_helper"
require "support/integration_helper"

RSpec.describe "Empty Value Display", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("todo")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("todo")
  end

  before(:each) do
    load_integration_metadata!("todo")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("todo_item").delete_all
    LcpRuby.registry.model_for("todo_list").delete_all
  end

  let(:list_model) { LcpRuby.registry.model_for("todo_list") }

  describe "index page" do
    it "renders empty value placeholder for nil fields" do
      list_model.create!(title: "Test List", description: nil)

      get "/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('class="lcp-empty-value"')
      expect(response.body).to include("\u2014")
    end

    it "renders normal values without placeholder" do
      list_model.create!(title: "Test List", description: "Has a description")

      get "/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Has a description")
    end
  end

  describe "show page" do
    it "renders empty value placeholder for nil fields" do
      list = list_model.create!(title: "Test List", description: nil)

      get "/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('class="lcp-empty-value"')
      expect(response.body).to include("\u2014")
    end

    it "renders normal values without placeholder" do
      list = list_model.create!(title: "Test List", description: "Present")

      get "/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Present")
    end
  end

  describe "empty_value_placeholder helper" do
    let(:helper_instance) { Object.new.extend(LcpRuby::DisplayHelper, ActionView::Helpers::TagHelper, ActionView::Helpers::OutputSafetyHelper) }

    it "returns value for false" do
      expect(helper_instance.empty_value_placeholder(false)).to eq(false)
    end

    it "returns value for 0" do
      expect(helper_instance.empty_value_placeholder(0)).to eq(0)
    end

    it "renders placeholder for nil" do
      result = helper_instance.empty_value_placeholder(nil)
      expect(result).to include("lcp-empty-value")
      expect(result).to include("\u2014")
    end

    it "renders placeholder for empty string" do
      result = helper_instance.empty_value_placeholder("")
      expect(result).to include("lcp-empty-value")
    end

    it "renders placeholder for whitespace-only string" do
      result = helper_instance.empty_value_placeholder("   ")
      expect(result).to include("lcp-empty-value")
    end

    it "renders placeholder for empty array" do
      result = helper_instance.empty_value_placeholder([])
      expect(result).to include("lcp-empty-value")
    end

    it "returns non-empty value as-is" do
      expect(helper_instance.empty_value_placeholder("hello")).to eq("hello")
    end

    it "returns non-zero integer as-is" do
      expect(helper_instance.empty_value_placeholder(42)).to eq(42)
    end

    it "uses per-presenter empty_value override" do
      presenter = instance_double(LcpRuby::Metadata::PresenterDefinition,
                                  options: { "empty_value" => "N/A" })

      result = helper_instance.empty_value_placeholder(nil, presenter)
      expect(result).to include("N/A")
      expect(result).to include("lcp-empty-value")
    end

    it "uses global config empty_value" do
      LcpRuby.configuration.empty_value = "---"

      result = helper_instance.empty_value_placeholder(nil)
      expect(result).to include("---")
      expect(result).to include("lcp-empty-value")
    ensure
      LcpRuby.configuration.empty_value = nil
    end

    it "prefers presenter override over global config" do
      LcpRuby.configuration.empty_value = "global"
      presenter = instance_double(LcpRuby::Metadata::PresenterDefinition,
                                  options: { "empty_value" => "presenter" })

      result = helper_instance.empty_value_placeholder(nil, presenter)
      expect(result).to include("presenter")
      expect(result).not_to include("global")
    ensure
      LcpRuby.configuration.empty_value = nil
    end
  end
end
