require "spec_helper"

RSpec.describe LcpRuby::CustomFields::ContractValidator do
  def build_model_def(fields:, validations: [], name: "custom_field_definition")
    hash = {
      "name" => name,
      "fields" => fields,
      "validations" => validations,
      "options" => { "timestamps" => true }
    }
    LcpRuby::Metadata::ModelDefinition.from_hash(hash)
  end

  let(:valid_fields) do
    [
      { "name" => "field_name", "type" => "string" },
      { "name" => "custom_type", "type" => "string" },
      { "name" => "target_model", "type" => "string" },
      { "name" => "label", "type" => "string" },
      { "name" => "active", "type" => "boolean" }
    ]
  end

  let(:scoped_uniqueness_validation) do
    [
      {
        "type" => "uniqueness",
        "field" => "field_name",
        "options" => { "scope" => "target_model" }
      }
    ]
  end

  describe ".validate" do
    context "with valid model" do
      it "passes when all required fields are present with correct types and uniqueness" do
        model_def = build_model_def(fields: valid_fields, validations: scoped_uniqueness_validation)
        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.errors).to be_empty
        expect(result.warnings).to be_empty
      end
    end

    context "with missing required field" do
      it "returns an error for each missing field" do
        model_def = build_model_def(fields: [
          { "name" => "custom_type", "type" => "string" },
          { "name" => "target_model", "type" => "string" },
          { "name" => "label", "type" => "string" },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must have a 'field_name' field")
      end
    end

    context "with wrong field type" do
      it "returns an error when field_name is integer instead of string" do
        fields = valid_fields.map do |f|
          f["name"] == "field_name" ? f.merge("type" => "integer") : f
        end
        model_def = build_model_def(fields: fields)

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must be type 'string'")
      end

      it "returns an error when active is string instead of boolean" do
        fields = valid_fields.map do |f|
          f["name"] == "active" ? f.merge("type" => "string") : f
        end
        model_def = build_model_def(fields: fields)

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must be type 'boolean'")
      end
    end

    context "with field-level uniqueness validation (DSL format)" do
      it "passes when field_name has scoped uniqueness in its own validations" do
        fields = valid_fields.map do |f|
          if f["name"] == "field_name"
            f.merge("validations" => [
              { "type" => "uniqueness", "options" => { "scope" => "target_model" } }
            ])
          else
            f
          end
        end
        model_def = build_model_def(fields: fields)
        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.errors).to be_empty
        expect(result.warnings).to be_empty
      end
    end

    context "with missing uniqueness validation" do
      it "passes with a warning" do
        model_def = build_model_def(fields: valid_fields)

        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.warnings.first).to include("should have a uniqueness validation")
      end
    end
  end
end
