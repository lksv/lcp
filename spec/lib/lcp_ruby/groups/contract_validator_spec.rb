require "spec_helper"

RSpec.describe LcpRuby::Groups::ContractValidator do
  describe ".validate_group" do
    it "passes for a valid group model" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group",
        "fields" => [
          { "name" => "name", "type" => "string", "validations" => [{ "type" => "uniqueness" }] },
          { "name" => "active", "type" => "boolean" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_group(model_def)
      expect(result).to be_valid
    end

    it "errors when name field is missing" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group",
        "fields" => [{ "name" => "label", "type" => "string" }],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_group(model_def)
      expect(result).not_to be_valid
      expect(result.errors.first).to match(/must have a 'name' field/)
    end

    it "errors when name field is not string type" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group",
        "fields" => [{ "name" => "name", "type" => "integer" }],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_group(model_def)
      expect(result).not_to be_valid
      expect(result.errors.first).to match(/must be type 'string'/)
    end

    it "warns when name field lacks uniqueness validation" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group",
        "fields" => [{ "name" => "name", "type" => "string" }],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_group(model_def)
      expect(result).to be_valid
      expect(result.warnings.first).to match(/should have a uniqueness validation/)
    end

    it "errors when active field is not boolean" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group",
        "fields" => [
          { "name" => "name", "type" => "string", "validations" => [{ "type" => "uniqueness" }] },
          { "name" => "active", "type" => "string" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_group(model_def)
      expect(result).not_to be_valid
      expect(result.errors.first).to match(/must be type 'boolean'/)
    end

    it "accepts custom field mapping" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group",
        "fields" => [
          { "name" => "group_name", "type" => "string", "validations" => [{ "type" => "uniqueness" }] },
          { "name" => "enabled", "type" => "boolean" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_group(model_def, { name: "group_name", active: "enabled" })
      expect(result).to be_valid
    end
  end

  describe ".validate_membership" do
    it "passes for a valid membership model with belongs_to" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_membership",
        "fields" => [
          { "name" => "user_id", "type" => "integer" }
        ],
        "associations" => [
          { "name" => "group", "type" => "belongs_to", "target_model" => "group" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_membership(model_def)
      expect(result).to be_valid
    end

    it "errors when both group FK and association are missing" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_membership",
        "fields" => [
          { "name" => "user_id", "type" => "integer" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_membership(model_def)
      expect(result).not_to be_valid
      expect(result.errors.first).to match(/must have a 'group_id' belongs_to association or field/)
    end

    it "errors when user FK is missing" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_membership",
        "fields" => [],
        "associations" => [
          { "name" => "group", "type" => "belongs_to", "target_model" => "group" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_membership(model_def)
      expect(result).not_to be_valid
      expect(result.errors.first).to match(/must have a 'user_id' field or belongs_to/)
    end

    it "warns when group FK is a plain field instead of belongs_to" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_membership",
        "fields" => [
          { "name" => "group_id", "type" => "integer" },
          { "name" => "user_id", "type" => "integer" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_membership(model_def)
      expect(result).to be_valid
      expect(result.warnings).to include(match(/plain field.*belongs_to association is recommended/))
    end
  end

  describe ".validate_role_mapping" do
    it "passes for a valid role mapping model" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_role_mapping",
        "fields" => [
          { "name" => "role_name", "type" => "string" }
        ],
        "associations" => [
          { "name" => "group", "type" => "belongs_to", "target_model" => "group" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_role_mapping(model_def)
      expect(result).to be_valid
    end

    it "errors when role field is missing" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_role_mapping",
        "fields" => [],
        "associations" => [
          { "name" => "group", "type" => "belongs_to", "target_model" => "group" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_role_mapping(model_def)
      expect(result).not_to be_valid
      expect(result.errors.first).to match(/must have a 'role_name' field/)
    end

    it "errors when role field is not string type" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_role_mapping",
        "fields" => [
          { "name" => "role_name", "type" => "integer" }
        ],
        "associations" => [
          { "name" => "group", "type" => "belongs_to", "target_model" => "group" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_role_mapping(model_def)
      expect(result).not_to be_valid
      expect(result.errors.first).to match(/must be type 'string'/)
    end

    it "warns when group FK is a plain field instead of belongs_to" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "group_role_mapping",
        "fields" => [
          { "name" => "group_id", "type" => "integer" },
          { "name" => "role_name", "type" => "string" }
        ],
        "options" => { "timestamps" => true }
      })

      result = described_class.validate_role_mapping(model_def)
      expect(result).to be_valid
      expect(result.warnings).to include(match(/plain field.*belongs_to association is recommended/))
    end
  end
end
