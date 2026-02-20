require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Roles::Setup do
  describe ".apply!" do
    context "when role_source is :implicit" do
      it "does nothing" do
        LcpRuby.reset!
        LcpRuby.configuration.role_source = :implicit

        loader = instance_double(LcpRuby::Metadata::Loader)
        expect(loader).not_to receive(:model_definitions)

        described_class.apply!(loader)
        expect(LcpRuby::Roles::Registry.available?).to be false
      end
    end

    context "when role_source is :model" do
      before(:all) do
        helper = Object.new.extend(IntegrationHelper)
        helper.load_integration_metadata!("role_source_test")
      end

      after(:all) do
        helper = Object.new.extend(IntegrationHelper)
        helper.teardown_integration_tables!("role_source_test")
      end

      it "raises MetadataError when role model is not defined" do
        LcpRuby.reset!
        LcpRuby.configuration.role_source = :model
        LcpRuby.configuration.role_model = "nonexistent"

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: {})

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /not defined/)
      end

      it "raises MetadataError when contract validation fails" do
        LcpRuby.reset!
        LcpRuby.configuration.role_source = :model
        LcpRuby.configuration.role_model = "bad_role"

        bad_model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "bad_role",
          "fields" => [ { "name" => "name", "type" => "integer" } ],
          "options" => { "timestamps" => true }
        })

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: { "bad_role" => bad_model_def })

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /does not satisfy the contract/)
      end

      it "marks registry as available on success" do
        # Load metadata first (builds models and tables)
        Object.new.extend(IntegrationHelper).load_integration_metadata!("role_source_test")

        # Configure role_source and run setup manually
        LcpRuby.configuration.role_source = :model
        loader = LcpRuby.loader
        described_class.apply!(loader)

        expect(LcpRuby::Roles::Registry.available?).to be true
      end
    end
  end
end
