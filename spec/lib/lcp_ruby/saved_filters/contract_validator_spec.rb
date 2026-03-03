require "spec_helper"

RSpec.describe LcpRuby::SavedFilters::ContractValidator do
  let(:base_fields) do
    [
      { "name" => "name", "type" => "string" },
      { "name" => "target_presenter", "type" => "string" },
      { "name" => "condition_tree", "type" => "json" },
      { "name" => "visibility", "type" => "enum" },
      { "name" => "owner_id", "type" => "integer" },
      { "name" => "pinned", "type" => "boolean" },
      { "name" => "default_filter", "type" => "boolean" },
      { "name" => "ql_text", "type" => "text" },
      { "name" => "description", "type" => "text" },
      { "name" => "target_role", "type" => "string" },
      { "name" => "target_group", "type" => "string" },
      { "name" => "position", "type" => "integer" },
      { "name" => "icon", "type" => "string" },
      { "name" => "color", "type" => "string" }
    ]
  end

  def build_model_def(fields:)
    model_data = { "name" => "saved_filter", "fields" => fields }
    LcpRuby::Metadata::ModelDefinition.from_hash(model_data)
  end

  describe ".validate" do
    context "with all required and recommended fields" do
      it "returns valid result with no errors or warnings" do
        result = described_class.validate(build_model_def(fields: base_fields))
        expect(result.errors).to be_empty
        expect(result.warnings).to be_empty
      end
    end

    context "with missing required field" do
      it "returns an error for missing 'name' field" do
        fields = base_fields.reject { |f| f["name"] == "name" }
        result = described_class.validate(build_model_def(fields: fields))
        expect(result.errors).to include(a_string_matching(/must have a 'name' field/))
      end

      it "returns an error for missing 'condition_tree' field" do
        fields = base_fields.reject { |f| f["name"] == "condition_tree" }
        result = described_class.validate(build_model_def(fields: fields))
        expect(result.errors).to include(a_string_matching(/must have a 'condition_tree' field/))
      end
    end

    context "with wrong type for required field" do
      it "returns an error when condition_tree is string instead of json" do
        fields = base_fields.map do |f|
          f["name"] == "condition_tree" ? f.merge("type" => "string") : f
        end
        result = described_class.validate(build_model_def(fields: fields))
        expect(result.errors).to include(a_string_matching(/condition_tree.*must be type/))
      end
    end

    context "with missing recommended field" do
      it "returns a warning for missing 'ql_text' field" do
        fields = base_fields.reject { |f| f["name"] == "ql_text" }
        result = described_class.validate(build_model_def(fields: fields))
        expect(result.errors).to be_empty
        expect(result.warnings).to include(a_string_matching(/'ql_text'.*recommended/))
      end
    end
  end
end
