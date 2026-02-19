require "spec_helper"

RSpec.describe LcpRuby::Types::TypeDefinition do
  describe ".from_hash" do
    it "parses a type definition from a hash" do
      type_def = described_class.from_hash(
        "name" => "email",
        "base_type" => "string",
        "transforms" => %w[strip downcase],
        "validations" => [
          { "type" => "format", "options" => { "with" => '\A.+@.+\z' } }
        ],
        "input_type" => "email",
        "renderer" => "email_link",
        "column_options" => { "limit" => 255 },
        "html_input_attrs" => { "autocomplete" => "email" }
      )

      expect(type_def.name).to eq("email")
      expect(type_def.base_type).to eq("string")
      expect(type_def.transforms).to eq(%w[strip downcase])
      expect(type_def.validations).to eq([ { "type" => "format", "options" => { "with" => '\A.+@.+\z' } } ])
      expect(type_def.input_type).to eq("email")
      expect(type_def.renderer).to eq("email_link")
      expect(type_def.column_options).to eq(limit: 255)
      expect(type_def.html_input_attrs).to eq(autocomplete: "email")
    end

    it "handles minimal definition" do
      type_def = described_class.from_hash(
        "name" => "simple",
        "base_type" => "string"
      )

      expect(type_def.name).to eq("simple")
      expect(type_def.transforms).to eq([])
      expect(type_def.validations).to eq([])
      expect(type_def.input_type).to be_nil
      expect(type_def.renderer).to be_nil
      expect(type_def.column_options).to eq({})
      expect(type_def.html_input_attrs).to eq({})
    end
  end

  describe "#column_type" do
    it "delegates to base_type for standard types" do
      type_def = described_class.from_hash("name" => "email", "base_type" => "string")
      expect(type_def.column_type).to eq(:string)
    end

    it "maps enum to string" do
      type_def = described_class.from_hash("name" => "custom_enum", "base_type" => "enum")
      expect(type_def.column_type).to eq(:string)
    end

    it "maps json to adapter-appropriate column type" do
      type_def = described_class.from_hash("name" => "custom_json", "base_type" => "json")
      expect(type_def.column_type).to eq(LcpRuby.json_column_type)
    end

    it "maps rich_text to text" do
      type_def = described_class.from_hash("name" => "custom_rt", "base_type" => "rich_text")
      expect(type_def.column_type).to eq(:text)
    end

    it "maps decimal to decimal" do
      type_def = described_class.from_hash("name" => "money", "base_type" => "decimal")
      expect(type_def.column_type).to eq(:decimal)
    end
  end

  describe "validation" do
    it "raises when name is blank" do
      expect {
        described_class.from_hash("name" => "", "base_type" => "string")
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises when base_type is blank" do
      expect {
        described_class.from_hash("name" => "test", "base_type" => "")
      }.to raise_error(LcpRuby::MetadataError, /Base type is required/)
    end

    it "raises for invalid base_type" do
      expect {
        described_class.from_hash("name" => "test", "base_type" => "invalid")
      }.to raise_error(LcpRuby::MetadataError, /Invalid base_type 'invalid'/)
    end

    LcpRuby::Metadata::FieldDefinition::BASE_TYPES.each do |base|
      it "accepts base_type '#{base}'" do
        expect {
          described_class.from_hash("name" => "test_#{base}", "base_type" => base)
        }.not_to raise_error
      end
    end
  end
end
