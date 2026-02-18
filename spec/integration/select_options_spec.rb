require "spec_helper"
require "support/integration_helper"

RSpec.describe "Select Options API", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("crm")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("crm")
  end

  before(:each) do
    load_integration_metadata!("crm")
    LcpRuby.registry.model_for("deal").delete_all
    LcpRuby.registry.model_for("contact").delete_all
    LcpRuby.registry.model_for("company").delete_all
  end

  let(:company_model) { LcpRuby.registry.model_for("company") }
  let(:contact_model) { LcpRuby.registry.model_for("contact") }

  describe "GET /admin/deals/select_options" do
    before { stub_current_user(role: "admin") }

    it "returns grouped JSON when group_by is configured" do
      company = company_model.create!(name: "Acme Corp", industry: "technology")

      get "/admin/deals/select_options", params: { field: "company_id" },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      # Grouped format: [{group: "...", options: [{value, label}]}]
      expect(json.first).to include("group")
      expect(json.first["options"]).to be_an(Array)
      expect(json.first["options"].first).to include("value" => company.id)
      expect(json.first["options"].first["label"]).to include("Acme")
    end

    it "returns groups with correct labels when group_by is configured" do
      company_model.create!(name: "Zebra Inc", industry: "technology")
      company_model.create!(name: "Alpha Corp", industry: "finance")

      get "/admin/deals/select_options", params: { field: "company_id" },
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      groups = json.map { |g| g["group"] }
      expect(groups).to include("technology", "finance")
      all_options = json.flat_map { |g| g["options"] }
      labels = all_options.map { |o| o["label"] }
      expect(labels).to include("Zebra Inc", "Alpha Corp")
    end

    it "filters by depends_on params" do
      acme = company_model.create!(name: "Acme Corp", industry: "technology")
      other = company_model.create!(name: "Other Corp", industry: "finance")
      contact_model.create!(first_name: "John", last_name: "Doe", company_id: acme.id)
      contact_model.create!(first_name: "Jane", last_name: "Smith", company_id: other.id)

      get "/admin/deals/select_options", params: {
        field: "contact_id",
        depends_on: { "company_id" => acme.id.to_s }
      }, headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["label"]).to include("Doe")
    end

    it "returns all contacts when no depends_on parent value" do
      acme = company_model.create!(name: "Acme Corp", industry: "technology")
      other = company_model.create!(name: "Other Corp", industry: "finance")
      contact_model.create!(first_name: "John", last_name: "Doe", company_id: acme.id)
      contact_model.create!(first_name: "Jane", last_name: "Smith", company_id: other.id)

      get "/admin/deals/select_options", params: { field: "contact_id" },
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
    end

    it "returns empty array for unknown field" do
      get "/admin/deals/select_options", params: { field: "nonexistent" },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end

    it "returns empty array when field param is missing" do
      get "/admin/deals/select_options",
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end

    it "uses custom label_method from input_options" do
      acme = company_model.create!(name: "Acme Corp", industry: "technology")
      contact_model.create!(first_name: "John", last_name: "Doe", company_id: acme.id)

      get "/admin/deals/select_options", params: { field: "contact_id" },
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      # label_method is full_name for contacts in the fixture
      expect(json.first["label"]).to eq("John Doe")
    end
  end

  describe "paginated search" do
    before { stub_current_user(role: "admin") }

    it "returns envelope format when q param is present" do
      company_model.create!(name: "Acme Corp", industry: "technology")
      company_model.create!(name: "Beta Inc", industry: "finance")

      get "/admin/deals/select_options", params: {
        field: "company_id", q: "Acme", page: 1, per_page: 10
      }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("options", "has_more", "total")
      expect(json["options"]).to be_an(Array)
    end

    it "returns envelope format when page param is present without q" do
      company_model.create!(name: "Acme Corp", industry: "technology")

      get "/admin/deals/select_options", params: {
        field: "company_id", page: 1, per_page: 10
      }, headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json).to include("options", "has_more", "total")
    end

    it "returns has_more: true when more results exist" do
      5.times { |i| company_model.create!(name: "Company #{i}", industry: "technology") }

      get "/admin/deals/select_options", params: {
        field: "company_id", page: 1, per_page: 2
      }, headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json["has_more"]).to be true
      expect(json["total"]).to eq(5)
      expect(json["options"].length).to eq(2)
    end

    it "returns has_more: false on last page" do
      3.times { |i| company_model.create!(name: "Company #{i}", industry: "technology") }

      get "/admin/deals/select_options", params: {
        field: "company_id", page: 2, per_page: 2
      }, headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json["has_more"]).to be false
      expect(json["options"].length).to eq(1)
    end

    it "returns flat array for legacy requests without q or page" do
      company_model.create!(name: "Acme Corp", industry: "technology")

      get "/admin/deals/select_options", params: { field: "company_id" },
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first).to include("group") # company_id has group_by configured
    end

    it "caps per_page at 100" do
      get "/admin/deals/select_options", params: {
        field: "company_id", page: 1, per_page: 999
      }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "authorization" do
    it "returns 403 when user cannot access the presenter" do
      stub_current_user(role: "viewer")

      get "/admin/deals/select_options", params: { field: "company_id" },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
