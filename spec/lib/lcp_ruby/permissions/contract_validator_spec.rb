require "spec_helper"

RSpec.describe LcpRuby::Permissions::ContractValidator do
  def build_model_def(fields:, name: "permission_config")
    hash = {
      "name" => name,
      "fields" => fields,
      "options" => { "timestamps" => true }
    }
    LcpRuby::Metadata::ModelDefinition.from_hash(hash)
  end

  describe ".validate" do
    context "with valid permission config model" do
      it "passes when target_model is string, definition is json, active is boolean" do
        model_def = build_model_def(fields: [
          { "name" => "target_model", "type" => "string" },
          { "name" => "definition", "type" => "json" },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.errors).to be_empty
      end

      it "passes with custom field mapping" do
        model_def = build_model_def(fields: [
          { "name" => "target", "type" => "string" },
          { "name" => "perm_json", "type" => "json" },
          { "name" => "enabled", "type" => "boolean" }
        ])

        result = described_class.validate(model_def, {
          target_model: "target", definition: "perm_json", active: "enabled"
        })
        expect(result).to be_valid
      end
    end

    context "with missing target_model field" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "definition", "type" => "json" },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must have a 'target_model' field")
      end
    end

    context "with wrong target_model field type" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "target_model", "type" => "integer" },
          { "name" => "definition", "type" => "json" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must be type 'string'")
      end
    end

    context "with missing definition field" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "target_model", "type" => "string" },
          { "name" => "active", "type" => "boolean" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must have a 'definition' field")
      end
    end

    context "with wrong definition field type" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "target_model", "type" => "string" },
          { "name" => "definition", "type" => "text" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must be type 'json'")
      end
    end

    context "with wrong active field type" do
      it "returns an error" do
        model_def = build_model_def(fields: [
          { "name" => "target_model", "type" => "string" },
          { "name" => "definition", "type" => "json" },
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
          { "name" => "target_model", "type" => "string" },
          { "name" => "definition", "type" => "json" }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
      end
    end
  end
end
