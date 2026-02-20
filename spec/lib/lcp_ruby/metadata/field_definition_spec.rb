require "spec_helper"

RSpec.describe LcpRuby::Metadata::FieldDefinition do
  describe ".from_hash" do
    it "parses a simple string field" do
      field = described_class.from_hash(
        "name" => "title",
        "type" => "string",
        "label" => "Title"
      )

      expect(field.name).to eq("title")
      expect(field.type).to eq("string")
      expect(field.label).to eq("Title")
      expect(field.column_type).to eq(:string)
    end

    it "parses a decimal field with column options" do
      field = described_class.from_hash(
        "name" => "budget",
        "type" => "decimal",
        "column_options" => { "precision" => 12, "scale" => 2 }
      )

      expect(field.column_type).to eq(:decimal)
      expect(field.column_options[:precision]).to eq(12)
      expect(field.column_options[:scale]).to eq(2)
    end

    it "parses an enum field" do
      field = described_class.from_hash(
        "name" => "status",
        "type" => "enum",
        "enum_values" => [
          { "value" => "draft", "label" => "Draft" },
          { "value" => "active", "label" => "Active" }
        ],
        "default" => "draft"
      )

      expect(field.enum?).to be true
      expect(field.enum_value_names).to eq(%w[draft active])
      expect(field.column_type).to eq(:string)
      expect(field.default).to eq("draft")
    end

    it "maps rich_text to text column type" do
      field = described_class.from_hash("name" => "content", "type" => "rich_text")
      expect(field.column_type).to eq(:text)
    end

    it "maps json to adapter-appropriate column type" do
      field = described_class.from_hash("name" => "meta", "type" => "json")
      expect(field.column_type).to eq(LcpRuby.json_column_type)
    end

    it "defaults label to humanized name" do
      field = described_class.from_hash("name" => "first_name", "type" => "string")
      expect(field.label).to eq("First name")
    end
  end

  describe "virtual fields (source)" do
    it "parses source: external" do
      field = described_class.from_hash(
        "name" => "stock", "type" => "integer", "source" => "external"
      )
      expect(field.virtual?).to be true
      expect(field.external?).to be true
      expect(field.service_accessor?).to be false
      expect(field.column_type).to be_nil
    end

    it "parses source with service accessor" do
      field = described_class.from_hash(
        "name" => "color",
        "type" => "string",
        "source" => { "service" => "json_field", "options" => { "column" => "metadata", "key" => "color" } }
      )
      expect(field.virtual?).to be true
      expect(field.external?).to be false
      expect(field.service_accessor?).to be true
      expect(field.column_type).to be_nil
    end

    it "non-virtual fields are not virtual" do
      field = described_class.from_hash("name" => "title", "type" => "string")
      expect(field.virtual?).to be false
      expect(field.external?).to be false
      expect(field.service_accessor?).to be false
    end

    it "raises when both source and computed are set" do
      expect {
        described_class.from_hash(
          "name" => "x", "type" => "string",
          "source" => "external", "computed" => "{y}"
        )
      }.to raise_error(LcpRuby::MetadataError, /cannot have both 'source' and 'computed'/)
    end
  end

  describe "validation" do
    it "raises on missing name" do
      expect {
        described_class.from_hash("type" => "string")
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises on invalid type" do
      expect {
        described_class.from_hash("name" => "foo", "type" => "invalid")
      }.to raise_error(LcpRuby::MetadataError, /type 'invalid' is invalid/)
    end

    LcpRuby::Metadata::FieldDefinition::VALID_TYPES.each do |type|
      it "accepts type '#{type}'" do
        expect {
          described_class.from_hash("name" => "test_field", "type" => type)
        }.not_to raise_error
      end
    end
  end
end
