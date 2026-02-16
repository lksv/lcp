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

  describe "#form_layout" do
    it "returns 'flat' by default" do
      expect(builder.form_layout).to eq("flat")
    end

    it "returns configured layout value" do
      presenter_with_tabs = LcpRuby::Metadata::PresenterDefinition.from_hash(
        presenter_hash.merge("form" => presenter_hash["form"].merge("layout" => "tabs"))
      )
      tabs_builder = described_class.new(presenter_with_tabs, model_definition)

      expect(tabs_builder.form_layout).to eq("tabs")
    end
  end

  describe "#form_sections with nested_fields" do
    let(:todo_list_hash) do
      {
        "name" => "todo_list",
        "label" => "Todo List",
        "fields" => [
          { "name" => "title", "type" => "string", "label" => "Title" }
        ],
        "associations" => [
          {
            "type" => "has_many",
            "name" => "todo_items",
            "target_model" => "todo_item",
            "dependent" => "destroy",
            "inverse_of" => "todo_list",
            "nested_attributes" => { "allow_destroy" => true }
          }
        ]
      }
    end
    let(:todo_list_model_def) { LcpRuby::Metadata::ModelDefinition.from_hash(todo_list_hash) }

    let(:todo_item_hash) do
      {
        "name" => "todo_item",
        "label" => "Todo Item",
        "fields" => [
          { "name" => "title", "type" => "string", "label" => "Title" },
          { "name" => "completed", "type" => "boolean", "label" => "Completed" }
        ],
        "associations" => [
          {
            "type" => "belongs_to",
            "name" => "todo_list",
            "target_model" => "todo_list",
            "inverse_of" => "todo_items"
          }
        ]
      }
    end
    let(:todo_item_model_def) { LcpRuby::Metadata::ModelDefinition.from_hash(todo_item_hash) }

    let(:nested_presenter_hash) do
      {
        "name" => "todo_list_admin",
        "model" => "todo_list",
        "label" => "Lists",
        "slug" => "lists",
        "index" => { "default_view" => "table", "per_page" => 25, "table_columns" => [] },
        "show" => { "layout" => [] },
        "form" => {
          "sections" => [
            {
              "title" => "Details",
              "columns" => 1,
              "fields" => [
                { "field" => "title" }
              ]
            },
            {
              "title" => "Items",
              "type" => "nested_fields",
              "association" => "todo_items",
              "allow_add" => true,
              "allow_remove" => true,
              "fields" => [
                { "field" => "title" },
                { "field" => "completed" }
              ]
            }
          ]
        },
        "search" => { "enabled" => false },
        "actions" => { "collection" => [], "single" => [] }
      }
    end
    let(:nested_presenter_def) { LcpRuby::Metadata::PresenterDefinition.from_hash(nested_presenter_hash) }

    before do
      loader = instance_double(LcpRuby::Metadata::Loader)
      allow(LcpRuby).to receive(:loader).and_return(loader)
      allow(loader).to receive(:model_definition).with("todo_item").and_return(todo_item_model_def)
    end

    subject(:nested_builder) { described_class.new(nested_presenter_def, todo_list_model_def) }

    it "enriches nested section fields with target model field_definitions" do
      sections = nested_builder.form_sections
      nested_section = sections.find { |s| s["type"] == "nested_fields" }

      title_field = nested_section["fields"].find { |f| f["field"] == "title" }
      expect(title_field["field_definition"]).to be_a(LcpRuby::Metadata::FieldDefinition)
      expect(title_field["field_definition"].name).to eq("title")

      completed_field = nested_section["fields"].find { |f| f["field"] == "completed" }
      expect(completed_field["field_definition"]).to be_a(LcpRuby::Metadata::FieldDefinition)
      expect(completed_field["field_definition"].type).to eq("boolean")
    end

    it "attaches association_definition to nested section" do
      sections = nested_builder.form_sections
      nested_section = sections.find { |s| s["type"] == "nested_fields" }

      expect(nested_section["association_definition"]).to be_a(LcpRuby::Metadata::AssociationDefinition)
      expect(nested_section["association_definition"].name).to eq("todo_items")
    end

    it "attaches target_model_definition to nested section" do
      sections = nested_builder.form_sections
      nested_section = sections.find { |s| s["type"] == "nested_fields" }

      expect(nested_section["target_model_definition"]).to eq(todo_item_model_def)
    end

    it "preserves regular section alongside nested section" do
      sections = nested_builder.form_sections
      regular = sections.find { |s| s["type"] != "nested_fields" }

      expect(regular["title"]).to eq("Details")
      title_field = regular["fields"].find { |f| f["field"] == "title" }
      expect(title_field["field_definition"]).to be_a(LcpRuby::Metadata::FieldDefinition)
    end

    context "with sortable" do
      it "resolves sortable: true to sortable_field 'position'" do
        sortable_presenter_hash = nested_presenter_hash.deep_dup
        sortable_presenter_hash["form"]["sections"][1]["sortable"] = true
        sortable_presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(sortable_presenter_hash)

        sortable_builder = described_class.new(sortable_presenter_def, todo_list_model_def)
        sections = sortable_builder.form_sections
        nested_section = sections.find { |s| s["type"] == "nested_fields" }

        expect(nested_section["sortable_field"]).to eq("position")
      end

      it "resolves sortable: 'sort_order' to sortable_field 'sort_order'" do
        sortable_presenter_hash = nested_presenter_hash.deep_dup
        sortable_presenter_hash["form"]["sections"][1]["sortable"] = "sort_order"
        sortable_presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(sortable_presenter_hash)

        sortable_builder = described_class.new(sortable_presenter_def, todo_list_model_def)
        sections = sortable_builder.form_sections
        nested_section = sections.find { |s| s["type"] == "nested_fields" }

        expect(nested_section["sortable_field"]).to eq("sort_order")
      end

      it "does not set sortable_field when sortable is absent" do
        sections = nested_builder.form_sections
        nested_section = sections.find { |s| s["type"] == "nested_fields" }

        expect(nested_section).not_to have_key("sortable_field")
      end
    end

    it "returns section unchanged when association not found" do
      bad_presenter_hash = nested_presenter_hash.deep_dup
      bad_presenter_hash["form"]["sections"][1]["association"] = "nonexistent"
      bad_presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(bad_presenter_hash)

      bad_builder = described_class.new(bad_presenter_def, todo_list_model_def)
      sections = bad_builder.form_sections
      nested = sections.find { |s| s["type"] == "nested_fields" }

      expect(nested["association_definition"]).to be_nil
    end
  end
end
