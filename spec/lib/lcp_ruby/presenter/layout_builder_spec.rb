require "spec_helper"

RSpec.describe LcpRuby::Presenter::LayoutBuilder do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  let(:model_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/task.yml"))["model"]
  end
  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash) }

  let(:presenter_hash) do
    # Build a minimal presenter config with an association_select field
    {
      "name" => "task_admin",
      "model" => "task",
      "label" => "Tasks",
      "slug" => "tasks",
      "index" => { "default_view" => "table", "per_page" => 25, "table_columns" => [] },
      "show" => { "layout" => [] },
      "form" => {
        "sections" => [
          {
            "title" => "Details",
            "columns" => 1,
            "fields" => [
              { "field" => "title", "placeholder" => "Enter title..." },
              { "field" => "project_id", "input_type" => "association_select" }
            ]
          }
        ]
      },
      "search" => { "enabled" => false },
      "actions" => { "collection" => [], "single" => [] }
    }
  end
  let(:presenter_definition) { LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash) }

  subject(:builder) { described_class.new(presenter_definition, model_definition) }

  describe "#form_sections" do
    let(:sections) { builder.form_sections }
    let(:fields) { sections.first["fields"] }

    it "enriches regular fields with field_definition" do
      title_field = fields.find { |f| f["field"] == "title" }
      expect(title_field["field_definition"]).to be_a(LcpRuby::Metadata::FieldDefinition)
      expect(title_field["field_definition"].name).to eq("title")
    end

    it "enriches association FK fields with synthetic field_definition" do
      fk_field = fields.find { |f| f["field"] == "project_id" }
      expect(fk_field["field_definition"]).to be_a(LcpRuby::Metadata::FieldDefinition)
      expect(fk_field["field_definition"].name).to eq("project_id")
      expect(fk_field["field_definition"].type).to eq("integer")
    end

    it "includes association metadata for FK fields" do
      fk_field = fields.find { |f| f["field"] == "project_id" }
      expect(fk_field["association"]).to be_a(LcpRuby::Metadata::AssociationDefinition)
      expect(fk_field["association"].name).to eq("project")
      expect(fk_field["association"].target_model).to eq("project")
    end

    it "sets humanized label from association name" do
      fk_field = fields.find { |f| f["field"] == "project_id" }
      expect(fk_field["field_definition"].label).to eq("Project")
    end

    it "does not add association key for regular fields" do
      title_field = fields.find { |f| f["field"] == "title" }
      expect(title_field).not_to have_key("association")
    end
  end

  describe "#form_sections with unknown FK field" do
    let(:presenter_hash) do
      {
        "name" => "task_admin",
        "model" => "task",
        "label" => "Tasks",
        "slug" => "tasks",
        "index" => { "default_view" => "table", "per_page" => 25, "table_columns" => [] },
        "show" => { "layout" => [] },
        "form" => {
          "sections" => [
            {
              "title" => "Details",
              "columns" => 1,
              "fields" => [
                { "field" => "nonexistent_field" }
              ]
            }
          ]
        },
        "search" => { "enabled" => false },
        "actions" => { "collection" => [], "single" => [] }
      }
    end

    it "leaves field_definition nil for unknown fields" do
      fields = builder.form_sections.first["fields"]
      unknown = fields.find { |f| f["field"] == "nonexistent_field" }
      expect(unknown["field_definition"]).to be_nil
    end
  end
end
