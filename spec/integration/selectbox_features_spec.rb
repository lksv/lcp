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
        post "/deals", params: {
          record: { title: "Big Deal", company_id: company.id, stage: "lead" }
        }
      }.to change { deal_model.count }.by(1)
    end

    it "rejects creating a deal with a nonexistent company_id" do
      post "/deals", params: {
        record: { title: "Bad Deal", company_id: 999999, stage: "lead" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("not allowed")
    end

    it "allows updating a deal with a valid company_id" do
      company = company_model.create!(name: "Acme Corp", industry: "technology")
      company2 = company_model.create!(name: "Beta Inc", industry: "finance")
      deal = deal_model.create!(title: "Deal 1", company_id: company.id, stage: "lead")

      patch "/deals/#{deal.id}", params: {
        record: { company_id: company2.id }
      }

      expect(response).to have_http_status(:redirect)
      deal.reload
      expect(deal.company_id).to eq(company2.id)
    end

    it "rejects updating a deal with a nonexistent company_id" do
      company = company_model.create!(name: "Acme Corp", industry: "technology")
      deal = deal_model.create!(title: "Deal 1", company_id: company.id, stage: "lead")

      patch "/deals/#{deal.id}", params: {
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
        post "/deals", params: {
          record: { title: "Deal", company_id: acme.id, contact_id: john.id, stage: "lead" }
        }
      }.to change { deal_model.count }.by(1)
    end
  end

  describe "1d: default value from metadata" do
    it "renders new form (no error)" do
      get "/deals/new"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "3c: I18n strings" do
    it "renders form with translated submit button" do
      get "/deals/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("lcp_ruby.form.create"))
      expect(response.body).to include(I18n.t("lcp_ruby.form.cancel"))
    end

    it "renders edit form with translated update button" do
      company = company_model.create!(name: "Acme", industry: "technology")
      deal = deal_model.create!(title: "Deal", company_id: company.id, stage: "lead")

      get "/deals/#{deal.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("lcp_ruby.form.update"))
    end

    it "uses translated error message for invalid association values" do
      post "/deals", params: {
        record: { title: "Bad", company_id: 999999, stage: "lead" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("lcp_ruby.form.errors.contains_not_allowed"))
    end
  end

  describe "select_options endpoint" do
    it "returns JSON options for company_id field" do
      company_model.create!(name: "Acme", industry: "technology")
      company_model.create!(name: "Beta", industry: "finance")

      get "/deals/select_options", params: { field: "company_id" }
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)
      # company_id has group_by: industry, so returns grouped format
      expect(data).to be_an(Array)
      expect(data.first).to have_key("group")
      expect(data.first).to have_key("options")

      all_options = data.flat_map { |g| g["options"] }
      expect(all_options.length).to eq(2)
      expect(all_options.map { |o| o["label"] }).to contain_exactly("Acme", "Beta")
    end

    it "returns empty array for unknown field" do
      get "/deals/select_options", params: { field: "nonexistent_field" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "filters options with depends_on parameter" do
      acme = company_model.create!(name: "Acme", industry: "technology")
      other = company_model.create!(name: "Other", industry: "finance")
      contact_model.create!(first_name: "John", last_name: "Doe", company_id: acme.id)
      contact_model.create!(first_name: "Jane", last_name: "Smith", company_id: other.id)

      get "/deals/select_options", params: {
        field: "contact_id",
        depends_on: { "company_id" => acme.id }
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
      expect(data.first["label"]).to include("John")
    end

    it "returns all options when depends_on parent is absent" do
      acme = company_model.create!(name: "Acme", industry: "technology")
      other = company_model.create!(name: "Other", industry: "finance")
      contact_model.create!(first_name: "John", last_name: "Doe", company_id: acme.id)
      contact_model.create!(first_name: "Jane", last_name: "Smith", company_id: other.id)

      get "/deals/select_options", params: { field: "contact_id" }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(2)
    end
  end

  describe "select_options search mode" do
    before do
      # Create companies with distinctive names for search testing
      company_model.create!(name: "Alpha Corp", industry: "technology")
      company_model.create!(name: "Alpha Ltd", industry: "finance")
      company_model.create!(name: "Beta Inc", industry: "technology")
      company_model.create!(name: "Gamma LLC", industry: "healthcare")
    end

    it "returns paginated results when page param is present" do
      get "/deals/select_options", params: {
        field: "company_id",
        page: 1,
        per_page: 2
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to have_key("options")
      expect(data).to have_key("has_more")
      expect(data).to have_key("total")
      expect(data["options"].length).to eq(2)
      expect(data["total"]).to eq(4)
      expect(data["has_more"]).to be true
    end

    it "returns second page of results" do
      get "/deals/select_options", params: {
        field: "company_id",
        page: 2,
        per_page: 2
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["options"].length).to eq(2)
      expect(data["has_more"]).to be false
    end

    it "caps per_page at 100" do
      get "/deals/select_options", params: {
        field: "company_id",
        page: 1,
        per_page: 999
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      # All 4 fit within the capped 100, so all are returned
      expect(data["options"].length).to eq(4)
      expect(data["has_more"]).to be false
    end
  end

  describe "ancestors_for reverse cascade" do
    it "resolves ancestor chain for contact_id field" do
      acme = company_model.create!(name: "Acme Corp", industry: "technology")
      john = contact_model.create!(first_name: "John", last_name: "Doe", company_id: acme.id)

      get "/deals/select_options", params: {
        field: "contact_id",
        ancestors_for: john.id
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to have_key("ancestors")
      ancestors = data["ancestors"]
      expect(ancestors.length).to eq(1)
      expect(ancestors.first["field"]).to eq("company_id")
      expect(ancestors.first["value"]).to eq(acme.id)
      expect(ancestors.first["label"]).to eq("Acme Corp")
    end

    it "returns empty ancestors when field has no depends_on" do
      company_model.create!(name: "Acme", industry: "technology")

      get "/deals/select_options", params: {
        field: "company_id",
        ancestors_for: 1
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["ancestors"]).to eq([])
    end

    it "returns empty ancestors for nonexistent record" do
      get "/deals/select_options", params: {
        field: "contact_id",
        ancestors_for: 999999
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["ancestors"]).to eq([])
    end
  end

  describe "inline_create permission filtering" do
    it "denies inline_create for role without create permission" do
      stub_current_user(role: "viewer")

      post "/deals/inline_create", params: {
        target_model: "company",
        label_method: "name",
        inline_record: { name: "Test Co", industry: "technology" }
      }

      # Viewer doesn't have create permission on company (default permissions)
      expect(response).not_to have_http_status(:created)
      expect(company_model.find_by(name: "Test Co")).to be_nil
    end

    it "allows inline_create for role with create permission" do
      stub_current_user(role: "admin")

      expect {
        post "/deals/inline_create", params: {
          target_model: "company",
          label_method: "name",
          inline_record: { name: "Admin Co", industry: "finance" }
        }
      }.to change { company_model.count }.by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe "3a: inline create endpoints" do
    it "GET inline_create_form returns HTML for target model" do
      get "/deals/inline_create_form", params: { target_model: "company" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("inline_record[name]")
      expect(response.body).to include("inline_record[industry]")
    end

    it "GET inline_create_form returns bad_request without target_model" do
      get "/deals/inline_create_form"
      expect(response).to have_http_status(:bad_request)
    end

    it "POST inline_create creates a record and returns JSON" do
      expect {
        post "/deals/inline_create", params: {
          target_model: "company",
          label_method: "name",
          inline_record: { name: "New Company", industry: "technology" }
        }
      }.to change { company_model.count }.by(1)

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)
      expect(data["id"]).to be_present
      expect(data["label"]).to eq("New Company")
    end

    it "POST inline_create returns errors for invalid record" do
      post "/deals/inline_create", params: {
        target_model: "company",
        inline_record: { name: "", industry: "technology" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      data = JSON.parse(response.body)
      expect(data["errors"]).to be_an(Array)
      expect(data["errors"].any? { |e| e.include?("Name") || e.include?("blank") }).to be true
    end

    it "POST inline_create returns bad_request without target_model" do
      post "/deals/inline_create", params: {
        inline_record: { name: "Test" }
      }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
