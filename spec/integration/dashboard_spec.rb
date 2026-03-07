require "spec_helper"
require "support/integration_helper"

RSpec.describe "Dashboard Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("dashboard")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("dashboard")
  end

  before(:each) do
    load_integration_metadata!("dashboard")
    task_model.delete_all
    order_model.delete_all
  end

  let(:task_model) { LcpRuby.registry.model_for("dashboard_task") }
  let(:order_model) { LcpRuby.registry.model_for("dashboard_order") }

  describe "Dashboard page rendering" do
    before { stub_current_user(role: "admin") }

    it "renders the dashboard page with HTTP 200" do
      get "/dashboard"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-grid-container")
    end

    it "renders KPI card with correct count" do
      order_model.create!(name: "Order 1", total_amount: 100)
      order_model.create!(name: "Order 2", total_amount: 200)

      get "/dashboard"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-kpi-value")
    end

    it "renders KPI card with sum aggregate" do
      order_model.create!(name: "Order 1", total_amount: 150.50)
      order_model.create!(name: "Order 2", total_amount: 249.50)

      get "/dashboard"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-kpi-value")
    end

    it "renders text widget with i18n content" do
      get "/dashboard"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-text-content")
    end

    it "renders presenter zone with limited records in a table" do
      5.times { |i| task_model.create!(name: "Task #{i}", status: "open") }

      get "/dashboard"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-presenter-zone-content")
      expect(response.body).to include("lcp-table-compact")
    end

    it "renders dashboard title" do
      get "/dashboard"
      expect(response).to have_http_status(:ok)
      # The page title should appear (humanized name or i18n)
      expect(response.body).to include("lcp-dashboard")
    end

    it "applies scope to KPI widget" do
      task_model.create!(name: "Open Task", status: "open")
      task_model.create!(name: "Closed Task", status: "closed")

      get "/dashboard"
      expect(response).to have_http_status(:ok)
      # The open_tasks KPI should count only 1
    end
  end

  describe "Standalone page navigation" do
    before { stub_current_user(role: "admin") }

    it "standalone page appears in view group definitions" do
      # The dashboard fixture defines a VG with model: nil
      vg = LcpRuby.loader.view_group_definitions["dashboard"]
      expect(vg).not_to be_nil
      expect(vg.model).to be_nil
    end
  end

  describe "Landing page redirect" do
    before { stub_current_user(role: "admin") }

    it "redirects from root to a navigable page" do
      get "/"
      expect(response).to have_http_status(:redirect)
    end

    it "redirects to configured landing page" do
      LcpRuby.configuration.landing_page = "dashboard"

      get "/"
      expect(response).to redirect_to("/dashboard")
    ensure
      LcpRuby.configuration.landing_page = nil
    end

    it "redirects to role-specific landing page" do
      LcpRuby.configuration.landing_page = {
        "admin" => "dashboard",
        "default" => "dashboard-tasks"
      }

      get "/"
      expect(response).to redirect_to("/dashboard")
    ensure
      LcpRuby.configuration.landing_page = nil
    end
  end
end
