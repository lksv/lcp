require "spec_helper"
require "support/integration_helper"

RSpec.describe "View Groups Integration", type: :request do
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
  let(:deal_model) { LcpRuby.registry.model_for("deal") }

  describe "view switcher on index page" do
    it "renders for grouped presenters with multiple views" do
      get "/admin/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-view-switcher")
      expect(response.body).to include("Detailed")
      expect(response.body).to include("Pipeline")
    end

    it "does not render for single-presenter groups" do
      get "/admin/companies"

      expect(response).to have_http_status(:ok)
      # The CSS class name appears in the layout stylesheet, so check for the actual div element
      expect(response.body).not_to include('<div class="lcp-view-switcher">')
    end
  end

  describe "switching between sibling views" do
    it "pipeline link points to the pipeline slug" do
      get "/admin/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/admin/pipeline")
    end
  end

  describe "view switcher on show page" do
    it "renders for grouped presenters" do
      company = company_model.create!(name: "Test Corp", industry: "technology")
      deal = deal_model.create!(title: "Big Deal", stage: "lead", company_id: company.id)

      get "/admin/deals/#{deal.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-view-switcher")
    end
  end

  describe "active view highlighting" do
    it "marks the current view as active on the deals index" do
      get "/admin/deals"

      expect(response).to have_http_status(:ok)
      # The deal_admin presenter renders "Detailed" with class "active"
      expect(response.body).to include('class="btn lcp-view-btn active"')
      expect(response.body).to match(/Detailed.*active|active.*Detailed/)
    end

    it "marks the pipeline view as active on the pipeline index" do
      get "/admin/pipeline"

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/Pipeline.*active|active.*Pipeline/)
    end
  end

  describe "navigable_presenters" do
    it "returns primary presenters from each group sorted by position" do
      helper = Object.new.extend(LcpRuby::LayoutHelper)
      entries = helper.navigable_presenters

      slugs = entries.map { |e| e[:slug] }
      # companies (position 1) should come before deals (position 3)
      expect(slugs).to eq(%w[companies deals])
    end

    it "excludes view groups whose primary presenter has no slug" do
      helper = Object.new.extend(LcpRuby::LayoutHelper)

      # Add a view group with a non-routable primary presenter
      non_routable = LcpRuby::Metadata::PresenterDefinition.from_hash(
        "name" => "hidden_admin", "model" => "company"
      )
      LcpRuby.loader.presenter_definitions["hidden_admin"] = non_routable

      vg = LcpRuby::Metadata::ViewGroupDefinition.new(
        name: "hidden_group",
        model: "company",
        primary_presenter: "hidden_admin",
        navigation_config: { "menu" => "main", "position" => 0 },
        views: [ { "presenter" => "hidden_admin" } ]
      )
      LcpRuby.loader.view_group_definitions["hidden_group"] = vg

      entries = helper.navigable_presenters
      names = entries.map { |e| e[:presenter].name }
      expect(names).not_to include("hidden_admin")
    ensure
      LcpRuby.loader.presenter_definitions.delete("hidden_admin")
      LcpRuby.loader.view_group_definitions.delete("hidden_group")
    end
  end

  describe "view group definitions" do
    it "loads the correct number of view groups from CRM fixtures" do
      view_groups = LcpRuby.loader.view_group_definitions

      # CRM has 2 explicit view groups: deals and companies
      expect(view_groups.keys).to contain_exactly("deals", "companies")
    end

    it "deals view group has two views" do
      deals_vg = LcpRuby.loader.view_group_definitions["deals"]

      expect(deals_vg.views.length).to eq(2)
      expect(deals_vg.presenter_names).to contain_exactly("deal_admin", "deal_pipeline")
      expect(deals_vg.has_switcher?).to be true
    end

    it "companies view group has one view and no switcher" do
      companies_vg = LcpRuby.loader.view_group_definitions["companies"]

      expect(companies_vg.views.length).to eq(1)
      expect(companies_vg.presenter_names).to contain_exactly("company_admin")
      expect(companies_vg.has_switcher?).to be false
    end
  end
end
