require "spec_helper"

RSpec.describe LcpRuby::Metadata::ModelDefinition do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  let(:valid_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
  end

  describe ".from_hash" do
    subject(:definition) { described_class.from_hash(valid_hash) }

    it "parses the model name" do
      expect(definition.name).to eq("project")
    end

    it "parses labels" do
      expect(definition.label).to eq("Project")
      expect(definition.label_plural).to eq("Projects")
    end

    it "defaults table_name to pluralized name" do
      expect(definition.table_name).to eq("projects")
    end

    it "parses fields" do
      expect(definition.fields).to be_an(Array)
      expect(definition.fields.length).to be >= 5

      title_field = definition.field("title")
      expect(title_field).to be_a(LcpRuby::Metadata::FieldDefinition)
      expect(title_field.type).to eq("string")
      expect(title_field.label).to eq("Title")
    end

    it "parses enum fields" do
      status_field = definition.field("status")
      expect(status_field.enum?).to be true
      expect(status_field.enum_value_names).to include("draft", "active", "completed", "archived")
      expect(status_field.default).to eq("draft")
    end

    it "parses field validations" do
      title_field = definition.field("title")
      expect(title_field.validations.length).to eq(2)
      expect(title_field.validations.first.type).to eq("presence")
    end

    it "parses column options" do
      title_field = definition.field("title")
      expect(title_field.column_options[:limit]).to eq(255)
    end

    it "parses scopes" do
      expect(definition.scopes).to be_an(Array)
      expect(definition.scopes.length).to be >= 2
    end

    it "parses events" do
      expect(definition.events).to be_an(Array)
      expect(definition.events.length).to be >= 3
    end

    it "parses options" do
      expect(definition.timestamps?).to be true
      expect(definition.label_method).to eq("title")
    end
  end

  describe "validation" do
    it "raises on missing name" do
      expect {
        described_class.from_hash({})
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises on duplicate field names" do
      hash = valid_hash.dup
      hash["fields"] = [
        { "name" => "title", "type" => "string" },
        { "name" => "title", "type" => "text" }
      ]

      expect {
        described_class.from_hash(hash)
      }.to raise_error(LcpRuby::MetadataError, /Duplicate field names/)
    end
  end
end
