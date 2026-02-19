require "spec_helper"
require "support/integration_helper"

RSpec.describe "Menu Navigation Integration", type: :request do
  describe "top menu layout (menu.yml with top_menu)" do
    before(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.load_integration_metadata!("menu_test")
    end

    after(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.teardown_integration_tables!("menu_test")
    end

    before(:each) do
      load_integration_metadata!("menu_test")
      stub_current_user(role: "admin")
    end

    it "loads menu definition from menu.yml" do
      expect(LcpRuby.loader.menu_defined?).to be true
      expect(LcpRuby.loader.menu_definition.has_top_menu?).to be true
    end

    it "renders menu-driven top navigation" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-nav")
      expect(response.body).to include("Projects")
    end

    it "renders dropdown group" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-nav-dropdown")
      expect(response.body).to include("Work")
    end

    it "renders custom link in dropdown" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/reports")
      expect(response.body).to include("Reports")
    end

    it "renders admin-only group for admin users" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Admin")
    end

    it "hides admin-only group for non-admin users" do
      stub_current_user(role: "viewer")

      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Admin")
    end

    it "marks active menu item" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      # The projects link should have the active class
      expect(response.body).to match(/class="active"[^>]*href="\/projects"|href="\/projects"[^>]*class="active"/)
    end

    it "does not render sidebar" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("lcp-sidebar")
    end

    it "uses top layout class on body" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('class="lcp-layout-top"')
    end

    it "renders badge when data provider is registered" do
      provider = double("Provider")
      allow(provider).to receive(:call).and_return(3)
      LcpRuby::Services::Registry.register("data_providers", "open_projects", provider)

      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-menu-badge")
      expect(response.body).to include("3")
    end

    it "does not render badge when data provider returns nil" do
      provider = double("Provider")
      allow(provider).to receive(:call).and_return(nil)
      LcpRuby::Services::Registry.register("data_providers", "open_projects", provider)

      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("lcp-menu-badge")
    end

    it "does not render badge when data provider is not registered" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("lcp-menu-badge")
    end
  end

  describe "sidebar menu layout" do
    before(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.load_integration_metadata!("menu_sidebar_test")
    end

    after(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.teardown_integration_tables!("menu_sidebar_test")
    end

    before(:each) do
      load_integration_metadata!("menu_sidebar_test")
      stub_current_user(role: "admin")
    end

    it "renders sidebar navigation" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-sidebar")
      expect(response.body).to include("lcp-layout-with-sidebar")
    end

    it "renders sidebar groups" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-sidebar-group")
      expect(response.body).to include("Work")
    end

    it "uses sidebar layout class" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('class="lcp-layout-sidebar"')
    end

    it "renders bottom-pinned items" do
      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-sidebar-bottom")
    end

    it "hides role-restricted items for non-matching roles" do
      stub_current_user(role: "viewer")

      get "/projects"

      expect(response).to have_http_status(:ok)
      # Settings is admin-only in sidebar
      expect(response.body).not_to include("Settings")
    end
  end

  describe "auto mode without menu.yml" do
    before(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.load_integration_metadata!("menu_nav_false_test")
    end

    after(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.teardown_integration_tables!("menu_nav_false_test")
    end

    before(:each) do
      load_integration_metadata!("menu_nav_false_test")
      stub_current_user(role: "admin")
    end

    it "uses auto-generated top navigation" do
      expect(LcpRuby.loader.menu_defined?).to be false

      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-nav")
    end

    it "excludes view groups with navigation: false from auto nav" do
      helper = Object.new.extend(LcpRuby::LayoutHelper)
      entries = helper.navigable_presenters

      slugs = entries.map { |e| e[:slug] }
      expect(slugs).to include("projects")
      expect(slugs).to include("tasks")
      expect(slugs).not_to include("settings")
    end

    it "still allows direct access to non-navigable view group slugs" do
      get "/settings"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "auto mode with menu.yml auto-appends unreferenced VGs" do
    before(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.load_integration_metadata!("menu_auto_append_test")
    end

    after(:all) do
      helper = Object.new.extend(IntegrationHelper)
      helper.teardown_integration_tables!("menu_auto_append_test")
    end

    before(:each) do
      load_integration_metadata!("menu_auto_append_test")
      stub_current_user(role: "admin")
    end

    it "auto-appends navigable unreferenced view groups to top_menu" do
      menu = LcpRuby.loader.menu_definition

      vg_names = menu.top_menu.select(&:view_group?).map(&:view_group_name)
      expect(vg_names).to include("projects")
      expect(vg_names).to include("tasks")
    end

    it "does not auto-append view groups with navigation: false" do
      menu = LcpRuby.loader.menu_definition

      vg_names = menu.top_menu.select(&:view_group?).map(&:view_group_name)
      expect(vg_names).not_to include("settings")
    end

    it "renders auto-appended items in navigation" do
      get "/tasks"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tasks")
    end
  end

  describe "strict mode" do
    it "raises error when menu.yml is missing in strict mode" do
      LcpRuby.reset!
      LcpRuby::Types::BuiltInTypes.register_all!
      LcpRuby::Services::BuiltInTransforms.register_all!
      LcpRuby::Services::BuiltInDefaults.register_all!

      # Use fixture where VGs have navigation: false (valid for strict mode)
      fixture_path = File.join(IntegrationHelper::FIXTURES_BASE, "menu_strict_test")
      LcpRuby.configuration.metadata_path = fixture_path
      LcpRuby.configuration.menu_mode = :strict

      expect {
        LcpRuby.loader.load_all
      }.to raise_error(LcpRuby::MetadataError, /menu\.yml is required/)
    end

    it "raises error when VG has navigation config in strict mode" do
      LcpRuby.reset!
      LcpRuby::Types::BuiltInTypes.register_all!
      LcpRuby::Services::BuiltInTransforms.register_all!
      LcpRuby::Services::BuiltInDefaults.register_all!

      # menu_nav_false_test has VGs with navigation: {position: X} — invalid for strict
      fixture_path = File.join(IntegrationHelper::FIXTURES_BASE, "menu_nav_false_test")
      LcpRuby.configuration.metadata_path = fixture_path
      LcpRuby.configuration.menu_mode = :strict

      expect {
        LcpRuby.loader.load_all
      }.to raise_error(LcpRuby::MetadataError, /navigation config.*strict/)
    end
  end

  describe "menu_definition reference validation" do
    it "raises on unknown view group reference in menu.yml" do
      LcpRuby.reset!
      LcpRuby::Types::BuiltInTypes.register_all!
      LcpRuby::Services::BuiltInTransforms.register_all!
      LcpRuby::Services::BuiltInDefaults.register_all!

      fixture_path = File.join(IntegrationHelper::FIXTURES_BASE, "menu_test")
      LcpRuby.configuration.metadata_path = fixture_path

      loader = LcpRuby.loader
      loader.load_all

      # Inject a menu definition referencing a nonexistent view group
      bad_menu = LcpRuby::Metadata::MenuDefinition.from_hash(
        "top_menu" => [ { "view_group" => "nonexistent" } ]
      )
      loader.instance_variable_set(:@menu_definition, bad_menu)

      expect {
        loader.send(:validate_menu_references!)
      }.to raise_error(LcpRuby::MetadataError, /unknown view group 'nonexistent'/)
    end
  end
end
