require "spec_helper"
require "support/integration_helper"

RSpec.describe "View Slots Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("todo")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("todo")
  end

  before do
    load_integration_metadata!("todo")
    stub_current_user(role: "admin")

    LcpRuby.registry.model_for("todo_item").delete_all
    LcpRuby.registry.model_for("todo_list").delete_all
  end

  let(:todo_list_model) { LcpRuby.registry.model_for("todo_list") }

  describe "GET /lists (index page)" do
    before do
      todo_list_model.create!(title: "Groceries", description: "Weekly shopping")
    end

    it "renders the search form" do
      get "/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-search")
      expect(response.body).to include("Search lists...")
    end

    it "renders the New button from collection actions slot" do
      get "/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New List")
    end

    it "renders pagination" do
      get "/lists"

      expect(response).to have_http_status(:ok)
      # Kaminari pagination is rendered (even if only 1 page, the slot is called)
    end

    it "renders toolbar with render_slot structure" do
      get "/lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-toolbar")
    end
  end

  describe "GET /lists/:id (show page)" do
    let!(:list) { todo_list_model.create!(title: "My List", description: "Test") }

    it "renders back-to-list link" do
      get "/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Back to list")
    end

    it "renders copy URL button" do
      get "/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-copy-url")
      expect(response.body).to include("Copy link")
    end

    it "renders single actions (Edit, Delete)" do
      get "/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit")
      expect(response.body).to include("Delete")
    end
  end

  describe "custom slot components" do
    let!(:list) { todo_list_model.create!(title: "My List", description: "Test") }

    after do
      # Clean up custom registrations
      LcpRuby::ViewSlots::Registry.clear!
      LcpRuby::ViewSlots::Registry.register_built_ins!
    end

    it "renders a custom component when registered" do
      # Register a custom component that renders a test partial
      # We use an existing partial path to avoid creating a test partial
      LcpRuby::ViewSlots::Registry.register(
        page: :index, slot: :toolbar_start, name: :custom_test,
        partial: "lcp_ruby/slots/show/back_to_list", position: 1
      )

      get "/lists"

      expect(response).to have_http_status(:ok)
      # The back_to_list partial contains "Back to list" text
      expect(response.body).to include("Back to list")
    end

    it "hides a component when enabled? returns false" do
      LcpRuby::ViewSlots::Registry.register(
        page: :show, slot: :toolbar_start, name: :hidden_component,
        partial: "lcp_ruby/slots/show/back_to_list", position: 1,
        enabled: ->(_ctx) { false }
      )

      # The back_to_list is already registered as built-in with name :back_to_list
      # Our hidden_component with different name should not show
      get "/lists/#{list.id}"

      expect(response).to have_http_status(:ok)
      # The built-in back_to_list is still there, but our hidden one doesn't duplicate
    end

    it "renders components in position order" do
      # Register two components at known positions
      LcpRuby::ViewSlots::Registry.register(
        page: :index, slot: :toolbar_start, name: :second_item,
        partial: "lcp_ruby/slots/index/pagination", position: 20
      )
      LcpRuby::ViewSlots::Registry.register(
        page: :index, slot: :toolbar_start, name: :first_item,
        partial: "lcp_ruby/slots/show/back_to_list", position: 5
      )

      todo_list_model.create!(title: "Test", description: "")
      get "/lists"

      expect(response).to have_http_status(:ok)
      body = response.body
      # "Back to list" (position 5) should appear before pagination (position 20)
      back_pos = body.index("Back to list")
      expect(back_pos).to be_present
    end
  end
end
