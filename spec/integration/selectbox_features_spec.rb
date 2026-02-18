require "spec_helper"
require "support/integration_helper"

RSpec.describe "Selectbox Features (Phase 1)", type: :request do
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
    stub_current_user(role: "admin")
  end

  let(:company_model) { LcpRuby.registry.model_for("company") }
  let(:contact_model) { LcpRuby.registry.model_for("contact") }
  let(:deal_model) { LcpRuby.registry.model_for("deal") }

  describe "1e: stale value validation" do
    it "allows creating a deal with a valid company_id" do
      company = company_model.create!(name: "Acme Corp", industry: "technology")

      expect {
        post "/admin/deals", params: {
          record: { title: "Big Deal", company_id: company.id, stage: "lead" }
        }
      }.to change { deal_model.count }.by(1)
    end

    it "rejects creating a deal with a nonexistent company_id" do
      post "/admin/deals", params: {
        record: { title: "Bad Deal", company_id: 999999, stage: "lead" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("not allowed")
    end

    it "allows updating a deal with a valid company_id" do
      company = company_model.create!(name: "Acme Corp", industry: "technology")
      company2 = company_model.create!(name: "Beta Inc", industry: "finance")
      deal = deal_model.create!(title: "Deal 1", company_id: company.id, stage: "lead")

      patch "/admin/deals/#{deal.id}", params: {
        record: { company_id: company2.id }
      }

      expect(response).to have_http_status(:redirect)
      deal.reload
      expect(deal.company_id).to eq(company2.id)
    end

    it "rejects updating a deal with a nonexistent company_id" do
      company = company_model.create!(name: "Acme Corp", industry: "technology")
      deal = deal_model.create!(title: "Deal 1", company_id: company.id, stage: "lead")

      patch "/admin/deals/#{deal.id}", params: {
        record: { company_id: 999999 }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("not allowed")
    end

    it "validates contact_id within depends_on scope" do
      acme = company_model.create!(name: "Acme Corp", industry: "technology")
      other = company_model.create!(name: "Other Corp", industry: "finance")
      john = contact_model.create!(first_name: "John", last_name: "Doe", company_id: acme.id)
      jane = contact_model.create!(first_name: "Jane", last_name: "Smith", company_id: other.id)

      # Submit a contact that belongs to the selected company — should work
      expect {
        post "/admin/deals", params: {
          record: { title: "Deal", company_id: acme.id, contact_id: john.id, stage: "lead" }
        }
      }.to change { deal_model.count }.by(1)
    end
  end

  describe "1d: default value from metadata" do
    it "renders new form (no error)" do
      get "/admin/deals/new"
      expect(response).to have_http_status(:ok)
    end
  end
end
