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

    describe "GET /admin/companies" do
      it "returns 200 and lists companies" do
        company_model.create!(name: "Acme Corp", industry: "technology")

        get "/admin/companies"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Acme Corp")
        expect(response.body).to include("Companies")
      end
    end

    describe "POST /admin/companies (create)" do
      it "creates a company" do
        expect {
          post "/admin/companies", params: {
            record: { name: "New Corp", industry: "finance", website: "https://new.com" }
          }
        }.to change { company_model.count }.by(1)

        expect(response).to have_http_status(:redirect)
      end

      it "validates required name" do
        post "/admin/companies", params: { record: { name: "", industry: "finance" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "GET /admin/companies/:id" do
      it "shows company details" do
        company = company_model.create!(name: "Acme Corp", industry: "technology")

        get "/admin/companies/#{company.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Acme Corp")
      end
    end

    describe "PATCH /admin/companies/:id (update)" do
      it "updates the company" do
        company = company_model.create!(name: "Old Name", industry: "technology")

        patch "/admin/companies/#{company.id}", params: { record: { name: "New Name" } }

        expect(response).to have_http_status(:redirect)
        expect(company.reload.name).to eq("New Name")
      end
    end

    describe "DELETE /admin/companies/:id (destroy)" do
      it "deletes the company" do
        company = company_model.create!(name: "To Delete", industry: "technology")

        expect {
          delete "/admin/companies/#{company.id}"
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

      patch "/admin/deals/#{deal.id}", params: { record: { value: 999.99 } }

      expect(response).to have_http_status(:redirect)
      expect(deal.reload.value).to eq(999.99)
    end

    it "admin can create deal with value" do
      expect {
        post "/admin/deals", params: {
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

      patch "/admin/deals/#{deal.id}", params: { record: { value: 999.99, title: "Updated" } }

      # Value should not change because it's not in the writable fields for sales_rep
      deal.reload
      expect(deal.value).to eq(100.0)
      expect(deal.title).to eq("Updated")
    end

    it "sales_rep cannot delete a deal" do
      deal = deal_model.create!(title: "Deal", stage: "lead", value: 100.0, company_id: company.id)

      delete "/admin/deals/#{deal.id}"

      # Should be forbidden (redirect with alert)
      expect(response).to have_http_status(:redirect)
      expect(deal_model.exists?(deal.id)).to be true
    end

    it "sales_rep can access deal_admin presenter" do
      deal_model.create!(title: "My Deal", stage: "lead", value: 50.0, company_id: company.id)

      get "/admin/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Deal")
    end
  end

  describe "Viewer role - read-only access" do
    before { stub_current_user(role: "viewer") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "viewer cannot access deal_admin presenter" do
      get "/admin/deals"

      # Viewer should be redirected (not authorized for deal_admin presenter)
      expect(response).to have_http_status(:redirect)
    end

    it "viewer can access pipeline (read-only) presenter" do
      deal_model.create!(title: "Pipeline Deal", stage: "lead", value: 50.0, company_id: company.id)

      get "/admin/pipeline"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pipeline Deal")
    end

    it "viewer cannot create companies" do
      post "/admin/companies", params: { record: { name: "New", industry: "technology" } }

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

        patch "/admin/deals/#{deal.id}", params: { record: { title: "Changed" } }

        # Should be denied by record rule
        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Won Deal")
      end

      it "cannot update a closed_lost deal" do
        deal = deal_model.create!(title: "Lost Deal", stage: "closed_lost", value: 100.0, company_id: company.id)

        patch "/admin/deals/#{deal.id}", params: { record: { title: "Changed" } }

        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Lost Deal")
      end

      it "can update an open deal" do
        deal = deal_model.create!(title: "Open Deal", stage: "lead", value: 100.0, company_id: company.id)

        patch "/admin/deals/#{deal.id}", params: { record: { title: "Updated Open Deal" } }

        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Updated Open Deal")
      end
    end

    context "as admin" do
      before { stub_current_user(role: "admin") }

      it "admin can update closed deals (excepted from record rule)" do
        deal = deal_model.create!(title: "Won Deal", stage: "closed_won", value: 100.0, company_id: company.id)

        patch "/admin/deals/#{deal.id}", params: { record: { title: "Admin Changed" } }

        expect(response).to have_http_status(:redirect)
        expect(deal.reload.title).to eq("Admin Changed")
      end
    end
  end

  describe "Search and filters" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "filters deals by search query" do
      deal_model.create!(title: "Enterprise License", stage: "lead", company_id: company.id)
      deal_model.create!(title: "Support Contract", stage: "lead", company_id: company.id)

      get "/admin/deals", params: { q: "Enterprise" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Enterprise License")
      expect(response.body).not_to include("Support Contract")
    end

    it "filters deals by predefined scope (won)" do
      deal_model.create!(title: "Won Deal", stage: "closed_won", company_id: company.id)
      deal_model.create!(title: "Open Deal", stage: "lead", company_id: company.id)

      get "/admin/deals", params: { filter: "won" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Won Deal")
      expect(response.body).not_to include("Open Deal")
    end

    it "filters deals by open scope (where_not closed)" do
      deal_model.create!(title: "Lead Deal", stage: "lead", company_id: company.id)
      deal_model.create!(title: "Qualified Deal", stage: "qualified", company_id: company.id)
      deal_model.create!(title: "Won Deal", stage: "closed_won", company_id: company.id)
      deal_model.create!(title: "Lost Deal", stage: "closed_lost", company_id: company.id)

      get "/admin/deals", params: { filter: "open" }

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
      get "/admin/deals/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<select")
      expect(response.body).to include("Acme Corp")
      expect(response.body).to include("-- Select --")
    end

    it "renders a <select> for contact_id on new deal form" do
      get "/admin/deals/new"

      expect(response).to have_http_status(:ok)
      # Contact select should be present with the contact's label
      expect(response.body).to include("John")
    end
  end

  describe "Edit button visibility" do
    before { stub_current_user(role: "admin") }

    let!(:company) { company_model.create!(name: "Test Corp", industry: "technology") }

    it "shows Edit link on companies index page" do
      get "/admin/companies"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end

    it "shows Edit link on company show page" do
      get "/admin/companies/#{company.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end

    it "shows Edit link on deals index page" do
      deal_model.create!(title: "My Deal", stage: "lead", company_id: company.id)

      get "/admin/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
    end
  end
end
