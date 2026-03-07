require "spec_helper"
require "support/integration_helper"

RSpec.describe "Pages Infrastructure", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("dialog")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("dialog")
  end

  before(:each) do
    load_integration_metadata!("dialog")
    stub_current_user(role: "admin")
  end

  describe "auto-pages are transparent" do
    it "existing CRUD flows work unchanged" do
      get "/contacts"
      expect(response).to have_http_status(:ok)

      get "/contacts/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("first_name")
    end

    it "index page renders table columns" do
      contact_model = LcpRuby.registry.model_for("contact")
      contact_model.delete_all
      contact_model.create!(first_name: "Alice", last_name: "Smith")

      get "/contacts"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).to include("Smith")
    end

    it "show page renders successfully" do
      contact_model = LcpRuby.registry.model_for("contact")
      contact_model.delete_all
      contact = contact_model.create!(first_name: "Bob", last_name: "Jones")

      get "/contacts/#{contact.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-resource-show")
    end

    it "create flow works through pages" do
      contact_model = LcpRuby.registry.model_for("contact")
      contact_model.delete_all

      post "/contacts", params: { record: { first_name: "Charlie", last_name: "Brown" } }

      expect(contact_model.count).to eq(1)
      expect(contact_model.last.first_name).to eq("Charlie")
    end
  end

  describe "page definitions" do
    it "auto-pages are created for each presenter" do
      expect(LcpRuby.loader.page_definitions["contacts"]).to be_present
      expect(LcpRuby.loader.page_definitions["contacts"].auto_generated?).to be true
    end

    it "auto-page slug matches presenter slug" do
      page = LcpRuby.loader.page_definitions["contacts"]
      presenter = LcpRuby.loader.presenter_definition("contacts")

      expect(page.slug).to eq(presenter.slug)
    end

    it "auto-page main zone references the presenter" do
      page = LcpRuby.loader.page_definitions["contacts"]

      expect(page.main_zone).to be_present
      expect(page.main_presenter_name).to eq("contacts")
    end

    it "dialog-only presenters get auto-pages without slug" do
      page = LcpRuby.loader.page_definitions["contact_quick_form"]

      expect(page).to be_present
      expect(page.routable?).to be false
      expect(page.dialog_only?).to be true
    end

    it "virtual model presenters get auto-pages" do
      page = LcpRuby.loader.page_definitions["bulk_status_change_dialog"]

      expect(page).to be_present
      expect(page.routable?).to be false
    end

    it "all presenters have corresponding pages" do
      LcpRuby.loader.presenter_definitions.each_key do |name|
        expect(LcpRuby.loader.page_definitions).to have_key(name),
          "Expected page definition for presenter '#{name}'"
      end
    end
  end

  describe "path helpers use page slug" do
    it "resources_path uses page slug" do
      get "/contacts"
      expect(response).to have_http_status(:ok)
      # The page URL is /contacts which equals the page slug
      expect(request.path).to eq("/contacts")
    end

    it "new_resource_path uses page slug" do
      get "/contacts/new"
      expect(response).to have_http_status(:ok)
      expect(request.path).to eq("/contacts/new")
    end
  end

  describe "Pages::Resolver" do
    it "finds page by slug" do
      page = LcpRuby::Pages::Resolver.find_by_slug("contacts")
      expect(page.name).to eq("contacts")
    end

    it "finds page by name" do
      page = LcpRuby::Pages::Resolver.find_by_name("contact_quick_form")
      expect(page.name).to eq("contact_quick_form")
    end

    it "lists only routable pages" do
      routable = LcpRuby::Pages::Resolver.routable_pages
      slugs = routable.map(&:slug)

      expect(slugs).to include("contacts")
      expect(routable.none? { |p| p.name == "contact_quick_form" }).to be true
    end
  end
end
