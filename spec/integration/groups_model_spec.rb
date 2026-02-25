require "spec_helper"
require "support/integration_helper"

RSpec.describe "Groups model source integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("groups_model_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("groups_model_test")
  end

  before(:each) do
    load_integration_metadata!("groups_model_test")
    LcpRuby.configuration.group_source = :model
    LcpRuby.configuration.group_role_mapping_model = "group_role_mapping"
    LcpRuby::Groups::Setup.apply!(LcpRuby.loader)
  end

  let(:group_model) { LcpRuby.registry.model_for("group") }
  let(:membership_model) { LcpRuby.registry.model_for("group_membership") }
  let(:mapping_model) { LcpRuby.registry.model_for("group_role_mapping") }

  describe "DB-backed group role resolution" do
    it "resolves roles through group membership and role mapping" do
      # Set up: group "editors" -> role "editor"
      group = group_model.create!(name: "editors", label: "Editors")
      mapping_model.create!(group_id: group.id, role_name: "editor")
      membership_model.create!(group_id: group.id, user_id: 42)

      # User with no direct roles, only group membership
      user = stub_current_user(role: [], id: 42)

      LcpRuby.configuration.role_resolution_strategy = :merged

      perm_def = LcpRuby.loader.permission_definition("project")
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to include("editor")
      expect(evaluator.can?(:create)).to be true
      expect(evaluator.can?(:destroy)).to be false
    end

    it "merges direct and group roles" do
      group = group_model.create!(name: "editors", label: "Editors")
      mapping_model.create!(group_id: group.id, role_name: "editor")
      membership_model.create!(group_id: group.id, user_id: 43)

      # User has direct viewer role + editor from group
      user = stub_current_user(role: ["viewer"], id: 43)

      LcpRuby.configuration.role_resolution_strategy = :merged

      perm_def = LcpRuby.loader.permission_definition("project")
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to match_array(%w[viewer editor])
    end

    it "excludes roles from inactive groups" do
      group = group_model.create!(name: "disabled", label: "Disabled", active: false)
      mapping_model.create!(group_id: group.id, role_name: "admin")
      membership_model.create!(group_id: group.id, user_id: 44)

      user = stub_current_user(role: [], id: 44)

      perm_def = LcpRuby.loader.permission_definition("project")
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      # Falls back to default because inactive group provides no roles
      expect(evaluator.roles).to eq(%w[viewer])
    end
  end

  describe "cache invalidation" do
    it "updates role resolution when groups change" do
      user = stub_current_user(role: [], id: 45)
      LcpRuby.configuration.role_resolution_strategy = :merged

      # Initially no groups -> default role
      perm_def = LcpRuby.loader.permission_definition("project")
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")
      expect(evaluator.can?(:create)).to be false

      # Add group with editor role
      group = group_model.create!(name: "new_editors", label: "New Editors")
      mapping_model.create!(group_id: group.id, role_name: "editor")
      membership_model.create!(group_id: group.id, user_id: 45)

      # Re-evaluate — should now have editor permissions
      evaluator2 = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")
      expect(evaluator2.can?(:create)).to be true
    end
  end
end
