require "spec_helper"
require "support/integration_helper"

RSpec.describe "Cascade Chain (3-level A→B→C)", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("cascade")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("cascade")
  end

  before(:each) do
    load_integration_metadata!("cascade")
    LcpRuby.registry.model_for("address").delete_all
    LcpRuby.registry.model_for("district").delete_all
    LcpRuby.registry.model_for("city").delete_all
    LcpRuby.registry.model_for("region").delete_all
    stub_current_user(role: "admin")
  end

  let(:region_model) { LcpRuby.registry.model_for("region") }
  let(:city_model) { LcpRuby.registry.model_for("city") }
  let(:district_model) { LcpRuby.registry.model_for("district") }
  let(:address_model) { LcpRuby.registry.model_for("address") }

  describe "GET /admin/addresses/select_options" do
    it "returns cities filtered by region (level A→B)" do
      r1 = region_model.create!(name: "Region 1")
      r2 = region_model.create!(name: "Region 2")
      c1 = city_model.create!(name: "City A", region_id: r1.id)
      c2 = city_model.create!(name: "City B", region_id: r1.id)
      c3 = city_model.create!(name: "City C", region_id: r2.id)

      get "/admin/addresses/select_options", params: {
        field: "city_id",
        depends_on: { "region_id" => r1.id.to_s }
      }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      labels = json.map { |o| o["label"] }
      expect(labels).to contain_exactly("City A", "City B")
      expect(labels).not_to include("City C")
    end

    it "returns districts filtered by city (level B→C)" do
      r1 = region_model.create!(name: "Region 1")
      c1 = city_model.create!(name: "City A", region_id: r1.id)
      c2 = city_model.create!(name: "City B", region_id: r1.id)
      d1 = district_model.create!(name: "District X", city_id: c1.id)
      d2 = district_model.create!(name: "District Y", city_id: c1.id)
      d3 = district_model.create!(name: "District Z", city_id: c2.id)

      get "/admin/addresses/select_options", params: {
        field: "district_id",
        depends_on: { "city_id" => c1.id.to_s }
      }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      labels = json.map { |o| o["label"] }
      expect(labels).to contain_exactly("District X", "District Y")
      expect(labels).not_to include("District Z")
    end

    it "returns all cities when no depends_on param" do
      r1 = region_model.create!(name: "Region 1")
      r2 = region_model.create!(name: "Region 2")
      city_model.create!(name: "City A", region_id: r1.id)
      city_model.create!(name: "City B", region_id: r2.id)

      get "/admin/addresses/select_options", params: { field: "city_id" },
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
    end

    it "returns all regions (root level, no depends_on)" do
      region_model.create!(name: "Region 1")
      region_model.create!(name: "Region 2")
      region_model.create!(name: "Region 3")

      get "/admin/addresses/select_options", params: { field: "region_id" },
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end

    it "returns empty array when parent has no children" do
      r1 = region_model.create!(name: "Empty Region")
      # No cities in this region

      get "/admin/addresses/select_options", params: {
        field: "city_id",
        depends_on: { "region_id" => r1.id.to_s }
      }, headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json).to eq([])
    end

    it "returns options sorted by name" do
      r1 = region_model.create!(name: "Region 1")
      city_model.create!(name: "Zeta City", region_id: r1.id)
      city_model.create!(name: "Alpha City", region_id: r1.id)
      city_model.create!(name: "Mu City", region_id: r1.id)

      get "/admin/addresses/select_options", params: {
        field: "city_id",
        depends_on: { "region_id" => r1.id.to_s }
      }, headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      labels = json.map { |o| o["label"] }
      expect(labels).to eq([ "Alpha City", "Mu City", "Zeta City" ])
    end
  end

  describe "form rendering" do
    it "renders cascading select data attributes for 3-level chain" do
      get "/admin/addresses/new"

      expect(response).to have_http_status(:ok)
      body = response.body

      # city_id depends on region_id
      expect(body).to include('data-lcp-depends-on="region_id"')
      # district_id depends on city_id
      expect(body).to include('data-lcp-depends-on="city_id"')
    end
  end

  describe "creating address with cascaded selects" do
    it "creates an address with all three levels selected" do
      r1 = region_model.create!(name: "Region 1")
      c1 = city_model.create!(name: "City A", region_id: r1.id)
      d1 = district_model.create!(name: "District X", city_id: c1.id)

      expect {
        post "/admin/addresses", params: {
          record: {
            street: "123 Main St",
            region_id: r1.id,
            city_id: c1.id,
            district_id: d1.id
          }
        }
      }.to change { address_model.count }.by(1)

      address = address_model.last
      expect(address.street).to eq("123 Main St")
      expect(address.region_id).to eq(r1.id)
      expect(address.city_id).to eq(c1.id)
      expect(address.district_id).to eq(d1.id)
    end
  end
end
