require "spec_helper"

RSpec.describe LcpRuby::DataSource::ApiModelConcern do
  let(:model_def) do
    LcpRuby::Metadata::ModelDefinition.new(
      name: "concern_test",
      fields: [
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "name", "type" => "string"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "count", "type" => "integer")
      ],
      data_source_config: { "type" => "host", "provider" => "TestHostProvider" }
    )
  end

  let(:model_class) do
    builder = LcpRuby::ModelFactory::ApiBuilder.new(model_def)
    klass = builder.build
    LcpRuby.registry.register("concern_test", klass)
    klass
  end

  describe "class methods" do
    it "reports as API model" do
      expect(model_class.lcp_api_model?).to be true
    end

    it "has model_name" do
      expect(model_class.model_name.to_s).to include("ConcernTest")
    end

    it "returns column_names from definition" do
      expect(model_class.column_names).to include("name", "count")
    end

    it "returns ransackable stubs" do
      expect(model_class.ransackable_attributes).to eq([])
      expect(model_class.ransackable_associations).to eq([])
      expect(model_class.ransack).to be_nil
    end
  end

  describe "instance methods" do
    let(:record) { model_class.new }

    it "is not persisted by default" do
      expect(record.persisted?).to be false
      expect(record.new_record?).to be true
    end

    it "is persisted when id is set" do
      record.id = "123"
      expect(record.persisted?).to be true
      expect(record.new_record?).to be false
    end

    it "supports to_param" do
      record.id = "42"
      expect(record.to_param).to eq("42")
    end

    it "supports attribute access" do
      record.name = "Test"
      record.count = 5

      expect(record.name).to eq("Test")
      expect(record.count).to eq(5)
      expect(record.read_attribute(:name)).to eq("Test")
      expect(record[:count]).to eq(5)
    end

    it "is not in error state" do
      expect(record.error?).to be false
    end

    it "is not destroyed" do
      expect(record.destroyed?).to be false
    end
  end
end
