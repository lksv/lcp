require "spec_helper"
require "support/integration_helper"

RSpec.describe "Composite Page Rendering", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("composite")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("composite")
  end

  before(:each) do
    load_integration_metadata!("composite")
    employee_model.delete_all
    leave_request_model.delete_all
    training_model.delete_all
  end

  let(:employee_model) { LcpRuby.registry.model_for("comp_employee") }
  let(:leave_request_model) { LcpRuby.registry.model_for("comp_leave_request") }
  let(:training_model) { LcpRuby.registry.model_for("comp_training") }

  describe "basic composite rendering" do
    before { stub_current_user(role: "admin") }

    it "renders the composite show page with HTTP 200" do
      employee = employee_model.create!(name: "Alice", email: "alice@example.com", department: "Engineering", status: "active")

      get "/comp-employees/#{employee.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-semantic-layout")
      expect(response.body).to include("lcp-area-main")
    end

    it "renders the main zone with record details" do
      employee = employee_model.create!(name: "Bob", email: "bob@example.com", department: "Sales", status: "active")

      get "/comp-employees/#{employee.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bob")
      expect(response.body).to include("bob@example.com")
      expect(response.body).to include("Sales")
    end

    it "renders tab bar with tab zones" do
      employee = employee_model.create!(name: "Charlie", status: "active")

      get "/comp-employees/#{employee.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tab-bar")
      expect(response.body).to include("lcp-tab")
    end

    it "renders both tab links in the tab bar" do
      employee = employee_model.create!(name: "Alice", status: "active")

      get "/comp-employees/#{employee.id}"
      expect(response.body).to include("?tab=leave_requests")
      expect(response.body).to include("?tab=trainings")
    end
  end

  describe "tab navigation" do
    before { stub_current_user(role: "admin") }

    it "defaults to first tab when no tab param" do
      employee = employee_model.create!(name: "Alice", status: "active")
      leave_request_model.create!(employee_id: employee.id, start_date: Date.today, end_date: Date.tomorrow, status: "pending", reason: "Vacation")

      get "/comp-employees/#{employee.id}"
      expect(response).to have_http_status(:ok)
      # First tab (leave_requests) should be active
      expect(response.body).to include("lcp-tab-active")
      expect(response.body).to include("lcp-tab-content")
      expect(response.body).to include("Vacation")
    end

    it "switches tab when tab param is specified" do
      employee = employee_model.create!(name: "Alice", status: "active")
      training_model.create!(employee_id: employee.id, title: "Ruby Workshop", status: "completed")

      get "/comp-employees/#{employee.id}?tab=trainings"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ruby Workshop")
    end

    it "shows different content for different tabs" do
      employee = employee_model.create!(name: "Alice", status: "active")
      leave_request_model.create!(employee_id: employee.id, start_date: Date.today, end_date: Date.tomorrow, status: "pending", reason: "Vacation")
      training_model.create!(employee_id: employee.id, title: "Python Course", status: "scheduled")

      # Default tab shows leave requests
      get "/comp-employees/#{employee.id}"
      expect(response.body).to include("Vacation")
      expect(response.body).not_to include("Python Course")

      # Trainings tab shows trainings
      get "/comp-employees/#{employee.id}?tab=trainings"
      expect(response.body).to include("Python Course")
    end
  end

  describe "scope_context scoping" do
    before { stub_current_user(role: "admin") }

    it "scopes tab records to the parent record" do
      alice = employee_model.create!(name: "Alice", status: "active")
      bob = employee_model.create!(name: "Bob", status: "active")

      leave_request_model.create!(employee_id: alice.id, start_date: Date.today, end_date: Date.tomorrow, status: "pending", reason: "Alice leave")
      leave_request_model.create!(employee_id: bob.id, start_date: Date.today, end_date: Date.tomorrow, status: "pending", reason: "Bob leave")

      get "/comp-employees/#{alice.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice leave")
      expect(response.body).not_to include("Bob leave")
    end

    it "scopes training tab to the parent record" do
      alice = employee_model.create!(name: "Alice", status: "active")
      bob = employee_model.create!(name: "Bob", status: "active")

      training_model.create!(employee_id: alice.id, title: "Alice Training", status: "done")
      training_model.create!(employee_id: bob.id, title: "Bob Training", status: "done")

      get "/comp-employees/#{alice.id}?tab=trainings"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice Training")
      expect(response.body).not_to include("Bob Training")
    end
  end

  describe "per-zone authorization" do
    it "hides tab zone when user lacks presenter access" do
      # Use 'restricted' role which has no presenter access for comp_training
      stub_current_user(role: "restricted")

      employee = employee_model.create!(name: "Alice", status: "active")
      training_model.create!(employee_id: employee.id, title: "Secret Training", status: "done")

      get "/comp-employees/#{employee.id}?tab=trainings"
      expect(response).to have_http_status(:ok)
      # Training tab should not show data since 'restricted' has no presenter access
      expect(response.body).not_to include("Secret Training")
    end

    it "hides unauthorized tab link from the tab bar" do
      stub_current_user(role: "restricted")

      employee = employee_model.create!(name: "Alice", status: "active")

      get "/comp-employees/#{employee.id}"
      expect(response).to have_http_status(:ok)
      # Leave requests tab link should be visible
      expect(response.body).to include("?tab=leave_requests")
      # Trainings tab link should NOT appear since user has no presenter access
      expect(response.body).not_to include("?tab=trainings")
    end
  end

  describe "empty tab state" do
    before { stub_current_user(role: "admin") }

    it "renders empty tab content when no records match" do
      employee = employee_model.create!(name: "Alice", status: "active")
      # No leave requests created

      get "/comp-employees/#{employee.id}"
      expect(response).to have_http_status(:ok)
      # Tab bar should still render
      expect(response.body).to include("lcp-tab-bar")
      expect(response.body).to include("No records")
    end
  end

  describe "index page for composite model" do
    before { stub_current_user(role: "admin") }

    it "renders index page via the composite page slug" do
      employee_model.create!(name: "Alice", status: "active")

      get "/comp-employees"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
    end
  end

  describe "page definition" do
    it "detects composite page correctly" do
      page = LcpRuby.loader.page_definitions["comp_employee_detail"]
      expect(page).to be_present
      expect(page.composite?).to be true
      expect(page.has_tabs?).to be true
      expect(page.tab_zones.size).to eq(2)
    end

    it "presenters claimed by composite page do not get auto-pages" do
      # Presenters used as zones in the composite page are "claimed"
      # and don't get their own auto-generated pages
      expect(LcpRuby.loader.page_definitions["comp_employee_show"]).to be_nil
      expect(LcpRuby.loader.page_definitions["comp_leave_requests_index"]).to be_nil
      expect(LcpRuby.loader.page_definitions["comp_trainings_index"]).to be_nil
    end

    it "composite page zones have scope_context" do
      page = LcpRuby.loader.page_definitions["comp_employee_detail"]
      leave_zone = page.tab_zones.find { |z| z.name == "leave_requests" }
      expect(leave_zone.scope_context).to eq("employee_id" => ":record_id")
      expect(leave_zone.label_key).to eq("lcp_ruby.composite_test.tabs.leave_requests")
    end
  end
end
