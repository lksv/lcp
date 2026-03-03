require "spec_helper"

RSpec.describe LcpRuby::SavedFilters::Setup do
  before do
    LcpRuby.reset!
  end

  describe ".apply!" do
    context "when saved_filter model is not defined" do
      it "silently skips without errors" do
        loader = instance_double(LcpRuby::Metadata::Loader, model_definitions: {})
        expect { described_class.apply!(loader) }.not_to raise_error
        expect(LcpRuby::SavedFilters::Registry.available?).to be false
      end
    end

    context "when saved_filter model is defined but fails contract" do
      it "raises MetadataError" do
        fields = [ { "name" => "name", "type" => "string" } ]
        model_data = { "name" => "saved_filter", "fields" => fields }
        model_def = LcpRuby::Metadata::ModelDefinition.from_hash(model_data)
        loader = instance_double(
          LcpRuby::Metadata::Loader,
          model_definitions: { "saved_filter" => model_def }
        )

        expect { described_class.apply!(loader) }.to raise_error(LcpRuby::MetadataError, /does not satisfy/)
      end
    end
  end
end
