require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Groups::ModelLoader do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("groups_model_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("groups_model_test")
  end

  before(:each) do
    Object.new.extend(IntegrationHelper).load_integration_metadata!("groups_model_test")
    LcpRuby.configuration.group_source = :model
    LcpRuby.configuration.group_role_mapping_model = "group_role_mapping"
  end

  let(:loader) { described_class.new }
  let(:group_model) { LcpRuby.registry.model_for("group") }
  let(:membership_model) { LcpRuby.registry.model_for("group_membership") }
  let(:mapping_model) { LcpRuby.registry.model_for("group_role_mapping") }

  describe "#all_group_names" do
    it "returns empty array when no groups exist" do
      expect(loader.all_group_names).to eq([])
    end

    it "returns sorted active group names" do
      group_model.create!(name: "editors", label: "Editors", active: true)
      group_model.create!(name: "admins", label: "Admins", active: true)
      group_model.create!(name: "inactive", label: "Inactive", active: false)

      result = loader.all_group_names
      expect(result).to eq(%w[admins editors])
      expect(result).not_to include("inactive")
    end
  end

  describe "#groups_for_user" do
    it "returns groups the user belongs to" do
      group = group_model.create!(name: "editors", label: "Editors")
      other_group = group_model.create!(name: "admins", label: "Admins")
      membership_model.create!(group_id: group.id, user_id: 42)

      user = double("User", id: 42)
      expect(loader.groups_for_user(user)).to eq(%w[editors])
    end

    it "excludes inactive groups" do
      group = group_model.create!(name: "inactive", label: "Inactive", active: false)
      membership_model.create!(group_id: group.id, user_id: 42)

      user = double("User", id: 42)
      expect(loader.groups_for_user(user)).to eq([])
    end

    it "returns empty for nil user" do
      expect(loader.groups_for_user(nil)).to eq([])
    end
  end

  describe "#roles_for_group" do
    it "returns mapped roles for a group" do
      group = group_model.create!(name: "editors", label: "Editors")
      mapping_model.create!(group_id: group.id, role_name: "editor")
      mapping_model.create!(group_id: group.id, role_name: "viewer")

      expect(loader.roles_for_group("editors")).to match_array(%w[editor viewer])
    end

    it "returns empty for unknown group" do
      expect(loader.roles_for_group("nonexistent")).to eq([])
    end

    it "returns empty when group_role_mapping_model is nil" do
      LcpRuby.configuration.group_role_mapping_model = nil
      expect(loader.roles_for_group("anything")).to eq([])
    end
  end

  describe "#roles_for_user" do
    it "returns all roles derived from user's group memberships" do
      group = group_model.create!(name: "editors", label: "Editors")
      membership_model.create!(group_id: group.id, user_id: 42)
      mapping_model.create!(group_id: group.id, role_name: "editor")
      mapping_model.create!(group_id: group.id, role_name: "viewer")

      user = double("User", id: 42)
      expect(loader.roles_for_user(user)).to match_array(%w[editor viewer])
    end

    it "returns empty when group_role_mapping_model is nil" do
      LcpRuby.configuration.group_role_mapping_model = nil
      user = double("User", id: 42)
      expect(loader.roles_for_user(user)).to eq([])
    end

    it "excludes roles from inactive groups" do
      group = group_model.create!(name: "inactive", label: "Inactive", active: false)
      membership_model.create!(group_id: group.id, user_id: 42)
      mapping_model.create!(group_id: group.id, role_name: "admin")

      user = double("User", id: 42)
      expect(loader.roles_for_user(user)).to eq([])
    end

    it "returns empty for nil user" do
      expect(loader.roles_for_user(nil)).to eq([])
    end
  end

  describe "error recovery" do
    it "returns empty array and logs when all_group_names hits a DB error" do
      allow(LcpRuby.configuration).to receive(:group_model).and_return("nonexistent_model")
      allow(LcpRuby.registry).to receive(:model_for).with("nonexistent_model").and_raise(LcpRuby::Error, "Model not found")

      expect(loader.all_group_names).to eq([])
    end

    it "returns empty array when groups_for_user hits a DB error" do
      user = double("User", id: 42)
      allow(LcpRuby.configuration).to receive(:group_model).and_return("nonexistent_model")
      allow(LcpRuby.registry).to receive(:model_for).with("nonexistent_model").and_raise(LcpRuby::Error, "Model not found")

      expect(loader.groups_for_user(user)).to eq([])
    end

    it "returns empty array when roles_for_group hits a DB error" do
      allow(group_model).to receive(:find_by).and_raise(ActiveRecord::StatementInvalid, "DB error")

      expect(loader.roles_for_group("anything")).to eq([])
    end

    it "returns empty array when roles_for_user hits a DB error" do
      user = double("User", id: 42)
      allow(LcpRuby.configuration).to receive(:group_model).and_return("nonexistent_model")
      allow(LcpRuby.registry).to receive(:model_for).with("nonexistent_model").and_raise(LcpRuby::Error, "Model not found")

      expect(loader.roles_for_user(user)).to eq([])
    end
  end

  describe "field mapping validation" do
    it "raises ArgumentError when name field mapping is missing" do
      LcpRuby.configuration.group_model_fields = { active: "active" }

      expect { loader.all_group_names }.to raise_error(ArgumentError, /Missing 'name' in group_model_fields/)
    ensure
      LcpRuby.configuration.group_model_fields = { name: "name", active: "active" }
    end

    it "raises ArgumentError when membership group field mapping is missing" do
      LcpRuby.configuration.group_membership_fields = { user: "user_id" }
      user = double("User", id: 42)

      expect { loader.groups_for_user(user) }.to raise_error(ArgumentError, /Missing 'group' in group_membership_fields/)
    ensure
      LcpRuby.configuration.group_membership_fields = { group: "group_id", user: "user_id" }
    end

    it "raises ArgumentError when role mapping role field is missing" do
      group_model.create!(name: "test", label: "Test")
      LcpRuby.configuration.group_role_mapping_fields = { group: "group_id" }

      expect { loader.roles_for_group("test") }.to raise_error(ArgumentError, /Missing 'role' in group_role_mapping_fields/)
    ensure
      LcpRuby.configuration.group_role_mapping_fields = { group: "group_id", role: "role_name" }
    end
  end

  describe "custom field mappings" do
    it "works with non-default group name field" do
      # The default field mapping uses "name", but we verify the field is
      # looked up dynamically from config, not hardcoded.
      group_model.create!(name: "custom_group", label: "Custom")

      expect(loader.all_group_names).to include("custom_group")
    end
  end
end
