require "spec_helper"

RSpec.describe LcpRuby::Permissions::Setup do
  describe ".apply!" do
    context "when permission_source is not :model" do
      it "does nothing" do
        LcpRuby.configuration.permission_source = :yaml

        loader = instance_double(LcpRuby::Metadata::Loader)
        expect(loader).not_to receive(:model_definitions)

        described_class.apply!(loader)
        expect(LcpRuby::Permissions::Registry.available?).to be false
      end
    end

    context "when permission_source is :model" do
      before do
        LcpRuby.configuration.permission_source = :model
      end

      it "raises MetadataError when permission model is not defined" do
        LcpRuby.configuration.permission_model = "nonexistent"

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: {})

        expect {
          described_class.apply!(loader)
        }.to raise_error(LcpRuby::MetadataError, /not defined/)
      end

      it "warns and returns in generator context" do
        LcpRuby.configuration.permission_model = "nonexistent"

        loader = instance_double(LcpRuby::Metadata::Loader,
          model_definitions: {})

        allow(LcpRuby).to receive(:generator_context?).and_return(true)
        allow(Rails.logger).to receive(:warn)

        expect { described_class.apply!(loader) }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with(/not defined/)
        expect(LcpRuby::Permissions::Registry.available?).to be false
      end
    end
  end
end
