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
      "name" => "task",
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
        "name" => "task",
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
        "name" => "todo_list",
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

  describe "#show_sections with association_list enrichment" do
    let(:company_model_hash) do
      {
        "name" => "company",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "associations" => [
          {
            "type" => "has_many",
            "name" => "contacts",
            "target_model" => "contact",
            "foreign_key" => "company_id",
            "dependent" => "destroy"
          }
        ]
      }
    end
    let(:company_model_def) { LcpRuby::Metadata::ModelDefinition.from_hash(company_model_hash) }

    let(:contact_model_def) do
      LcpRuby::Metadata::ModelDefinition.from_hash(
        "name" => "contact",
        "fields" => [
          { "name" => "first_name", "type" => "string" },
          { "name" => "last_name", "type" => "string" }
        ],
        "display_templates" => {
          "default" => { "template" => "{first_name} {last_name}" }
        }
      )
    end

    let(:show_presenter_hash) do
      {
        "name" => "company_admin",
        "model" => "company",
        "label" => "Companies",
        "slug" => "companies",
        "index" => { "default_view" => "table", "per_page" => 25, "table_columns" => [] },
        "show" => {
          "layout" => [
            { "section" => "Info", "fields" => [ { "field" => "name" } ] },
            {
              "section" => "Contacts",
              "type" => "association_list",
              "association" => "contacts",
              "display" => "default",
              "link" => true,
              "limit" => 5,
              "empty_message" => "No contacts."
            }
          ]
        },
        "form" => { "sections" => [] },
        "search" => { "enabled" => false },
        "actions" => { "collection" => [], "single" => [] }
      }
    end
    let(:show_presenter_def) { LcpRuby::Metadata::PresenterDefinition.from_hash(show_presenter_hash) }

    before do
      loader = instance_double(LcpRuby::Metadata::Loader)
      allow(LcpRuby).to receive(:loader).and_return(loader)
      allow(loader).to receive(:model_definition).with("contact").and_return(contact_model_def)
    end

    subject(:show_builder) { described_class.new(show_presenter_def, company_model_def) }

    it "attaches association_definition to association_list section" do
      sections = show_builder.show_sections
      assoc_section = sections.find { |s| s["type"] == "association_list" }

      expect(assoc_section["association_definition"]).to be_a(LcpRuby::Metadata::AssociationDefinition)
      expect(assoc_section["association_definition"].name).to eq("contacts")
    end

    it "attaches target_model_definition to association_list section" do
      sections = show_builder.show_sections
      assoc_section = sections.find { |s| s["type"] == "association_list" }

      expect(assoc_section["target_model_definition"]).to eq(contact_model_def)
    end

    it "preserves original section keys" do
      sections = show_builder.show_sections
      assoc_section = sections.find { |s| s["type"] == "association_list" }

      expect(assoc_section["display"]).to eq("default")
      expect(assoc_section["link"]).to eq(true)
      expect(assoc_section["limit"]).to eq(5)
      expect(assoc_section["empty_message"]).to eq("No contacts.")
    end

    it "does not enrich non-association_list sections" do
      sections = show_builder.show_sections
      info_section = sections.find { |s| s["section"] == "Info" }

      expect(info_section).not_to have_key("association_definition")
      expect(info_section).not_to have_key("target_model_definition")
    end

    it "returns section unchanged when association not found" do
      bad_hash = show_presenter_hash.deep_dup
      bad_hash["show"]["layout"][1]["association"] = "nonexistent"
      bad_def = LcpRuby::Metadata::PresenterDefinition.from_hash(bad_hash)
      builder = described_class.new(bad_def, company_model_def)

      sections = builder.show_sections
      assoc_section = sections.find { |s| s["type"] == "association_list" }

      expect(assoc_section).not_to have_key("association_definition")
    end
  end

  describe "#form_sections with multi_select" do
    let(:through_model_hash) do
      {
        "name" => "article",
        "label" => "Article",
        "fields" => [
          { "name" => "title", "type" => "string", "label" => "Title" }
        ],
        "associations" => [
          {
            "type" => "has_many",
            "name" => "article_tags",
            "target_model" => "article_tag",
            "dependent" => "destroy"
          },
          {
            "type" => "has_many",
            "name" => "tags",
            "target_model" => "tag",
            "through" => "article_tags"
          }
        ]
      }
    end
    let(:through_model_def) { LcpRuby::Metadata::ModelDefinition.from_hash(through_model_hash) }

    let(:multi_select_presenter_hash) do
      {
        "name" => "article",
        "model" => "article",
        "label" => "Articles",
        "slug" => "articles",
        "index" => { "default_view" => "table", "per_page" => 25, "table_columns" => [] },
        "show" => { "layout" => [] },
        "form" => {
          "sections" => [
            {
              "title" => "Details",
              "columns" => 1,
              "fields" => [
                { "field" => "title" },
                {
                  "field" => "tag_ids",
                  "input_type" => "multi_select",
                  "input_options" => { "association" => "tags" }
                }
              ]
            }
          ]
        },
        "search" => { "enabled" => false },
        "actions" => { "collection" => [], "single" => [] }
      }
    end
    let(:multi_select_presenter_def) { LcpRuby::Metadata::PresenterDefinition.from_hash(multi_select_presenter_hash) }
    subject(:ms_builder) { described_class.new(multi_select_presenter_def, through_model_def) }

    it "enriches multi_select field with multi_select_association" do
      sections = ms_builder.form_sections
      tag_field = sections.first["fields"].find { |f| f["field"] == "tag_ids" }

      expect(tag_field["multi_select_association"]).to be_a(LcpRuby::Metadata::AssociationDefinition)
      expect(tag_field["multi_select_association"].name).to eq("tags")
      expect(tag_field["multi_select_association"].through?).to be true
    end

    it "creates synthetic field_definition for multi_select field" do
      sections = ms_builder.form_sections
      tag_field = sections.first["fields"].find { |f| f["field"] == "tag_ids" }

      expect(tag_field["field_definition"]).to be_a(LcpRuby::Metadata::FieldDefinition)
      expect(tag_field["field_definition"].name).to eq("tag_ids")
      expect(tag_field["field_definition"].type).to eq("integer")
    end

    it "does not enrich when association is not through" do
      non_through_hash = through_model_hash.deep_dup
      non_through_hash["associations"] = [
        { "type" => "has_many", "name" => "tags", "target_model" => "tag" }
      ]
      non_through_def = LcpRuby::Metadata::ModelDefinition.from_hash(non_through_hash)
      builder = described_class.new(multi_select_presenter_def, non_through_def)

      sections = builder.form_sections
      tag_field = sections.first["fields"].find { |f| f["field"] == "tag_ids" }

      expect(tag_field["multi_select_association"]).to be_nil
    end

    it "does not enrich when association name does not match" do
      presenter_hash = multi_select_presenter_hash.deep_dup
      presenter_hash["form"]["sections"][0]["fields"][1]["input_options"]["association"] = "categories"
      presenter_def = LcpRuby::Metadata::PresenterDefinition.from_hash(presenter_hash)
      builder = described_class.new(presenter_def, through_model_def)

      sections = builder.form_sections
      cat_field = sections.first["fields"].find { |f| f["field"] == "tag_ids" }

      expect(cat_field["multi_select_association"]).to be_nil
    end
  end
end
