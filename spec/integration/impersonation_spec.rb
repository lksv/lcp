require "spec_helper"
require "support/integration_helper"

RSpec.describe "Impersonation", type: :request do
  before(:all) do
    IntegrationHelper::FIXTURES_BASE
    # Use CRM fixtures which have multi-role permissions
  end

  before do
    load_integration_metadata!("crm")
    LcpRuby.configuration.impersonation_roles = [ "admin" ]
  end

  after { LcpRuby.configuration.impersonation_roles = [] }

  describe "POST /impersonate" do
    context "when user is admin (allowed to impersonate)" do
      before { stub_current_user(role: "admin") }

      it "sets impersonation session and redirects" do
        post "/impersonate", params: { role: "viewer" }
        expect(response).to redirect_to("/")
        follow_redirect!
      end

      it "returns alert when no role specified" do
        post "/impersonate", params: { role: "" }
        expect(response).to redirect_to("/")
        expect(flash[:alert]).to include("No role specified")
      end

      it "rejects non-existent role" do
        post "/impersonate", params: { role: "nonexistent" }
        expect(response).to redirect_to("/")
        expect(flash[:alert]).to include("not a valid role")
      end
    end

    context "when user is not allowed to impersonate" do
      before { stub_current_user(role: "viewer") }

      it "denies impersonation" do
        post "/impersonate", params: { role: "admin" }
        expect(response).to redirect_to("/")
        expect(flash[:alert]).to include("not authorized")
      end
    end

    context "when impersonation is disabled" do
      before do
        LcpRuby.configuration.impersonation_roles = []
        stub_current_user(role: "admin")
      end

      it "denies impersonation" do
        post "/impersonate", params: { role: "viewer" }
        expect(response).to redirect_to("/")
        expect(flash[:alert]).to include("not authorized")
      end
    end
  end

  describe "DELETE /impersonate" do
    before { stub_current_user(role: "admin") }

    it "clears impersonation and redirects" do
      delete "/impersonate"
      expect(response).to redirect_to("/")
      expect(flash[:notice]).to include("Stopped impersonation")
    end
  end

  describe "impersonation effect on pages" do
    before { stub_current_user(role: "admin") }

    it "shows impersonation banner when active" do
      post "/impersonate", params: { role: "viewer" }
      # viewer has access to deal_pipeline presenter (slug: pipeline)
      get "/pipeline"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Viewing as role")
      expect(response.body).to include("viewer")
      expect(response.body).to include("Stop impersonation")
    end

    it "restricts access based on impersonated role" do
      # Admin can access deal, but viewer cannot
      post "/impersonate", params: { role: "viewer" }
      get "/deals"

      # Viewer can't access deal presenter, should be denied
      expect(response).to have_http_status(:redirect)
    end

    it "shows role selector when impersonation is available but not active" do
      get "/deals"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("View as:")
      expect(response.body).to include("Impersonate")
    end
  end

  describe "authorization audit logging" do
    before { stub_current_user(role: "viewer") }

    it "publishes ActiveSupport::Notifications event on access denial" do
      events = []
      subscription = ActiveSupport::Notifications.subscribe("authorization.lcp_ruby") do |*, payload|
        events << payload
      end

      get "/deals"

      ActiveSupport::Notifications.unsubscribe(subscription)

      # First event from authorize_presenter_access, second from user_not_authorized rescue
      expect(events.size).to be >= 1
      presenter_event = events.find { |e| e[:action] == "access_presenter" }
      expect(presenter_event).to be_present
      expect(presenter_event[:resource]).to eq("deal")
      expect(presenter_event[:detail]).to eq("presenter access denied")
      expect(presenter_event[:user_id]).to eq(1)
      expect(presenter_event[:roles]).to include("viewer")
    end

    it "logs denial to Rails.logger" do
      allow(Rails.logger).to receive(:warn).and_call_original

      get "/deals"

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including("[LcpRuby::Auth] Access denied")
      ).at_least(:once)
    end
  end
end
