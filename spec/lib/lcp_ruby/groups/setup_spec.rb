require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Groups::Setup do
  describe ".apply!" do
    context "when group_source is :none" do
      it "does nothing" do
        LcpRuby.reset!
        LcpRuby.configuration.group_source = :none

        loader = instance_double(LcpRuby::Metadata::Loader)
        described_class.apply!(loader)

        expect(LcpRuby::Groups::Registry.available?).to be false
      end
    end

    context "when group_source is :yaml" do
      before(:all) do
        helper = Object.new.extend(IntegrationHelper)
        helper.load_integration_metadata!("groups_yaml_test")
      end

      after(:all) do
        helper = Object.new.extend(IntegrationHelper)
        helper.teardown_integration_tables!("groups_yaml_test")
      end

      it "loads groups from YAML and marks registry as available" do
        Object.new.extend(IntegrationHelper).load_integration_metadata!("groups_yaml_test")
        LcpRuby.configuration.group_source = :yaml

        loader = LcpRuby.loader
        described_class.apply!(loader)

        expect(LcpRuby::Groups::Registry.available?).to be true
        expect(LcpRuby::Groups::Registry.all_group_names).to include("editors_group", "admins_group")
      end
    end

    context "when group_source is :model" do
      before(:all) do
        helper = Object.new.extend(IntegrationHelper)
        helper.load_integration_metadata!("groups_model_test")
      end

      after(:all) do
        helper = Object.new.extend(IntegrationHelper)
        helper.teardown_integration_tables!("groups_model_test")
      end

      it "raises MetadataError when group model is not defined" do
        LcpRuby.reset!
        LcpRuby.configuration.group_source = :model
        LcpRuby.configuration.group_model = "nonexistent"

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: {})

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /not defined/)
      end

      it "marks registry as available on success" do
        Object.new.extend(IntegrationHelper).load_integration_metadata!("groups_model_test")
        LcpRuby.configuration.group_source = :model
        LcpRuby.configuration.group_role_mapping_model = "group_role_mapping"

        loader = LcpRuby.loader
        described_class.apply!(loader)

        expect(LcpRuby::Groups::Registry.available?).to be true
      end
    end

    context "when group_source is :host" do
      it "raises MetadataError when no adapter is configured" do
        LcpRuby.reset!
        LcpRuby.configuration.group_source = :host
        LcpRuby.configuration.group_adapter = nil

        loader = instance_double(LcpRuby::Metadata::Loader)

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /no group_adapter/)
      end

      it "raises MetadataError when adapter is missing required methods" do
        LcpRuby.reset!
        LcpRuby.configuration.group_source = :host
        LcpRuby.configuration.group_adapter = Object.new

        loader = instance_double(LcpRuby::Metadata::Loader)

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /must respond to/)
      end

      it "marks registry as available with valid adapter" do
        LcpRuby.reset!
        LcpRuby.configuration.group_source = :host

        adapter = double("Adapter")
        allow(adapter).to receive(:all_group_names).and_return(%w[team_a])
        allow(adapter).to receive(:groups_for_user).and_return(%w[team_a])
        allow(adapter).to receive(:roles_for_group).and_return(%w[admin])

        LcpRuby.configuration.group_adapter = adapter

        loader = instance_double(LcpRuby::Metadata::Loader)
        described_class.apply!(loader)

        expect(LcpRuby::Groups::Registry.available?).to be true
      end
    end
  end
end
