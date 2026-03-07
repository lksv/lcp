require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::ApiBuilder do
  let(:model_def) do
    LcpRuby::Metadata::ModelDefinition.new(
      name: "api_test_model",
      fields: [
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "name", "type" => "string"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "count", "type" => "integer"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "price", "type" => "decimal"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "active", "type" => "boolean"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "created_on", "type" => "date"),
        LcpRuby::Metadata::FieldDefinition.from_hash(
          "name" => "status", "type" => "enum",
          "enum_values" => [ { "value" => "open", "label" => "Open" }, { "value" => "closed", "label" => "Closed" } ]
        )
      ],
      options: { "label_method" => "name" },
      data_source_config: { "type" => "host", "provider" => "TestHostProvider" }
    )
  end

  subject { described_class.new(model_def) }

  describe "#build" do
    let(:model_class) { subject.build }

    it "creates a class in LcpRuby::Dynamic namespace" do
      expect(model_class.name).to eq("LcpRuby::Dynamic::ApiTestModel")
    end

    it "includes ApiModelConcern" do
      expect(model_class.ancestors).to include(LcpRuby::DataSource::ApiModelConcern)
    end

    it "does NOT inherit from ActiveRecord::Base" do
      expect(model_class.ancestors).not_to include(ActiveRecord::Base)
    end

    it "defines attributes for all fields" do
      record = model_class.new
      expect(record).to respond_to(:name)
      expect(record).to respond_to(:name=)
      expect(record).to respond_to(:count)
      expect(record).to respond_to(:price)
      expect(record).to respond_to(:active)
      expect(record).to respond_to(:created_on)
      expect(record).to respond_to(:status)
    end

    it "defines :id attribute" do
      record = model_class.new
      expect(record).to respond_to(:id)
      expect(record).to respond_to(:id=)
    end

    it "casts attribute types correctly" do
      record = model_class.new(count: "5", active: "true", price: "19.99")
      expect(record.count).to eq(5)
      expect(record.active).to be true
      expect(record.price).to eq(BigDecimal("19.99"))
    end

    it "applies enum validations" do
      record = model_class.new(status: "invalid")
      expect(record.valid?).to be false
      expect(record.errors[:status]).to be_present
    end

    it "defines to_label from label_method" do
      record = model_class.new(name: "Test Building")
      expect(record.to_label).to eq("Test Building")
    end

    it "sets lcp_model_definition" do
      expect(model_class.lcp_model_definition).to eq(model_def)
    end

    it "reports as API model" do
      expect(model_class.lcp_api_model?).to be true
    end
  end

  describe "rebuilding" do
    it "removes previous constant" do
      subject.build
      # Build again should not raise "already initialized"
      expect { subject.build }.not_to raise_error
    end
  end
end
