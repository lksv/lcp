require "spec_helper"
require "support/integration_helper"

RSpec.describe "Authentication modes", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("todo")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("todo")
  end

  describe "external mode (default)" do
    before(:each) do
      load_integration_metadata!("todo")
      LcpRuby.configuration.authentication = :external
    end

    it "returns 500 when no current_user is provided" do
      get "/lists"
      expect(response).to have_http_status(:internal_server_error)
    end

    it "works when current_user is stubbed" do
      stub_current_user(role: "admin")
      get "/lists"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "none mode" do
    before(:each) do
      load_integration_metadata!("todo")
      LcpRuby.configuration.authentication = :none
    end

    it "allows access without login" do
      get "/lists"
      expect(response).to have_http_status(:ok)
    end

    it "provides a development user with admin role" do
      captured_user = nil
      allow_any_instance_of(LcpRuby::ApplicationController).to receive(:set_presenter_and_model).and_wrap_original do |m, *args|
        m.call(*args)
        captured_user = LcpRuby::Current.user
      end

      get "/lists"

      expect(response).to have_http_status(:ok)
      expect(captured_user).not_to be_nil
      expect(captured_user.name).to eq("Development User")
      expect(captured_user.lcp_role).to eq([ "admin" ])
    end
  end

  describe "view group public flag" do
    it "ViewGroupDefinition supports public attribute" do
      vg = LcpRuby::Metadata::ViewGroupDefinition.new(
        name: "public_view",
        model: "todo_list",
        primary_presenter: "todo_list",
        views: [ { "presenter" => "todo_list", "label" => "Lists" } ],
        public: true
      )
      expect(vg.public?).to be true
    end

    it "ViewGroupDefinition defaults public to false" do
      vg = LcpRuby::Metadata::ViewGroupDefinition.new(
        name: "private_view",
        model: "todo_list",
        primary_presenter: "todo_list",
        views: [ { "presenter" => "todo_list", "label" => "Lists" } ]
      )
      expect(vg.public?).to be false
    end

    it "parses public flag from YAML hash" do
      vg = LcpRuby::Metadata::ViewGroupDefinition.from_hash({
        "view_group" => {
          "name" => "test",
          "model" => "todo_list",
          "primary" => "todo_list",
          "public" => true,
          "views" => [ { "presenter" => "todo_list", "label" => "Lists" } ]
        }
      })
      expect(vg.public?).to be true
    end
  end
end
