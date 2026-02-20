require "spec_helper"

RSpec.describe LcpRuby::Roles::ContractValidator do
  let(:fixtures_path) { File.expand_path("../../../../fixtures/metadata", __dir__) }

  def build_model_def(fields:, name: "role")
    hash = {
      "name" => name,
      "fields" => fields,
      "options" => { "timestamps" => true }
    }
    LcpRuby::Metadata::ModelDefinition.from_hash(hash)
  end

  describe ".validate" do
    context "with valid role model" do
      it "passes when name field is string with uniqueness" do
        model_def = build_model_def(fields: [
          { "name" => "name", "type" => "string", "validations" => [ { "type" => "uniqueness" } ] },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.errors).to be_empty
      end

      it "passes with custom field mapping" do
        model_def = build_model_def(fields: [
          { "name" => "role_key", "type" => "string", "validations" => [ { "type" => "uniqueness" } ] },
          { "name" => "enabled", "type" => "boolean" }
        ])

        result = described_class.validate(model_def, { name: "role_key", active: "enabled" })
        expect(result).to be_valid
      end
    end

    context "with missing name field" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "title", "type" => "string" },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must have a 'name' field")
      end
    end

    context "with wrong name field type" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "name", "type" => "integer" },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must be type 'string'")
      end
    end

    context "with wrong active field type" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "name", "type" => "string", "validations" => [ { "type" => "uniqueness" } ] },
          { "name" => "active", "type" => "string" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("'active' field must be type 'boolean'")
      end
    end

    context "with missing active field" do
      it "passes (active field is optional)" do
        model_def = build_model_def(fields: [
          { "name" => "name", "type" => "string", "validations" => [ { "type" => "uniqueness" } ] }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
      end
    end

    context "with missing uniqueness validation on name" do
      it "passes with a warning" do
        model_def = build_model_def(fields: [
          { "name" => "name", "type" => "string" },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.warnings.first).to include("should have a uniqueness validation")
      end
    end
  end
end
