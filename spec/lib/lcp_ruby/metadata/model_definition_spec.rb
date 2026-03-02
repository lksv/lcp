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

  describe "#belongs_to_fk_map" do
    it "returns FK-to-association mapping for belongs_to associations" do
      definition = described_class.from_hash(
        "name" => "deal",
        "fields" => [ { "name" => "title", "type" => "string" } ],
        "associations" => [
          { "type" => "belongs_to", "name" => "company", "target_model" => "company", "foreign_key" => "company_id" },
          { "type" => "belongs_to", "name" => "contact", "target_model" => "contact", "foreign_key" => "contact_id" }
        ]
      )

      fk_map = definition.belongs_to_fk_map

      expect(fk_map.keys).to contain_exactly("company_id", "contact_id")
      expect(fk_map["company_id"].name).to eq("company")
      expect(fk_map["contact_id"].name).to eq("contact")
    end

    it "excludes has_many and has_one associations" do
      definition = described_class.from_hash(
        "name" => "company",
        "fields" => [ { "name" => "name", "type" => "string" } ],
        "associations" => [
          { "type" => "has_many", "name" => "deals", "target_model" => "deal", "foreign_key" => "company_id" },
          { "type" => "has_one", "name" => "profile", "target_model" => "profile", "foreign_key" => "company_id" },
          { "type" => "belongs_to", "name" => "industry", "target_model" => "industry", "foreign_key" => "industry_id" }
        ]
      )

      fk_map = definition.belongs_to_fk_map

      expect(fk_map.keys).to eq([ "industry_id" ])
    end

    it "returns empty hash when no belongs_to associations exist" do
      definition = described_class.from_hash(
        "name" => "standalone",
        "fields" => [ { "name" => "title", "type" => "string" } ],
        "associations" => [
          { "type" => "has_many", "name" => "items", "target_model" => "item", "foreign_key" => "standalone_id" }
        ]
      )

      expect(definition.belongs_to_fk_map).to eq({})
    end

    it "returns empty hash when no associations exist" do
      definition = described_class.from_hash(
        "name" => "simple",
        "fields" => [ { "name" => "title", "type" => "string" } ]
      )

      expect(definition.belongs_to_fk_map).to eq({})
    end

    it "is memoized" do
      definition = described_class.from_hash(
        "name" => "deal",
        "fields" => [ { "name" => "title", "type" => "string" } ],
        "associations" => [
          { "type" => "belongs_to", "name" => "company", "target_model" => "company", "foreign_key" => "company_id" }
        ]
      )

      first_call = definition.belongs_to_fk_map
      second_call = definition.belongs_to_fk_map

      expect(first_call).to equal(second_call)
    end
  end

  describe "#display_templates" do
    it "parses display_templates from hash" do
      definition = described_class.from_hash(
        "name" => "contact",
        "fields" => [ { "name" => "first_name", "type" => "string" } ],
        "display_templates" => {
          "default" => {
            "template" => "{first_name} {last_name}",
            "subtitle" => "{position} at {company.name}",
            "icon" => "user"
          },
          "compact" => {
            "template" => "{last_name}, {first_name}"
          },
          "card" => {
            "renderer" => "ContactCardRenderer"
          }
        }
      )

      expect(definition.display_templates).to be_a(Hash)
      expect(definition.display_templates.size).to eq(3)

      default_tmpl = definition.display_template("default")
      expect(default_tmpl).to be_a(LcpRuby::Metadata::DisplayTemplateDefinition)
      expect(default_tmpl.template).to eq("{first_name} {last_name}")
      expect(default_tmpl.subtitle).to eq("{position} at {company.name}")
      expect(default_tmpl.icon).to eq("user")
      expect(default_tmpl).to be_structured

      compact_tmpl = definition.display_template("compact")
      expect(compact_tmpl.template).to eq("{last_name}, {first_name}")

      card_tmpl = definition.display_template("card")
      expect(card_tmpl).to be_renderer
    end

    it "returns nil for unknown template name" do
      definition = described_class.from_hash(
        "name" => "contact",
        "fields" => [ { "name" => "name", "type" => "string" } ],
        "display_templates" => {
          "default" => { "template" => "{name}" }
        }
      )

      expect(definition.display_template("nonexistent")).to be_nil
    end

    it "defaults display_template to look up 'default' name" do
      definition = described_class.from_hash(
        "name" => "contact",
        "fields" => [ { "name" => "name", "type" => "string" } ],
        "display_templates" => {
          "default" => { "template" => "{name}" }
        }
      )

      expect(definition.display_template).to be_a(LcpRuby::Metadata::DisplayTemplateDefinition)
      expect(definition.display_template.name).to eq("default")
    end

    it "returns empty hash when no display_templates defined" do
      definition = described_class.from_hash(
        "name" => "simple",
        "fields" => [ { "name" => "name", "type" => "string" } ]
      )

      expect(definition.display_templates).to eq({})
      expect(definition.display_template).to be_nil
    end
  end

  describe "#virtual?" do
    it "returns true when table_name is _virtual" do
      definition = described_class.from_hash(
        "name" => "item_def",
        "table_name" => "_virtual",
        "fields" => [ { "name" => "name", "type" => "string" } ]
      )
      expect(definition.virtual?).to be true
    end

    it "returns false for normal models" do
      definition = described_class.from_hash(
        "name" => "item",
        "fields" => [ { "name" => "name", "type" => "string" } ]
      )
      expect(definition.virtual?).to be false
    end
  end

  describe "model options predicates" do
    describe "#soft_delete?" do
      it "returns true when soft_delete is true" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "soft_delete" => true }
        )
        expect(definition.soft_delete?).to be true
        expect(definition.soft_delete_options).to eq({})
      end

      it "returns true when soft_delete is a Hash" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "soft_delete" => { "column" => "deleted_at" } }
        )
        expect(definition.soft_delete?).to be true
        expect(definition.soft_delete_options).to eq({ "column" => "deleted_at" })
      end

      it "returns false when soft_delete is absent" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ]
        )
        expect(definition.soft_delete?).to be false
        expect(definition.soft_delete_options).to eq({})
      end

      it "returns false when soft_delete is false" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "soft_delete" => false }
        )
        expect(definition.soft_delete?).to be false
      end

      it "returns false when soft_delete is nil" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "soft_delete" => nil }
        )
        expect(definition.soft_delete?).to be false
      end

      it "returns false when soft_delete is a string" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "soft_delete" => "yes" }
        )
        expect(definition.soft_delete?).to be false
      end
    end

    describe "#soft_delete_column" do
      it "defaults to discarded_at" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "soft_delete" => true }
        )
        expect(definition.soft_delete_column).to eq("discarded_at")
      end

      it "uses custom column when specified" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "soft_delete" => { "column" => "deleted_at" } }
        )
        expect(definition.soft_delete_column).to eq("deleted_at")
      end
    end

    describe "#auditing?" do
      it "returns true for boolean true" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "auditing" => true }
        )
        expect(definition.auditing?).to be true
        expect(definition.auditing_options).to eq({})
      end

      it "returns true for Hash" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "auditing" => { "only" => %w[title status] } }
        )
        expect(definition.auditing?).to be true
        expect(definition.auditing_options).to eq({ "only" => %w[title status] })
      end

      it "returns false when absent" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ]
        )
        expect(definition.auditing?).to be false
      end
    end

    describe "#userstamps?" do
      it "returns true for boolean true" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => true }
        )
        expect(definition.userstamps?).to be true
      end

      it "returns true for Hash" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => { "created_by" => "author_id" } }
        )
        expect(definition.userstamps?).to be true
        expect(definition.userstamps_options).to eq({ "created_by" => "author_id" })
      end

      it "returns false when absent" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ]
        )
        expect(definition.userstamps?).to be false
      end
    end

    describe "userstamps accessors" do
      it "returns default creator and updater fields" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => true }
        )
        expect(definition.userstamps_creator_field).to eq("created_by_id")
        expect(definition.userstamps_updater_field).to eq("updated_by_id")
      end

      it "returns custom creator and updater fields" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => { "created_by" => "author_id", "updated_by" => "editor_id" } }
        )
        expect(definition.userstamps_creator_field).to eq("author_id")
        expect(definition.userstamps_updater_field).to eq("editor_id")
      end

      it "returns false for store_name? by default" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => true }
        )
        expect(definition.userstamps_store_name?).to be false
      end

      it "returns true for store_name? when enabled" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => { "store_name" => true } }
        )
        expect(definition.userstamps_store_name?).to be true
      end

      it "returns nil for name fields when store_name is false" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => true }
        )
        expect(definition.userstamps_creator_name_field).to be_nil
        expect(definition.userstamps_updater_name_field).to be_nil
      end

      it "derives name fields from default FK columns" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => { "store_name" => true } }
        )
        expect(definition.userstamps_creator_name_field).to eq("created_by_name")
        expect(definition.userstamps_updater_name_field).to eq("updated_by_name")
      end

      it "derives name fields from custom FK columns" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => { "created_by" => "author_id", "updated_by" => "last_editor_id", "store_name" => true } }
        )
        expect(definition.userstamps_creator_name_field).to eq("author_name")
        expect(definition.userstamps_updater_name_field).to eq("last_editor_name")
      end
    end

    describe "#userstamp_column_names" do
      it "returns empty array when userstamps disabled" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ]
        )
        expect(definition.userstamp_column_names).to eq([])
      end

      it "returns FK columns for simple userstamps" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => true }
        )
        expect(definition.userstamp_column_names).to eq(%w[created_by_id updated_by_id])
      end

      it "includes name columns when store_name is true" do
        definition = described_class.from_hash(
          "name" => "item",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "userstamps" => { "store_name" => true } }
        )
        expect(definition.userstamp_column_names).to eq(%w[created_by_id updated_by_id created_by_name updated_by_name])
      end
    end

    describe "#tree?" do
      it "returns true for boolean true" do
        definition = described_class.from_hash(
          "name" => "category",
          "fields" => [ { "name" => "name", "type" => "string" } ],
          "options" => { "tree" => true }
        )
        expect(definition.tree?).to be true
      end

      it "returns true for Hash" do
        definition = described_class.from_hash(
          "name" => "category",
          "fields" => [ { "name" => "name", "type" => "string" } ],
          "options" => { "tree" => { "parent_field" => "parent_category_id" } }
        )
        expect(definition.tree?).to be true
        expect(definition.tree_options).to eq({ "parent_field" => "parent_category_id" })
      end
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

  describe "positioning" do
    it "returns positioned? false when no positioning config" do
      definition = described_class.from_hash(
        "name" => "simple",
        "fields" => [ { "name" => "title", "type" => "string" } ]
      )
      expect(definition.positioned?).to be false
      expect(definition.positioning_config).to be_nil
    end

    it "parses positioning: true as default config" do
      definition = described_class.from_hash(
        "name" => "stage",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "position", "type" => "integer" }
        ],
        "positioning" => true
      )
      expect(definition.positioned?).to be true
      expect(definition.positioning_field).to eq("position")
      expect(definition.positioning_scope).to eq([])
    end

    it "parses positioning with custom field" do
      definition = described_class.from_hash(
        "name" => "stage",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "sort_order", "type" => "integer" }
        ],
        "positioning" => { "field" => "sort_order" }
      )
      expect(definition.positioned?).to be true
      expect(definition.positioning_field).to eq("sort_order")
      expect(definition.positioning_scope).to eq([])
    end

    it "parses positioning with scope" do
      definition = described_class.from_hash(
        "name" => "stage",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "position", "type" => "integer" },
          { "name" => "pipeline_id", "type" => "integer" }
        ],
        "positioning" => { "field" => "position", "scope" => "pipeline_id" }
      )
      expect(definition.positioned?).to be true
      expect(definition.positioning_field).to eq("position")
      expect(definition.positioning_scope).to eq([ "pipeline_id" ])
    end

    it "parses positioning with array scope" do
      definition = described_class.from_hash(
        "name" => "item",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "position", "type" => "integer" },
          { "name" => "category_id", "type" => "integer" },
          { "name" => "group_id", "type" => "integer" }
        ],
        "positioning" => { "scope" => [ "category_id", "group_id" ] }
      )
      expect(definition.positioning_scope).to eq([ "category_id", "group_id" ])
    end

    it "returns nil for positioning: false" do
      definition = described_class.from_hash(
        "name" => "simple",
        "fields" => [ { "name" => "title", "type" => "string" } ],
        "positioning" => false
      )
      expect(definition.positioned?).to be false
    end
  end
end
