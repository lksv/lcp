require "spec_helper"

RSpec.describe LcpRuby::CustomFields::BuiltInModel do
  describe ".model_hash" do
    subject(:hash) { described_class.model_hash }

    it "returns a hash with model name" do
      expect(hash["name"]).to eq("custom_field_definition")
    end

    it "has timestamps enabled" do
      expect(hash.dig("options", "timestamps")).to be true
    end

    it "has label_method set to label" do
      expect(hash.dig("options", "label_method")).to eq("label")
    end

    it "includes required fields" do
      field_names = hash["fields"].map { |f| f["name"] }
      expect(field_names).to include("target_model", "field_name", "custom_type", "label")
    end

    it "includes all expected fields" do
      field_names = hash["fields"].map { |f| f["name"] }
      expected = %w[
        target_model field_name custom_type label description section position
        active required default_value placeholder min_length max_length
        min_value max_value precision enum_values show_in_table show_in_form
        show_in_show sortable searchable input_type renderer renderer_options
        column_width extra_validations readable_by_roles writable_by_roles
      ]
      expected.each do |name|
        expect(field_names).to include(name), "Missing field: #{name}"
      end
    end

    it "has uniqueness validation on field_name scoped to target_model" do
      validation = hash["validations"].find { |v| v["type"] == "uniqueness" }
      expect(validation).to be_present
      expect(validation["field"]).to eq("field_name")
      expect(validation.dig("options", "scope")).to eq("target_model")
    end
  end

  describe ".model_definition" do
    it "returns a ModelDefinition instance" do
      result = described_class.model_definition
      expect(result).to be_a(LcpRuby::Metadata::ModelDefinition)
      expect(result.name).to eq("custom_field_definition")
    end
  end

  describe ".reserved_name?" do
    it "returns true for reserved names" do
      %w[id type created_at updated_at custom_data].each do |name|
        expect(described_class.reserved_name?(name)).to be true
      end
    end

    it "returns false for non-reserved names" do
      expect(described_class.reserved_name?("website")).to be false
      expect(described_class.reserved_name?("custom_field")).to be false
    end
  end

  describe "FIELD_TYPE_VALUES" do
    it "includes expected types" do
      expected = %w[string text integer float decimal boolean date datetime enum]
      expect(described_class::FIELD_TYPE_VALUES).to match_array(expected)
    end
  end
end
