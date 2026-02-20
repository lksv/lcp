require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::CustomFields::Registry do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("custom_fields_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("custom_fields_test")
  end

  before(:each) do
    Object.new.extend(IntegrationHelper).load_integration_metadata!("custom_fields_test")
  end

  let(:cfd_model) { LcpRuby.registry.model_for("custom_field_definition") }

  describe ".for_model" do
    it "returns empty array when no definitions exist" do
      expect(described_class.for_model("project")).to eq([])
    end

    it "returns definitions for a model ordered by position" do
      cfd_model.create!(
        target_model: "project", field_name: "website",
        custom_type: "string", label: "Website", position: 2
      )
      cfd_model.create!(
        target_model: "project", field_name: "priority",
        custom_type: "integer", label: "Priority", position: 1
      )

      result = described_class.for_model("project")
      expect(result.length).to eq(2)
      expect(result.first.field_name).to eq("priority")
      expect(result.last.field_name).to eq("website")
    end

    it "only returns active definitions" do
      cfd_model.create!(
        target_model: "project", field_name: "active_field",
        custom_type: "string", label: "Active", active: true
      )
      cfd_model.create!(
        target_model: "project", field_name: "inactive_field",
        custom_type: "string", label: "Inactive", active: false
      )

      result = described_class.for_model("project")
      expect(result.length).to eq(1)
      expect(result.first.field_name).to eq("active_field")
    end

    it "scopes by target_model" do
      cfd_model.create!(
        target_model: "project", field_name: "proj_field",
        custom_type: "string", label: "Project Field"
      )
      cfd_model.create!(
        target_model: "other_model", field_name: "other_field",
        custom_type: "string", label: "Other Field"
      )

      result = described_class.for_model("project")
      expect(result.length).to eq(1)
      expect(result.first.field_name).to eq("proj_field")
    end

    it "caches results" do
      cfd_model.create!(
        target_model: "project", field_name: "cached_field",
        custom_type: "string", label: "Cached"
      )

      result1 = described_class.for_model("project")
      result2 = described_class.for_model("project")
      expect(result1).to equal(result2)
    end
  end

  describe ".reload!" do
    it "clears cache for specific model" do
      cfd_model.create!(
        target_model: "project", field_name: "reloaded",
        custom_type: "string", label: "Reloaded"
      )

      result1 = described_class.for_model("project")
      described_class.reload!("project")
      result2 = described_class.for_model("project")
      expect(result1).not_to equal(result2)
    end

    it "clears all caches when called without argument" do
      cfd_model.create!(
        target_model: "project", field_name: "all_clear",
        custom_type: "string", label: "All Clear"
      )

      described_class.for_model("project")
      described_class.reload!
      result = described_class.for_model("project")
      expect(result.length).to eq(1)
    end
  end

  describe ".available?" do
    it "returns true after mark_available!" do
      described_class.clear!
      expect(described_class.available?).to be false

      described_class.mark_available!
      expect(described_class.available?).to be true
    end
  end

  describe ".clear!" do
    it "resets availability and cache" do
      described_class.mark_available!
      described_class.clear!
      expect(described_class.available?).to be false
    end
  end
end
