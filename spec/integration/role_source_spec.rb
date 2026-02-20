require "spec_helper"
require "support/integration_helper"

RSpec.describe "Role Source Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("role_source_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("role_source_test")
  end

  before(:each) do
    load_integration_metadata!("role_source_test")
    # Configure role_source after metadata load (reset! clears config)
    LcpRuby.configuration.role_source = :model
    LcpRuby::Roles::Registry.mark_available!
    LcpRuby::Roles::ChangeHandler.install!(role_model)
  end

  let(:role_model) { LcpRuby.registry.model_for("role") }
  let(:project_model) { LcpRuby.registry.model_for("project") }

  describe "Registry after boot" do
    it "marks the registry as available" do
      expect(LcpRuby::Roles::Registry.available?).to be true
    end

    it "returns role names from DB" do
      role_model.create!(name: "admin", label: "Administrator")
      role_model.create!(name: "viewer", label: "Viewer")
      LcpRuby::Roles::Registry.reload!

      expect(LcpRuby::Roles::Registry.all_role_names).to eq(%w[admin viewer])
    end

    it "filters out inactive roles" do
      role_model.create!(name: "admin", label: "Admin", active: true)
      role_model.create!(name: "old_role", label: "Old", active: false)
      LcpRuby::Roles::Registry.reload!

      names = LcpRuby::Roles::Registry.all_role_names
      expect(names).to include("admin")
      expect(names).not_to include("old_role")
    end
  end

  describe "Cache invalidation" do
    it "updates cache when a role is created" do
      expect(LcpRuby::Roles::Registry.all_role_names).to eq([])

      role_model.create!(name: "dynamic_admin", label: "Dynamic Admin")

      expect(LcpRuby::Roles::Registry.all_role_names).to include("dynamic_admin")
    end

    it "updates cache when a role is updated" do
      role = role_model.create!(name: "old_name", label: "Old")
      LcpRuby::Roles::Registry.reload!
      expect(LcpRuby::Roles::Registry.all_role_names).to include("old_name")

      role.update!(name: "new_name")
      # after_commit triggers reload
      expect(LcpRuby::Roles::Registry.all_role_names).to include("new_name")
      expect(LcpRuby::Roles::Registry.all_role_names).not_to include("old_name")
    end

    it "updates cache when a role is destroyed" do
      role = role_model.create!(name: "to_delete", label: "To Delete")
      LcpRuby::Roles::Registry.reload!
      expect(LcpRuby::Roles::Registry.all_role_names).to include("to_delete")

      role.destroy!
      # after_commit triggers reload
      expect(LcpRuby::Roles::Registry.all_role_names).not_to include("to_delete")
    end
  end

  describe "PermissionEvaluator with role_source :model" do
    let(:perm_def) do
      LcpRuby.loader.permission_definitions["project"]
    end

    it "filters out roles not in the registry" do
      role_model.create!(name: "admin", label: "Admin")
      LcpRuby::Roles::Registry.reload!

      # User claims admin and nonexistent_role; only admin should be used
      user = double("User", id: 1, lcp_role: %w[admin nonexistent_role])
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to eq([ "admin" ])
    end

    it "falls back to default_role when all user roles are invalid" do
      LcpRuby::Roles::Registry.reload!

      user = double("User", id: 1, lcp_role: %w[nonexistent])
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to eq([ "viewer" ])
    end

    it "keeps valid roles when registry is available" do
      role_model.create!(name: "admin", label: "Admin")
      role_model.create!(name: "viewer", label: "Viewer")
      LcpRuby::Roles::Registry.reload!

      user = double("User", id: 1, lcp_role: %w[admin viewer])
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to match_array(%w[admin viewer])
    end
  end

  describe "Implicit mode (unchanged behavior)" do
    before(:each) do
      LcpRuby.configuration.role_source = :implicit
      LcpRuby::Roles::Registry.clear!
    end

    let(:perm_def) do
      LcpRuby.loader.permission_definitions["project"]
    end

    it "does not filter roles through the registry" do
      user = double("User", id: 1, lcp_role: %w[admin])
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      # In implicit mode, roles are only filtered against permission definition keys
      expect(evaluator.roles).to eq([ "admin" ])
    end

    it "falls back to default_role for unknown roles (via permission definition)" do
      user = double("User", id: 1, lcp_role: %w[nonexistent])
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to eq([ "viewer" ])
    end
  end

  describe "CRUD operations on roles" do
    before do
      stub_current_user(role: "admin")
    end

    it "lists roles" do
      role_model.create!(name: "admin", label: "Admin")
      get "/roles"
      expect(response).to have_http_status(:success)
    end

    it "creates a role via HTTP" do
      post "/roles", params: { record: { name: "new_role", label: "New Role", active: "1", position: "0" } }
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response).to have_http_status(:success)
    end

    it "shows a role" do
      role = role_model.create!(name: "admin", label: "Admin")
      get "/roles/#{role.id}"
      expect(response).to have_http_status(:success)
    end
  end
end
