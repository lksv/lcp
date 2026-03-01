require "spec_helper"
require "support/integration_helper"

RSpec.describe "Not Found Handling", type: :request do
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
  end

  describe "unknown slug" do
    it "returns 404 with styled error page" do
      get "/nonexistent-slug"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Page not found")
      expect(response.body).to include("The page you requested could not be found.")
      expect(response.body).to include("lcp-error-page")
    end

    it "includes a back to home link" do
      get "/nonexistent-slug"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Back to home")
    end

    it "returns JSON error for JSON requests" do
      get "/nonexistent-slug", headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Page not found")
    end
  end

  describe "missing record" do
    it "returns 404 with styled error page" do
      get "/lists/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Page not found")
      expect(response.body).to include("The record you requested could not be found.")
      expect(response.body).to include("lcp-error-page")
    end

    it "returns JSON error for JSON requests" do
      get "/lists/999999", headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Record not found")
    end
  end

  describe "not_found_handler: :raise" do
    before(:each) do
      LcpRuby.configuration.not_found_handler = :raise
    end

    it "re-raises MetadataError for unknown slug instead of rendering styled page" do
      get "/nonexistent-slug"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).not_to include("lcp-error-page")
    end

    it "re-raises RecordNotFound for missing record instead of rendering styled page" do
      get "/lists/999999"

      # Rails middleware maps RecordNotFound to 404 even when re-raised,
      # but the response uses Rails' default error page, not our styled template
      expect(response.body).not_to include("lcp-error-page")
    end
  end
end
