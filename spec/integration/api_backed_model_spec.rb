require "spec_helper"
require "support/integration_helper"

# Host provider for integration tests
class IntegrationTestBuildingProvider
  BUILDINGS = [
    { id: "1", name: "Tower Alpha", address: "123 Main St", floors: 10 },
    { id: "2", name: "Tower Beta", address: "456 Oak Ave", floors: 5 },
    { id: "3", name: "Tower Gamma", address: "789 Pine Rd", floors: 20 }
  ].freeze

  def find(id)
    data = BUILDINGS.find { |b| b[:id] == id.to_s }
    raise LcpRuby::DataSource::RecordNotFound, "Building #{id} not found" unless data

    model_class = LcpRuby.registry.model_for("external_building")
    record = model_class.new
    data.each { |k, v| record.send("#{k}=", v) if record.respond_to?("#{k}=") }
    record.instance_variable_set(:@persisted, true)
    record
  end

  def find_many(ids)
    ids.filter_map do |id|
      find(id)
    rescue LcpRuby::DataSource::RecordNotFound
      nil
    end
  end

  def search(params = {}, sort: nil, page: 1, per: 25)
    records = BUILDINGS.map do |data|
      model_class = LcpRuby.registry.model_for("external_building")
      record = model_class.new
      data.each { |k, v| record.send("#{k}=", v) if record.respond_to?("#{k}=") }
      record.instance_variable_set(:@persisted, true)
      record
    end

    # Apply filters if provided
    if params.is_a?(Array)
      params.each do |filter|
        field = filter[:field]
        value = filter[:value]
        operator = filter[:operator]

        records = records.select do |r|
          record_value = r.respond_to?(field) ? r.send(field).to_s : ""
          case operator
          when "eq" then record_value == value.to_s
          when "cont" then record_value.downcase.include?(value.to_s.downcase)
          else true
          end
        end
      end
    end

    LcpRuby::SearchResult.new(
      records: records,
      total_count: records.size,
      current_page: page,
      per_page: per
    )
  end

  def select_options(search: nil, filter: {}, sort: nil, label_method: "to_label", limit: 200)
    BUILDINGS.map { |b| { id: b[:id], label: b[:name] } }
  end
end

RSpec.describe "API-backed models", type: :request do
  before(:each) do
    load_integration_metadata!("api_model")
    stub_current_user(role: "admin")
  end

  describe "GET /external-buildings (API model index)" do
    it "renders index page with data from API source" do
      get "/external-buildings"
      expect(response).to have_http_status(:ok)
      # API model data should appear in the table
      expect(response.body).to include("Tower Alpha")
    end

    it "supports pagination" do
      get "/external-buildings", params: { page: 1 }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /external-buildings/:id (API model show)" do
    it "renders show page with data from API source" do
      get "/external-buildings/1"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tower Alpha")
      expect(response.body).to include("123 Main St")
    end

    it "returns 404 for non-existent record" do
      get "/external-buildings/999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "write actions on API model" do
    it "returns 404 for new" do
      get "/external-buildings/new"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for create" do
      post "/external-buildings", params: { record: { name: "Test" } }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for edit" do
      get "/external-buildings/1/edit"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for update" do
      patch "/external-buildings/1", params: { record: { name: "Updated" } }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for destroy" do
      delete "/external-buildings/1"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "cross-source association (DB belongs_to API)" do
    it "allows DB model to reference API model" do
      work_order_class = LcpRuby.registry.model_for("work_order")
      work_order = work_order_class.create!(title: "Fix elevator", external_building_id: "1")

      get "/work-orders/#{work_order.id}"
      expect(response).to have_http_status(:ok)

      # The work order should be viewable
      expect(response.body).to include("Fix elevator")
    end
  end

  describe "model definition" do
    it "identifies API models correctly" do
      building_def = LcpRuby.loader.model_definition("external_building")
      expect(building_def.api_model?).to be true
      expect(building_def.data_source_type).to eq(:host)
    end

    it "identifies DB models correctly" do
      work_order_def = LcpRuby.loader.model_definition("work_order")
      expect(work_order_def.api_model?).to be false
      expect(work_order_def.data_source_type).to eq(:db)
    end
  end

  describe "model class" do
    it "API model includes ApiModelConcern" do
      building_class = LcpRuby.registry.model_for("external_building")
      expect(building_class.lcp_api_model?).to be true
      expect(building_class.ancestors).not_to include(ActiveRecord::Base)
    end

    it "DB model is ActiveRecord::Base" do
      work_order_class = LcpRuby.registry.model_for("work_order")
      expect(work_order_class.ancestors).to include(ActiveRecord::Base)
    end
  end
end
