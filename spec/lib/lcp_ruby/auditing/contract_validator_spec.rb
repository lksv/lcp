require "spec_helper"

RSpec.describe LcpRuby::Auditing::ContractValidator do
  def build_model_def(fields:, name: "audit_log", options: {})
    hash = {
      "name" => name,
      "fields" => fields,
      "options" => options.merge("timestamps" => false)
    }
    LcpRuby::Metadata::ModelDefinition.from_hash(hash)
  end

  describe ".validate" do
    context "with a valid audit model" do
      it "passes with all required and recommended fields" do
        model_def = build_model_def(fields: [
          { "name" => "auditable_type", "type" => "string" },
          { "name" => "auditable_id", "type" => "integer" },
          { "name" => "action", "type" => "string" },
          { "name" => "changes_data", "type" => "json" },
          { "name" => "user_id", "type" => "integer" },
          { "name" => "user_snapshot", "type" => "json" },
          { "name" => "metadata", "type" => "json" },
          { "name" => "created_at", "type" => "datetime" }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.errors).to be_empty
        expect(result.warnings).to be_empty
      end
    end

    context "with missing required fields" do
      it "returns errors for missing auditable_type" do
        model_def = build_model_def(fields: [
          { "name" => "auditable_id", "type" => "integer" },
          { "name" => "action", "type" => "string" },
          { "name" => "changes_data", "type" => "json" },
          { "name" => "created_at", "type" => "datetime" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must have a 'auditable_type' field")
      end

      it "returns errors for missing changes_data" do
        model_def = build_model_def(fields: [
          { "name" => "auditable_type", "type" => "string" },
          { "name" => "auditable_id", "type" => "integer" },
          { "name" => "action", "type" => "string" },
          { "name" => "created_at", "type" => "datetime" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must have a 'changes_data' field")
      end
    end

    context "with wrong field types" do
      it "returns error when auditable_type is not string" do
        model_def = build_model_def(fields: [
          { "name" => "auditable_type", "type" => "integer" },
          { "name" => "auditable_id", "type" => "integer" },
          { "name" => "action", "type" => "string" },
          { "name" => "changes_data", "type" => "json" },
          { "name" => "created_at", "type" => "datetime" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must be type 'string'")
      end

      it "returns error when changes_data is not json" do
        model_def = build_model_def(fields: [
          { "name" => "auditable_type", "type" => "string" },
          { "name" => "auditable_id", "type" => "integer" },
          { "name" => "action", "type" => "string" },
          { "name" => "changes_data", "type" => "string" },
          { "name" => "created_at", "type" => "datetime" }
        ])

        result = described_class.validate(model_def)
        expect(result).not_to be_valid
        expect(result.errors.first).to include("must be type 'json'")
      end
    end

    context "with missing recommended fields" do
      it "passes with warnings when user_id is missing" do
        model_def = build_model_def(fields: [
          { "name" => "auditable_type", "type" => "string" },
          { "name" => "auditable_id", "type" => "integer" },
          { "name" => "action", "type" => "string" },
          { "name" => "changes_data", "type" => "json" },
          { "name" => "created_at", "type" => "datetime" }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.warnings).to include(a_string_matching(/user_id.*recommended/))
        expect(result.warnings).to include(a_string_matching(/user_snapshot.*recommended/))
      end
    end

    context "with missing created_at and no timestamps" do
      it "warns about missing chronological ordering" do
        model_def = build_model_def(fields: [
          { "name" => "auditable_type", "type" => "string" },
          { "name" => "auditable_id", "type" => "integer" },
          { "name" => "action", "type" => "string" },
          { "name" => "changes_data", "type" => "json" }
        ])

        result = described_class.validate(model_def)
        expect(result).to be_valid
        expect(result.warnings).to include(a_string_matching(/created_at.*timestamps/))
      end
    end

    context "with custom field mapping" do
      it "validates against mapped field names" do
        model_def = build_model_def(fields: [
          { "name" => "model_type", "type" => "string" },
          { "name" => "model_id", "type" => "integer" },
          { "name" => "operation", "type" => "string" },
          { "name" => "diff", "type" => "json" },
          { "name" => "created_at", "type" => "datetime" }
        ])

        mapping = {
          auditable_type: "model_type",
          auditable_id: "model_id",
          action: "operation",
          changes_data: "diff"
        }

        result = described_class.validate(model_def, mapping)
        expect(result).to be_valid
      end
    end
  end
end
