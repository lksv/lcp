require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Groups::ChangeHandler do
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
    LcpRuby::Groups::Registry.mark_available!
  end

  let(:group_model) { LcpRuby.registry.model_for("group") }
  let(:membership_model) { LcpRuby.registry.model_for("group_membership") }
  let(:mapping_model) { LcpRuby.registry.model_for("group_role_mapping") }

  describe ".install!" do
    it "installs after_commit on group model" do
      described_class.install!(group_model, membership_model, mapping_model)

      expect(LcpRuby::Groups::Registry).to receive(:reload!)
      expect(LcpRuby::Authorization::PolicyFactory).to receive(:clear!)

      group_model.create!(name: "test_group", label: "Test")
    end

    it "installs after_commit on membership model" do
      described_class.install!(group_model, membership_model, mapping_model)
      group = group_model.create!(name: "test_group", label: "Test")

      expect(LcpRuby::Groups::Registry).to receive(:reload!)
      expect(LcpRuby::Authorization::PolicyFactory).to receive(:clear!)

      membership_model.create!(group_id: group.id, user_id: 1)
    end

    it "installs after_commit on mapping model" do
      described_class.install!(group_model, membership_model, mapping_model)
      group = group_model.create!(name: "test_group", label: "Test")

      expect(LcpRuby::Groups::Registry).to receive(:reload!)
      expect(LcpRuby::Authorization::PolicyFactory).to receive(:clear!)

      mapping_model.create!(group_id: group.id, role_name: "editor")
    end

    it "handles nil mapping_class gracefully" do
      expect {
        described_class.install!(group_model, membership_model, nil)
      }.not_to raise_error
    end
  end

  describe "cache invalidation verification" do
    it "actually clears registry cache when group is created" do
      # Set up a real model loader with the registry
      model_loader = LcpRuby::Groups::ModelLoader.new
      LcpRuby::Groups::Registry.set_loader(model_loader)
      LcpRuby::Groups::Registry.mark_available!
      described_class.install!(group_model, membership_model, mapping_model)

      # Cache the initial state
      initial_names = LcpRuby::Groups::Registry.all_group_names
      expect(initial_names).to eq([])

      # Create a group — after_commit should clear the cache
      group_model.create!(name: "new_group", label: "New")

      # Cache should be cleared, returning fresh data
      expect(LcpRuby::Groups::Registry.all_group_names).to include("new_group")
    end

    it "clears registry cache when membership is created" do
      model_loader = LcpRuby::Groups::ModelLoader.new
      LcpRuby::Groups::Registry.set_loader(model_loader)
      LcpRuby::Groups::Registry.mark_available!
      described_class.install!(group_model, membership_model, mapping_model)

      # Create group first, cache the names
      group = group_model.create!(name: "test_cache", label: "Test")
      LcpRuby::Groups::Registry.all_group_names

      # Creating a membership also triggers cache invalidation
      expect(LcpRuby::Groups::Registry).to receive(:reload!).and_call_original
      membership_model.create!(group_id: group.id, user_id: 99)
    end
  end
end
