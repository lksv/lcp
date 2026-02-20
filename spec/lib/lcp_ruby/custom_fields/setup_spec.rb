require "spec_helper"

RSpec.describe LcpRuby::CustomFields::Setup do
  describe ".apply!" do
    context "when no models have custom_fields enabled" do
      it "does nothing" do
        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: { "plain" => model_def_without_custom_fields })

        described_class.apply!(loader)
        expect(LcpRuby::CustomFields::Registry.available?).to be false
      end
    end

    context "when custom_field_definition model is missing" do
      it "raises MetadataError" do
        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: { "project" => model_def_with_custom_fields })

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /not defined/)
      end

      it "warns and returns in generator context" do
        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: { "project" => model_def_with_custom_fields })

        allow(LcpRuby).to receive(:generator_context?).and_return(true)
        allow(Rails.logger).to receive(:warn)

        expect { described_class.apply!(loader) }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with(/not defined/)
        expect(LcpRuby::CustomFields::Registry.available?).to be false
      end
    end
  end

  private

  def model_def_without_custom_fields
    LcpRuby::Metadata::ModelDefinition.from_hash({
      "name" => "plain",
      "fields" => [ { "name" => "title", "type" => "string" } ]
    })
  end

  def model_def_with_custom_fields
    LcpRuby::Metadata::ModelDefinition.from_hash({
      "name" => "project",
      "fields" => [ { "name" => "title", "type" => "string" } ],
      "options" => { "custom_fields" => true }
    })
  end
end
