require "spec_helper"
require "support/integration_helper"

RSpec.describe "Groups YAML source integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("groups_yaml_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("groups_yaml_test")
  end

  before(:each) do
    load_integration_metadata!("groups_yaml_test")
    LcpRuby.configuration.group_source = :yaml
    LcpRuby::Groups::Setup.apply!(LcpRuby.loader)
  end

  describe "group-derived permissions with merged strategy" do
    it "grants editor permissions via group membership" do
      # User has no direct role but belongs to editors_group (which maps to editor role)
      user = stub_current_user(role: [], id: 1)
      allow(user).to receive(:lcp_groups).and_return(%w[editors_group])

      LcpRuby.configuration.role_resolution_strategy = :merged

      # Editor role can create
      project_model = LcpRuby.registry.model_for("project")
      project_model.create!(title: "Test Project", status: "active")

      get "/projects"
      expect(response).to have_http_status(:success)
    end

    it "grants admin permissions via admins_group" do
      user = stub_current_user(role: [], id: 2)
      allow(user).to receive(:lcp_groups).and_return(%w[admins_group])

      LcpRuby.configuration.role_resolution_strategy = :merged

      get "/projects"
      expect(response).to have_http_status(:success)
    end
  end

  describe "role_resolution_strategy :groups_only" do
    it "ignores direct roles and uses only group-derived roles" do
      # User has direct admin role but groups_only means we only use groups
      user = stub_current_user(role: ["admin"], id: 3)
      allow(user).to receive(:lcp_groups).and_return(%w[editors_group])

      LcpRuby.configuration.role_resolution_strategy = :groups_only

      # Should get editor permissions (from group), not admin (from direct)
      perm_def = LcpRuby.loader.permission_definition("project")
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to eq(%w[editor])
      expect(evaluator.can?(:create)).to be true
      expect(evaluator.can?(:destroy)).to be false
    end
  end

  describe "role_resolution_strategy :direct_only" do
    it "ignores group-derived roles and uses only direct roles" do
      user = stub_current_user(role: ["viewer"], id: 4)
      allow(user).to receive(:lcp_groups).and_return(%w[admins_group])

      LcpRuby.configuration.role_resolution_strategy = :direct_only

      # Should get viewer permissions (from direct), not admin (from group)
      perm_def = LcpRuby.loader.permission_definition("project")
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "project")

      expect(evaluator.roles).to eq(%w[viewer])
      expect(evaluator.can?(:create)).to be false
    end
  end
end
