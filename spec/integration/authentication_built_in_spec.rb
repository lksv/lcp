require "spec_helper"
require "support/integration_helper"

# Tests for built-in (Devise) authentication mode.
# Devise is set up once in before(:all) to avoid repeated Devise.setup calls.
# Individual tests only need to ensure the config is correct (no route reload).
RSpec.describe "Authentication built-in mode", type: :request do
  before(:all) do
    # Create users table
    ActiveRecord::Schema.define do
      create_table :lcp_ruby_users, force: true do |t|
        t.string :name,               null: false
        t.json   :lcp_role,           default: [ "viewer" ]
        t.boolean :active,            null: false, default: true
        t.json   :profile_data,       default: {}
        t.string :email,              null: false, default: ""
        t.string :encrypted_password, null: false, default: ""
        t.string   :reset_password_token
        t.datetime :reset_password_sent_at
        t.datetime :remember_created_at
        t.integer  :sign_in_count, default: 0, null: false
        t.datetime :current_sign_in_at
        t.datetime :last_sign_in_at
        t.string   :current_sign_in_ip
        t.string   :last_sign_in_ip
        t.integer  :failed_attempts, default: 0, null: false
        t.string   :unlock_token
        t.datetime :locked_at
        t.timestamps null: false
      end

      add_index :lcp_ruby_users, :email,                unique: true unless index_exists?(:lcp_ruby_users, :email)
      add_index :lcp_ruby_users, :reset_password_token, unique: true unless index_exists?(:lcp_ruby_users, :reset_password_token)
      add_index :lcp_ruby_users, :unlock_token,         unique: true unless index_exists?(:lcp_ruby_users, :unlock_token)
    end

    # Load metadata ONCE
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("todo")
    LcpRuby.configuration.authentication = :built_in
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("todo")
    ActiveRecord::Base.connection.drop_table(:lcp_ruby_users, if_exists: true)
  end

  # Override the global before(:each) reset. We need to reload metadata
  # (since reset! clears it) but keep the Devise routes intact.
  before(:each) do
    # Re-register metadata without calling reset! again
    # (spec_helper already called reset!)
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Display::RendererRegistry.register_built_ins!

    fixture_path = File.join(IntegrationHelper::FIXTURES_BASE, "todo")
    LcpRuby.configuration.metadata_path = fixture_path
    LcpRuby.configuration.auto_migrate = true
    LcpRuby.configuration.authentication = :built_in

    loader = LcpRuby.loader
    loader.load_all
    loader.model_definitions.each_value do |model_def|
      builder = LcpRuby::ModelFactory::Builder.new(model_def)
      model_class = builder.build
      LcpRuby.registry.register(model_def.name, model_class)
    end

    LcpRuby::User.delete_all
  end

  let(:user) do
    LcpRuby::User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      lcp_role: [ "admin" ]
    )
  end

  describe "unauthenticated access" do
    it "redirects to login page" do
      get "/lists"

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to("/auth/login")
    end
  end

  describe "login page" do
    it "renders the login form" do
      get "/auth/login"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log in")
    end
  end

  describe "login flow" do
    it "authenticates valid credentials" do
      user # create the user

      post "/auth/login", params: {
        user: { email: "test@example.com", password: "password123" }
      }

      expect(response).to have_http_status(:redirect)
    end

    it "rejects invalid credentials" do
      user # create the user

      post "/auth/login", params: {
        user: { email: "test@example.com", password: "wrong" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "logout" do
    it "signs out and redirects to login" do
      user # create the user

      post "/auth/login", params: {
        user: { email: "test@example.com", password: "password123" }
      }

      delete "/auth/logout"

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "deactivated user" do
    it "prevents access for deactivated users" do
      user.update!(active: false)

      post "/auth/login", params: {
        user: { email: "test@example.com", password: "password123" }
      }
      get "/lists"

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "registration" do
    context "when registration is disabled" do
      before { LcpRuby.configuration.auth_allow_registration = false }

      it "returns 404 for registration page" do
        get "/auth/register"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when registration is enabled" do
      before { LcpRuby.configuration.auth_allow_registration = true }

      it "renders the registration form" do
        get "/auth/register"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Create account")
      end

      it "creates a new user" do
        post "/auth", params: {
          user: {
            name: "New User",
            email: "new@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }

        expect(response).to have_http_status(:redirect)
        expect(LcpRuby::User.find_by(email: "new@example.com")).to be_present
      end
    end
  end

  describe "password reset" do
    it "renders forgot password form" do
      get "/auth/password/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Forgot your password?")
    end

    it "sends reset instructions" do
      user # create user

      post "/auth/password", params: {
        user: { email: "test@example.com" }
      }

      expect(response).to have_http_status(:redirect)
    end
  end
end
