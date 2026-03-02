require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Auditing::Setup do
  describe ".apply!" do
    context "when no model has auditing enabled" do
      it "does nothing" do
        LcpRuby.reset!

        model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "plain_item",
          "fields" => [{ "name" => "name", "type" => "string" }],
          "options" => { "timestamps" => true }
        })

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: { "plain_item" => model_def })

        described_class.apply!(loader)
        expect(LcpRuby::Auditing::Registry.available?).to be false
      end
    end

    context "when a model has auditing enabled" do
      it "raises MetadataError when audit model is not defined" do
        LcpRuby.reset!

        model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "audited_thing",
          "fields" => [{ "name" => "name", "type" => "string" }],
          "options" => { "timestamps" => true, "auditing" => true }
        })

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: { "audited_thing" => model_def })

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /audit model.*not defined/)
      end

      it "warns and returns in generator context when audit model is missing" do
        LcpRuby.reset!

        model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "audited_thing",
          "fields" => [{ "name" => "name", "type" => "string" }],
          "options" => { "timestamps" => true, "auditing" => true }
        })

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: { "audited_thing" => model_def })

        allow(LcpRuby).to receive(:generator_context?).and_return(true)
        allow(Rails.logger).to receive(:warn)

        expect { described_class.apply!(loader) }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with(/not defined/)
        expect(LcpRuby::Auditing::Registry.available?).to be false
      end

      it "raises MetadataError when contract validation fails" do
        LcpRuby.reset!

        audited_def = LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "audited_thing",
          "fields" => [{ "name" => "name", "type" => "string" }],
          "options" => { "timestamps" => true, "auditing" => true }
        })

        bad_audit_def = LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "audit_log",
          "fields" => [{ "name" => "action", "type" => "string" }],
          "options" => { "timestamps" => false }
        })

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: {
            "audited_thing" => audited_def,
            "audit_log" => bad_audit_def
          })

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /does not satisfy the contract/)
      end

      it "marks registry as available on success" do
        helper = Object.new.extend(IntegrationHelper)
        helper.load_integration_metadata!("auditing")

        expect(LcpRuby::Auditing::Registry.available?).to be true
      end
    end
  end
end
