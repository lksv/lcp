require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Roles::ChangeHandler do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("role_source_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("role_source_test")
  end

  before(:each) do
    Object.new.extend(IntegrationHelper).load_integration_metadata!("role_source_test")
    # Configure role_source and install handler after metadata load
    LcpRuby.configuration.role_source = :model
    LcpRuby::Roles::Registry.mark_available!
    described_class.install!(role_model)
  end

  let(:role_model) { LcpRuby.registry.model_for("role") }

  describe ".install!" do
    it "triggers Registry.reload! on create" do
      expect(LcpRuby::Roles::Registry).to receive(:reload!)
      role_model.create!(name: "test_role", label: "Test")
    end

    it "triggers Registry.reload! on update" do
      role = role_model.create!(name: "update_test", label: "Update Test")
      LcpRuby::Roles::Registry.reload!

      expect(LcpRuby::Roles::Registry).to receive(:reload!)
      role.update!(label: "Updated")
    end

    it "triggers Registry.reload! on destroy" do
      role = role_model.create!(name: "destroy_test", label: "Destroy Test")
      LcpRuby::Roles::Registry.reload!

      expect(LcpRuby::Roles::Registry).to receive(:reload!)
      role.destroy!
    end
  end
end
