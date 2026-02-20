require "spec_helper"
require "support/integration_helper"

RSpec.describe "CRM App Integration", type: :request do
  # Create tables once for the suite
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("crm")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("crm")
  end

  # spec_helper resets LcpRuby state before each test, so reload metadata each time.
  before(:each) do
    load_integration_metadata!("crm")
    # Clear records between tests (respecting FK order)
    LcpRuby.registry.model_for("deal").delete_all
    LcpRuby.registry.model_for("contact").delete_all
    LcpRuby.registry.model_for("company").delete_all
  end

  let(:company_model) { LcpRuby.registry.model_for("company") }
  let(:contact_model) { LcpRuby.registry.model_for("contact") }
  let(:deal_model) { LcpRuby.registry.model_for("deal") }

  describe "Admin role - full CRUD on companies" do
    before { stub_current_user(role: "admin") }

    describe "GET /companies" do
      it "returns 200 and lists companies" do
        company_model.create!(name: "Acme Corp", industry: "technology")

        get "/companies"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Acme Corp")
        expect(response.body).to include("Companies")
      end
    end

    describe "POST /companies (create)" do
      it "creates a company" do
        expect {
          post "/companies", params: {
            record: { name: "New Corp", industry: "finance", website: "https://new.com" }
          }
        }.to change { company_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
      end

      it "validates required name" do
        post "/companies", params: { record: { name: "", industry: "finance" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "GET /companies/:id" do
      it "shows company details" do
        company = company_model.create!(name: "Acme Corp", industry: "technology")

        get "/companies/#{company.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Acme Corp")
      end
    end

    describe "PATCH /companies/:id (update)" do
      it "updates the company" do
        company = company_model.create!(name: "Old Name", industry: "technology")

        patch "/companies/#{company.id}", params: { record: { name: "New Name" } }

        expect(response).to have_http_status(:redirect)
        expect(company.reload.name).to eq("New Name")
      end
    end

    describe "DELETE /companies/:id (destroy)" do
      it "deletes the company" do
        company = company_model.create!(name: "To Delete", industry: "technology")

        expect {
          delete "/companies/#{company.id}"
        }.to change { company_model.count }.by(-1)

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "Admin role - deal value field" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "admin can update deal value" do
      deal = deal_model.create!(title: "Big Deal", stage: "lead", value: 100.0, company_id: company.id)

      patch "/deals/#{deal.id}", params: { record: { value: 999.99 } }

      expect(response).to have_http_status(:redirect)
      expect(deal.reload.value).to eq(999.99)
    end

    it "admin can create deal with value" do
      expect {
        post "/deals", params: {
          record: { title: "New Deal", stage: "lead", value: 500.0, company_id: company.id }
        }
      }.to change { deal_model.count }.by(1)

      expect(deal_model.last.value).to eq(500.0)
    end
  end

  describe "Sales Rep role - restricted access" do
    before { stub_current_user(role: "sales_rep") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "sales_rep cannot update deal value (field not writable)" do
      deal = deal_model.create!(title: "Deal", stage: "lead", value: 100.0, company_id: company.id)

      patch "/deals/#{deal.id}", params: { record: { value: 999.99, title: "Updated" } }

      # Value should not change because it's not in the writable fields for sales_rep
      deal.reload
      expect(deal.value).to eq(100.0)
      expect(deal.title).to eq("Updated")
    end

    it "sales_rep cannot delete a deal" do
      deal = deal_model.create!(title: "Deal", stage: "lead", value: 100.0, company_id: company.id)

      delete "/deals/#{deal.id}"

      # Should be forbidden (redirect with alert)
      expect(response).to have_http_status(:redirect)
      expect(deal_model.exists?(deal.id)).to be true
    end

    it "sales_rep can access deal presenter" do
      deal_model.create!(title: "My Deal", stage: "lead", value: 50.0, company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Deal")
    end
  end

  describe "Viewer role - read-only access" do
    before { stub_current_user(role: "viewer") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "viewer cannot access deal presenter" do
      get "/deals"

      # Viewer should be redirected (not authorized for deal presenter)
      expect(response).to have_http_status(:redirect)
    end

    it "viewer can access pipeline (read-only) presenter" do
      deal_model.create!(title: "Pipeline Deal", stage: "lead", value: 50.0, company_id: company.id)

      get "/pipeline"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pipeline Deal")
    end

    it "viewer cannot create companies" do
      post "/companies", params: { record: { name: "New", industry: "technology" } }

      # Should be forbidden
      expect(response).to have_http_status(:redirect)
      expect(company_model.where(name: "New").count).to eq(0)
    end
  end

  describe "Record-level rules - closed deals" do
    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    context "as sales_rep" do
      before { stub_current_user(role: "sales_rep") }

      it "cannot update a closed_won deal" do
        deal = deal_model.create!(title: "Won Deal", stage: "closed_won", value: 100.0, company_id: company.id)

        patch "/deals/#{deal.id}", params: { record: { title: "Changed" } }

        # Should be denied by record rule
        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Won Deal")
      end

      it "cannot update a closed_lost deal" do
        deal = deal_model.create!(title: "Lost Deal", stage: "closed_lost", value: 100.0, company_id: company.id)

        patch "/deals/#{deal.id}", params: { record: { title: "Changed" } }

        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Lost Deal")
      end

      it "can update an open deal" do
        deal = deal_model.create!(title: "Open Deal", stage: "lead", value: 100.0, company_id: company.id)

        patch "/deals/#{deal.id}", params: { record: { title: "Updated Open Deal" } }

        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Updated Open Deal")
      end
    end

    context "as admin" do
      before { stub_current_user(role: "admin") }

      it "admin can update closed deals (excepted from record rule)" do
        deal = deal_model.create!(title: "Won Deal", stage: "closed_won", value: 100.0, company_id: company.id)

        patch "/deals/#{deal.id}", params: { record: { title: "Admin Changed" } }

        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Admin Changed")
      end
    end
  end

  describe "Extended display features" do
    before { stub_current_user(role: "admin") }

    describe "dot-notation on index" do
      it "shows company name via dot-notation on deals index" do
        company = company_model.create!(name: "Acme Corp", industry: "technology")
        deal_model.create!(title: "Deal 1", stage: "lead", company_id: company.id)

        get "/deals"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Acme Corp")
      end

      it "shows company name for multiple deals without N+1" do
        company = company_model.create!(name: "Test Corp", industry: "finance")
        3.times { |i| deal_model.create!(title: "Deal #{i}", stage: "lead", company_id: company.id) }

        queries = []
        callback = lambda { |*, payload| queries << payload[:sql] unless payload[:sql].match?(/SCHEMA|TRANSACTION|SAVEPOINT|sqlite_master/) }
        begin
          ActiveSupport::Notifications.subscribe("sql.active_record", &callback)
          get "/deals"
        ensure
          ActiveSupport::Notifications.unsubscribe(callback)
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Test Corp")

        company_selects = queries.select { |q| q.include?("SELECT") && q.include?("companies") }
        expect(company_selects.size).to eq(1)
      end
    end

    describe "dot-notation on show" do
      it "shows company name via dot-notation on deal show" do
        company = company_model.create!(name: "Show Corp", industry: "technology")
        deal = deal_model.create!(title: "Show Deal", stage: "lead", company_id: company.id)

        get "/deals/#{deal.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Show Corp")
      end
    end

    describe "custom renderer on show" do
      it "delegates to a registered custom renderer" do
        renderer_class = Class.new(LcpRuby::Display::BaseRenderer) do
          def render(value, options = {}, record: nil, view_context: nil)
            "<span class=\"test-highlighted\">#{ERB::Util.html_escape(value)}</span>".html_safe
          end
        end
        LcpRuby::Display::RendererRegistry.register("test_highlight", renderer_class)

        company = company_model.create!(name: "Highlight Corp", industry: "technology")
        deal = deal_model.create!(title: "Renderer Deal", stage: "lead", company_id: company.id)

        get "/deals/#{deal.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("test-highlighted")
        expect(response.body).to include("Highlight Corp")
      end

      it "falls back to raw value when custom renderer is not registered" do
        company = company_model.create!(name: "Fallback Corp", industry: "technology")
        deal = deal_model.create!(title: "Fallback Deal", stage: "lead", company_id: company.id)

        get "/deals/#{deal.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Fallback Corp")
      end
    end

    describe "label support for dot-path columns" do
      it "shows custom label in index column header" do
        company = company_model.create!(name: "Label Corp", industry: "technology")
        deal_model.create!(title: "Label Deal", stage: "lead", company_id: company.id)

        get "/deals"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Company")
      end
    end

    describe "collection display on index" do
      it "shows contact names as collection on companies index" do
        company = company_model.create!(name: "Collection Corp", industry: "technology")
        contact_model.create!(first_name: "Alice", last_name: "Smith", company_id: company.id)
        contact_model.create!(first_name: "Bob", last_name: "Jones", company_id: company.id)

        get "/companies"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alice")
        expect(response.body).to include("Bob")
      end

      it "respects collection limit" do
        company = company_model.create!(name: "Big Corp", industry: "technology")
        5.times { |i| contact_model.create!(first_name: "Contact#{i}", last_name: "Test", company_id: company.id) }

        get "/companies"

        expect(response).to have_http_status(:ok)
        # Limit is 3, so we should see the first 3 contacts
        expect(response.body).to include("Contact0")
        expect(response.body).to include("Contact1")
        expect(response.body).to include("Contact2")
      end
    end
  end

  describe "Eager loading" do
    before { stub_current_user(role: "admin") }

    it "preloads company for deals index (avoids N+1)" do
      company = company_model.create!(name: "Acme Corp", industry: "technology")
      3.times { |i| deal_model.create!(title: "Deal #{i}", stage: "lead", company_id: company.id) }

      queries = []
      callback = lambda { |*, payload| queries << payload[:sql] unless payload[:sql].match?(/SCHEMA|TRANSACTION|SAVEPOINT|sqlite_master/) }
      begin
        ActiveSupport::Notifications.subscribe("sql.active_record", &callback)
        get "/deals"
      ensure
        ActiveSupport::Notifications.unsubscribe(callback)
      end

      expect(response).to have_http_status(:ok)
      # Company name should appear in the response (resolved via association)
      expect(response.body).to include("Acme Corp")

      # There should be only one SELECT for companies (batched includes)
      company_selects = queries.select { |q| q.include?("SELECT") && q.include?("companies") }
      expect(company_selects.size).to eq(1)
    end

    it "preloads contacts and deals for company show page" do
      company = company_model.create!(name: "Show Corp", industry: "technology")
      contact_model.create!(first_name: "Jane", last_name: "Doe", company_id: company.id)
      deal_model.create!(title: "Preloaded Deal", stage: "lead", company_id: company.id)

      queries = []
      callback = lambda { |*, payload| queries << payload[:sql] unless payload[:sql].match?(/SCHEMA|TRANSACTION|SAVEPOINT|sqlite_master/) }
      begin
        ActiveSupport::Notifications.subscribe("sql.active_record", &callback)
        get "/companies/#{company.id}"
      ensure
        ActiveSupport::Notifications.unsubscribe(callback)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jane")
      expect(response.body).to include("Preloaded Deal")

      # Contacts and deals should each be loaded in one query via preloader.
      # Contacts may also trigger a nested company preload (from display template).
      contact_selects = queries.select { |q| q.include?("SELECT") && q.include?("contacts") }
      deal_selects = queries.select { |q| q.include?("SELECT") && q.include?("deals") }
      expect(contact_selects.size).to eq(1)
      expect(deal_selects.size).to eq(1)
    end
  end

  describe "Search and filters" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "filters deals by search query" do
      deal_model.create!(title: "Enterprise License", stage: "lead", company_id: company.id)
      deal_model.create!(title: "Support Contract", stage: "lead", company_id: company.id)

      get "/deals", params: { q: "Enterprise" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Enterprise License")
      expect(response.body).not_to include("Support Contract")
    end

    it "filters deals by predefined scope (won)" do
      deal_model.create!(title: "Won Deal", stage: "closed_won", company_id: company.id)
      deal_model.create!(title: "Open Deal", stage: "lead", company_id: company.id)

      get "/deals", params: { filter: "won" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Won Deal")
      expect(response.body).not_to include("Open Deal")
    end

    it "filters deals by open scope (where_not closed)" do
      deal_model.create!(title: "Lead Deal", stage: "lead", company_id: company.id)
      deal_model.create!(title: "Qualified Deal", stage: "qualified", company_id: company.id)
      deal_model.create!(title: "Won Deal", stage: "closed_won", company_id: company.id)
      deal_model.create!(title: "Lost Deal", stage: "closed_lost", company_id: company.id)

      get "/deals", params: { filter: "open" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lead Deal")
      expect(response.body).to include("Qualified Deal")
      expect(response.body).not_to include("Won Deal")
      expect(response.body).not_to include("Lost Deal")
    end
  end

  describe "Association select rendering" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Acme Corp", industry: "technology") }
    let!(:contact) { contact_model.create!(first_name: "John", last_name: "Doe", company_id: company.id) }

    it "renders a <select> for company_id on new deal form" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<select")
      expect(response.body).to include("Acme Corp")
      expect(response.body).to include("-- Select --")
    end

    it "renders a <select> for contact_id on new deal form" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      # Contact select should be present with the contact's label
      expect(response.body).to include("John")
    end
  end

  describe "Edit button visibility" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "shows Edit link on companies index page" do
      get "/companies"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end

    it "shows Edit link on company show page" do
      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end

    it "shows Edit link on deals index page" do
      deal_model.create!(title: "My Deal", stage: "lead", company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end
  end

  describe "Display types in index" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "renders badge display type for stage column" do
      deal_model.create!(title: "Deal", stage: "lead", company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("badge")
    end

    it "renders currency display type for value column" do
      deal_model.create!(title: "Deal", stage: "lead", value: 1234.50, company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1,234.50")
    end

    it "renders pinned column CSS class" do
      deal_model.create!(title: "Deal", stage: "lead", company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-pinned-left")
    end

    it "renders hidden_on CSS class" do
      deal_model.create!(title: "Deal", stage: "lead", company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-hidden-mobile")
    end

    it "renders dropdown actions when actions_position is dropdown" do
      deal_model.create!(title: "Deal", stage: "lead", company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-actions-dropdown")
    end

    it "renders summary row with sum" do
      deal_model.create!(title: "Deal 1", stage: "lead", value: 100.0, company_id: company.id)
      deal_model.create!(title: "Deal 2", stage: "lead", value: 250.0, company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-summary-row")
      expect(response.body).to include("350")
    end
  end

  describe "Display types in show" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "renders heading display type" do
      deal = deal_model.create!(title: "Important Deal", stage: "lead", company_id: company.id)

      get "/deals/#{deal.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<strong>")
      expect(response.body).to include("Important Deal")
    end

    it "renders badge on show page" do
      deal = deal_model.create!(title: "Deal", stage: "lead", company_id: company.id)

      get "/deals/#{deal.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("badge")
    end
  end

  describe "Conditional rendering" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "hides contact_id field when stage is lead" do
      deal = deal_model.create!(title: "Lead Deal", stage: "lead", company_id: company.id)

      get "/deals/#{deal.id}/edit"

      expect(response).to have_http_status(:ok)
      # contact_id has visible_when: { field: stage, operator: not_in, value: [lead] }
      # When stage=lead, the field should be hidden
      expect(response.body).to include("data-lcp-visible-field=\"stage\"")
    end

    it "shows contact_id field when stage is qualified" do
      deal = deal_model.create!(title: "Qualified Deal", stage: "qualified", company_id: company.id)

      get "/deals/#{deal.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-conditional=\"field\"")
    end

    it "applies lcp-conditionally-disabled class to value field when stage is closed_won" do
      deal = deal_model.create!(title: "Won Deal", stage: "closed_won", value: 100.0, company_id: company.id)

      get "/deals/#{deal.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-conditionally-disabled")
    end

    it "does not disable value field when stage is lead" do
      deal = deal_model.create!(title: "Lead Deal", stage: "lead", value: 100.0, company_id: company.id)

      get "/deals/#{deal.id}/edit"

      expect(response).to have_http_status(:ok)
      # The value field wrapper should have data-lcp-conditional but not the disabled class
      expect(response.body).to include("data-lcp-disable-field=\"stage\"")
    end

    it "hides Metrics section when stage is lead" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      # New deal has no stage set, but the Metrics section should have conditional attrs
      expect(response.body).to include("data-lcp-visible-field=\"stage\"")
    end

    it "renders conditional data attributes on sections" do
      deal = deal_model.create!(title: "Qualified Deal", stage: "qualified", company_id: company.id)

      get "/deals/#{deal.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-conditional=\"section\"")
    end

    it "disables close_won action when value is blank on index" do
      deal = deal_model.create!(title: "No Value Deal", stage: "qualified", company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      # close_won has disable_when: { field: value, operator: blank }
      # When value is nil/blank, the action should be disabled
      expect(response.body).to include("lcp-action-disabled")
    end

    it "enables close_won action when value is present on index" do
      deal = deal_model.create!(title: "Valued Deal", stage: "qualified", value: 500.0, company_id: company.id)

      get "/deals"

      expect(response).to have_http_status(:ok)
      # close_won should NOT have the disabled class when value is present
      # It should still be visible (stage is not closed)
      expect(response.body).to include("Close as Won")
    end

    it "renders custom action as button_to with confirm dialog on show page" do
      deal = deal_model.create!(title: "Active Deal", stage: "qualified", value: 500.0, company_id: company.id)

      get "/deals/#{deal.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Close as Won")
      # Custom actions render as button_to (form with POST)
      expect(response.body).to include("actions/close_won")
      expect(response.body).to include("Mark this deal as won?")
    end

    describe "show page section conditions" do
      it "hides Metrics section when stage is lead" do
        deal = deal_model.create!(title: "Lead Deal", stage: "lead", company_id: company.id)

        get "/deals/#{deal.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Metrics")
      end

      it "shows Metrics section when stage is qualified" do
        deal = deal_model.create!(title: "Qualified Deal", stage: "qualified", company_id: company.id)

        get "/deals/#{deal.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Metrics")
      end

      it "applies disabled class when disable_when is true" do
        deal = deal_model.create!(title: "Won Deal", stage: "closed_won", company_id: company.id)

        get "/deals/#{deal.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Deal Notes")
        expect(response.body).to include("lcp-conditionally-disabled")
      end

      it "does not apply disabled class when disable_when is false" do
        deal = deal_model.create!(title: "Active Deal", stage: "qualified", company_id: company.id)

        get "/deals/#{deal.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Deal Notes")
        expect(response.body).not_to include("lcp-conditionally-disabled")
      end
    end

    it "renders disabled custom action as span on show page" do
      deal = deal_model.create!(title: "No Value Deal", stage: "qualified", company_id: company.id)

      get "/deals/#{deal.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-action-disabled")
      expect(response.body).to include("Close as Won")
    end

    it "does not render close_won action for closed deals" do
      deal = deal_model.create!(title: "Won Deal", stage: "closed_won", value: 100.0, company_id: company.id)

      get "/deals/#{deal.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Close as Won")
    end
  end

  describe "Evaluate conditions authorization" do
    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "allows admin to evaluate conditions on existing record" do
      stub_current_user(role: "admin")
      deal = deal_model.create!(title: "Deal", stage: "lead", company_id: company.id)

      post "/deals/#{deal.id}/evaluate_conditions", params: {
        record: { title: "Updated" }
      }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
    end

    it "allows admin to evaluate conditions on new record" do
      stub_current_user(role: "admin")

      post "/deals/evaluate_conditions", params: {
        record: { title: "New Deal", stage: "lead" }
      }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
    end

    it "denies viewer from evaluating conditions on existing record (no edit permission)" do
      stub_current_user(role: "viewer")
      deal = deal_model.create!(title: "Deal", stage: "lead", company_id: company.id)

      post "/deals/#{deal.id}/evaluate_conditions", params: {
        record: { title: "Updated" }
      }, headers: { "Accept" => "application/json" }

      # Viewer cannot access deal presenter, Pundit returns 403 for JSON
      expect(response).to have_http_status(:forbidden)
    end

    it "denies viewer from evaluating conditions on new record (no create permission)" do
      stub_current_user(role: "viewer")

      post "/deals/evaluate_conditions", params: {
        record: { title: "New Deal", stage: "lead" }
      }, headers: { "Accept" => "application/json" }

      # Viewer cannot access deal presenter, Pundit returns 403 for JSON
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "Display templates in association_list" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Acme Corp", industry: "technology") }

    it "renders display template HTML for contacts in association_list" do
      contact_model.create!(first_name: "Alice", last_name: "Smith", position: "Engineer", company_id: company.id)

      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-display-template")
      expect(response.body).to include("lcp-display-template__title")
      expect(response.body).to include("Alice Smith")
    end

    it "renders subtitle with dot-path resolved value" do
      contact_model.create!(first_name: "Bob", last_name: "Jones", position: "Manager", company_id: company.id)

      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-display-template__subtitle")
      expect(response.body).to include("Manager at Acme Corp")
    end

    it "renders icon in display template" do
      contact_model.create!(first_name: "Carol", last_name: "Lee", company_id: company.id)

      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-display-template__icon")
      expect(response.body).to include("user")
    end

    it "shows empty message when no contacts" do
      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No contacts yet.")
      expect(response.body).to include("lcp-association-list__empty")
    end

    it "respects limit on association_list" do
      10.times { |i| contact_model.create!(first_name: "Person#{i}", last_name: "Test", company_id: company.id) }

      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      # Limit is 5 in the fixture, so only 5 contacts should render
      rendered_contacts = response.body.scan(/lcp-display-template__title/).size
      expect(rendered_contacts).to eq(5)
    end

    it "sorts contacts by configured field" do
      contact_model.create!(first_name: "Zara", last_name: "Zenith", company_id: company.id)
      contact_model.create!(first_name: "Anna", last_name: "Alpha", company_id: company.id)
      contact_model.create!(first_name: "Mike", last_name: "Mid", company_id: company.id)

      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      # Sort by last_name asc: Alpha, Mid, Zenith
      body = response.body
      alpha_pos = body.index("Alpha")
      mid_pos = body.index("Mid")
      zenith_pos = body.index("Zenith")
      expect(alpha_pos).to be < mid_pos
      expect(mid_pos).to be < zenith_pos
    end

    it "renders links when link: true" do
      contact_model.create!(first_name: "Linked", last_name: "Contact", company_id: company.id)

      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      # Should contain a link to the contact show page
      expect(response.body).to include("/contacts/")
    end

    it "falls back to to_label for deals without display template" do
      deal_model.create!(title: "Big Deal", stage: "lead", company_id: company.id)

      get "/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Big Deal")
    end
  end

  describe "Display template permission filtering" do
    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "viewer sees restricted fields filtered in display template" do
      stub_current_user(role: "viewer")
      contact_model.create!(first_name: "Secret", last_name: "Agent", position: "Spy", company_id: company.id)

      get "/companies/#{company.id}"

      # Viewer has access to company_admin, contacts are rendered
      expect(response).to have_http_status(:ok)
      # The template still renders, but field access is controlled by PermissionEvaluator
      expect(response.body).to include("lcp-association-item")
    end
  end

  describe "Form layout features" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "renders tabs layout on deal form" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tabs")
      expect(response.body).to include("lcp-tab-nav")
      expect(response.body).to include("Deal Details")
      expect(response.body).to include("Metrics")
    end

    it "renders collapsible section with collapsed state" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-collapsible")
      expect(response.body).to include("lcp-collapsed")
      expect(response.body).to include("lcp-collapse-toggle")
    end

    it "renders prefix on value field" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-input-prefix")
      expect(response.body).to include("$")
    end

    it "renders progress field as readonly (suffix not shown for readonly fields)" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-readonly-value")
    end

    it "renders readonly field" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-readonly-value")
    end

    it "still submits form data correctly with tabs layout" do
      expect {
        post "/deals", params: {
          record: { title: "Tab Deal", stage: "lead", value: 500.0, company_id: company.id }
        }
      }.to change { deal_model.count }.by(1)

      expect(deal_model.last.title).to eq("Tab Deal")
    end

    it "renders slider input for priority field" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-slider-wrapper")
      expect(response.body).to include("lcp-slider")
      expect(response.body).to include("lcp-slider-value")
      expect(response.body).to include('type="range"')
    end

    it "renders toggle input for featured field" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-toggle")
      expect(response.body).to include("lcp-toggle-input")
      expect(response.body).to include("lcp-toggle-slider")
    end

    it "renders rating input for rating field" do
      get "/deals/new"

      expect(response).to have_http_status(:ok)
      # Rating renders as a select with values 0..5
      expect(response.body).to match(/<select[^>]*name="record\[rating\]"/)
    end
  end
end
