require "spec_helper"

RSpec.describe LcpRuby::DataSource::RestJson do
  let(:model_def) do
    LcpRuby::Metadata::ModelDefinition.new(
      name: "test_building",
      fields: [
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "name", "type" => "string"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "address", "type" => "string"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "floors", "type" => "integer")
      ],
      data_source_config: config
    )
  end

  let(:config) do
    {
      "type" => "rest_json",
      "base_url" => "https://api.example.com",
      "resource" => "buildings",
      "timeout" => 5,
      "field_mapping" => { "name" => "building_name" },
      "endpoints" => {
        "show" => { "path" => "buildings/:id", "response_path" => "data" },
        "search" => { "method" => "GET", "response_path" => "data.items", "total_count_path" => "data.total" }
      },
      "pagination" => { "style" => "offset_limit" }
    }
  end

  before do
    builder = LcpRuby::ModelFactory::ApiBuilder.new(model_def)
    model_class = builder.build
    LcpRuby.registry.register("test_building", model_class)
  end

  subject { described_class.new(config, model_def) }

  def stub_http_response(status:, body:)
    response = instance_double(Net::HTTPResponse, code: status.to_s, body: body.to_json)
    allow(response).to receive(:is_a?).with(anything).and_return(false)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(status >= 200 && status < 300)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:new).and_return(http)
    http
  end

  def stub_http_error(error_class)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_raise(error_class)
    allow(Net::HTTP).to receive(:new).and_return(http)
    http
  end

  describe "#find" do
    it "makes HTTP GET and hydrates response" do
      response_body = { "data" => { "id" => "1", "building_name" => "Tower A", "address" => "123 St", "floors" => 5 } }
      stub_http_response(status: 200, body: response_body)

      record = subject.find("1")
      expect(record.id).to eq("1")
      expect(record.name).to eq("Tower A")
      expect(record.address).to eq("123 St")
      expect(record.floors).to eq(5)
    end

    it "raises RecordNotFound on 404" do
      stub_http_response(status: 404, body: "Not Found")

      expect { subject.find("999") }.to raise_error(LcpRuby::DataSource::RecordNotFound)
    end

    it "raises ConnectionError on connection failure" do
      stub_http_error(Errno::ECONNREFUSED)

      expect { subject.find("1") }.to raise_error(LcpRuby::DataSource::ConnectionError)
    end
  end

  describe "#search" do
    it "makes HTTP GET with pagination params and parses response" do
      response_body = {
        "data" => {
          "items" => [
            { "id" => "1", "building_name" => "Tower A", "address" => "123 St", "floors" => 5 },
            { "id" => "2", "building_name" => "Tower B", "address" => "456 Ave", "floors" => 3 }
          ],
          "total" => 50
        }
      }
      stub_http_response(status: 200, body: response_body)

      result = subject.search
      expect(result).to be_a(LcpRuby::SearchResult)
      expect(result.total_count).to eq(50)
      expect(result.size).to eq(2)
      expect(result.first.name).to eq("Tower A")
    end
  end

  describe "#supported_operators" do
    it "returns operators from config when present" do
      config_with_ops = config.merge("supported_operators" => %w[eq cont])
      adapter = described_class.new(config_with_ops, model_def)
      expect(adapter.supported_operators).to eq(%w[eq cont])
    end

    it "returns defaults when not configured" do
      expect(subject.supported_operators).to include("eq", "cont")
    end
  end

  describe "authentication" do
    it "applies bearer auth" do
      config_with_auth = config.merge("auth" => { "type" => "bearer", "token_env" => "TEST_TOKEN" })
      allow(ENV).to receive(:fetch).with("TEST_TOKEN", nil).and_return("my-secret-token")

      adapter = described_class.new(config_with_auth, model_def)

      response_body = { "data" => { "id" => "1", "building_name" => "X" } }
      http = stub_http_response(status: 200, body: response_body)

      allow(http).to receive(:request) do |request|
        expect(request["Authorization"]).to eq("Bearer my-secret-token")
        response = instance_double(Net::HTTPResponse, code: "200", body: response_body.to_json)
        allow(response).to receive(:is_a?).with(anything).and_return(false)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        response
      end

      adapter.find("1")
    end
  end
end
