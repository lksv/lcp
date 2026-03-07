require "spec_helper"

RSpec.describe LcpRuby::VirtualColumns::Collector do
  before do
    LcpRuby.reset!
    LcpRuby::Types::BuiltInTypes.register_all!
  end

  def make_model_def(hash)
    LcpRuby::Metadata::ModelDefinition.from_hash(hash)
  end

  def make_presenter_def(hash)
    LcpRuby::Metadata::PresenterDefinition.from_hash(hash)
  end

  let(:model_def) do
    make_model_def({
      "name" => "order",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "status", "type" => "string" },
        { "name" => "due_date", "type" => "date" }
      ],
      "associations" => [
        { "type" => "has_many", "name" => "items", "target_model" => "item", "foreign_key" => "order_id" }
      ],
      "virtual_columns" => {
        "items_count" => { "function" => "count", "association" => "items" },
        "total_value" => {
          "expression" => "SUM(items.price)",
          "join" => "LEFT JOIN items ON items.order_id = %{table}.id",
          "group" => true,
          "type" => "decimal"
        },
        "is_overdue" => {
          "expression" => "CASE WHEN %{table}.due_date < CURRENT_DATE THEN 1 ELSE 0 END",
          "type" => "boolean"
        },
        "auto_col" => {
          "expression" => "1",
          "type" => "integer",
          "auto_include" => true
        }
      }
    })
  end

  describe ".collect for :index context" do
    it "collects VCs from table_columns" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [
            { "field" => "title" },
            { "field" => "items_count" }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("items_count")
      expect(result).to include("auto_col") # auto_include always included
    end

    it "collects VCs from tile_fields" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "layout" => "tiles",
          "tile" => {
            "title_field" => "title",
            "fields" => [ { "field" => "items_count" } ]
          }
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("items_count")
    end

    it "collects VCs from item_classes conditions" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "item_classes" => [
            { "css_class" => "highlight", "when" => { "field" => "is_overdue", "operator" => "eq", "value" => true } }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("is_overdue")
    end

    it "collects VCs from compound item_classes conditions" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "item_classes" => [
            {
              "css_class" => "highlight",
              "when" => {
                "all" => [
                  { "field" => "is_overdue", "operator" => "eq", "value" => true },
                  { "field" => "items_count", "operator" => "gt", "value" => 0 }
                ]
              }
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("is_overdue", "items_count")
    end

    it "collects VCs from action visible_when" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ]
        },
        "actions" => {
          "single" => [
            {
              "name" => "approve",
              "type" => "custom",
              "visible_when" => { "field" => "items_count", "operator" => "gt", "value" => 0 }
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("items_count")
    end

    it "collects from explicit index virtual_columns" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "virtual_columns" => [ "total_value", "is_overdue" ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("total_value", "is_overdue")
    end

    it "always includes auto_include virtual columns" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("auto_col")
      expect(result).not_to include("items_count") # not referenced
    end
  end

  describe ".collect for :show context" do
    it "collects VCs from show layout fields" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "show" => {
          "layout" => [
            {
              "title" => "Details",
              "fields" => [
                { "field" => "title" },
                { "field" => "items_count" },
                { "field" => "is_overdue" }
              ]
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :show)
      expect(result).to include("items_count", "is_overdue")
    end

    it "collects from explicit show virtual_columns" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "show" => {
          "virtual_columns" => [ "total_value" ],
          "layout" => [
            { "title" => "Details", "fields" => [ { "field" => "title" } ] }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :show)
      expect(result).to include("total_value")
    end
  end

  describe ".collect for :edit context" do
    it "collects VCs from form field visible_when conditions" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "form" => {
          "sections" => [
            {
              "title" => "Details",
              "fields" => [
                {
                  "field" => "title",
                  "visible_when" => { "field" => "is_overdue", "operator" => "eq", "value" => false }
                }
              ]
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :edit)
      expect(result).to include("is_overdue")
    end
  end

  describe "action-level virtual_columns declarations" do
    it "collects VCs from action virtual_columns arrays" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ]
        },
        "actions" => {
          "single" => [
            {
              "name" => "escalate",
              "type" => "custom",
              "virtual_columns" => [ "items_count", "is_overdue" ]
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("items_count", "is_overdue")
    end

    it "ignores unknown VC names in action virtual_columns" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => { "table_columns" => [ { "field" => "title" } ] },
        "actions" => {
          "single" => [
            { "name" => "test", "type" => "custom", "virtual_columns" => [ "nonexistent" ] }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).not_to include("nonexistent")
    end
  end

  describe "scope-level virtual_columns declarations" do
    it "collects VCs from predefined_filters virtual_columns" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => { "table_columns" => [ { "field" => "title" } ] },
        "search" => {
          "predefined_filters" => [
            { "name" => "critical", "scope" => "critical", "virtual_columns" => [ "items_count" ] }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("items_count")
    end

    it "scope-level VCs are included in show context too" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "show" => { "layout" => [ { "title" => "Info", "fields" => [ { "field" => "title" } ] } ] },
        "search" => {
          "predefined_filters" => [
            { "name" => "critical", "scope" => "critical", "virtual_columns" => [ "is_overdue" ] }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :show)
      expect(result).to include("is_overdue")
    end
  end

  describe "record_rules VC collection" do
    it "collects VCs from permission record_rules conditions" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => { "table_columns" => [ { "field" => "title" } ] }
      })

      perm_def = LcpRuby::Metadata::PermissionDefinition.from_hash(
        "model" => "order",
        "roles" => {
          "admin" => {
            "crud" => [ "read" ],
            "record_rules" => [
              { "deny" => [ "destroy" ], "when" => { "field" => "items_count", "operator" => "gt", "value" => 0 } }
            ]
          }
        }
      )
      LcpRuby.loader.permission_definitions["order"] = perm_def

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("items_count")
    end
  end

  describe "walk_condition_fields branches" do
    it "collects VCs from 'any' compound conditions" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "item_classes" => [
            {
              "css_class" => "warn",
              "when" => {
                "any" => [
                  { "field" => "is_overdue", "operator" => "eq", "value" => true },
                  { "field" => "items_count", "operator" => "eq", "value" => 0 }
                ]
              }
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("is_overdue", "items_count")
    end

    it "collects VCs from 'not' compound conditions" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "item_classes" => [
            {
              "css_class" => "warn",
              "when" => {
                "not" => { "field" => "is_overdue", "operator" => "eq", "value" => true }
              }
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("is_overdue")
    end

    it "collects VCs from dot-path fields (root extraction)" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "item_classes" => [
            {
              "css_class" => "warn",
              "when" => { "field" => "items_count.something", "operator" => "gt", "value" => 0 }
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("items_count")
    end

    it "collects VCs from collection conditions" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ],
          "item_classes" => [
            {
              "css_class" => "warn",
              "when" => {
                "collection" => "items",
                "quantifier" => "any",
                "condition" => { "field" => "is_overdue", "operator" => "eq", "value" => true }
              }
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :index)
      expect(result).to include("is_overdue")
    end
  end

  describe "edit context extended coverage" do
    it "collects VCs from section-level visible_when" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "form" => {
          "sections" => [
            {
              "title" => "Overdue Section",
              "visible_when" => { "field" => "is_overdue", "operator" => "eq", "value" => true },
              "fields" => [ { "field" => "title" } ]
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :edit)
      expect(result).to include("is_overdue")
    end

    it "collects VCs from field disable_when" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "form" => {
          "sections" => [
            {
              "title" => "Details",
              "fields" => [
                {
                  "field" => "title",
                  "disable_when" => { "field" => "items_count", "operator" => "gt", "value" => 0 }
                }
              ]
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :edit)
      expect(result).to include("items_count")
    end

    it "collects VCs from action disable_when" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "form" => { "sections" => [ { "title" => "Details", "fields" => [ { "field" => "title" } ] } ] },
        "actions" => {
          "single" => [
            {
              "name" => "approve",
              "type" => "custom",
              "disable_when" => { "field" => "is_overdue", "operator" => "eq", "value" => true }
            }
          ]
        }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model_def, context: :edit)
      expect(result).to include("is_overdue")
    end
  end

  describe "sort_field parameter" do
    it "includes VC when sort_field matches a virtual column name" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ]
        }
      })

      result = described_class.collect(
        presenter_def: presenter, model_def: model_def, context: :index, sort_field: "items_count"
      )
      expect(result).to include("items_count")
    end

    it "ignores sort_field that is not a virtual column" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ]
        }
      })

      result = described_class.collect(
        presenter_def: presenter, model_def: model_def, context: :index, sort_field: "title"
      )
      # title is a real field, not a VC — should only have auto_col
      expect(result).not_to include("title")
      expect(result).to include("auto_col") # auto_include still works
    end

    it "works with nil sort_field (default)" do
      presenter = make_presenter_def({
        "name" => "orders", "model" => "order", "slug" => "orders",
        "index" => {
          "table_columns" => [ { "field" => "title" } ]
        }
      })

      result = described_class.collect(
        presenter_def: presenter, model_def: model_def, context: :index, sort_field: nil
      )
      expect(result).not_to include("items_count")
    end
  end

  describe "returns empty set when no virtual columns defined" do
    it "returns empty when model has no VCs" do
      model = make_model_def({
        "name" => "plain",
        "fields" => [ { "name" => "title", "type" => "string" } ]
      })
      presenter = make_presenter_def({
        "name" => "plains", "model" => "plain", "slug" => "plains",
        "index" => { "table_columns" => [ { "field" => "title" } ] }
      })

      result = described_class.collect(presenter_def: presenter, model_def: model, context: :index)
      expect(result).to be_empty
    end
  end
end
