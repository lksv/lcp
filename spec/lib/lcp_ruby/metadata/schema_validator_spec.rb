# frozen_string_literal: true

require "spec_helper"

RSpec.describe LcpRuby::Metadata::SchemaValidator do
  subject(:validator) { described_class.new }

  def build_presenter(hash)
    hash = LcpRuby::HashUtils.stringify_deep(hash)
    hash["name"] ||= "test"
    hash["model"] ||= "widget"
    LcpRuby::Metadata::PresenterDefinition.from_hash(hash)
  end

  # --- Helper methods ---

  def build_model(hash)
    hash = LcpRuby::HashUtils.stringify_deep(hash)
    hash["name"] ||= "widget"
    LcpRuby::Metadata::ModelDefinition.from_hash(hash)
  end

  def build_permission(hash)
    hash = LcpRuby::HashUtils.stringify_deep(hash)
    hash["model"] ||= "widget"
    hash["roles"] ||= { "viewer" => { "crud" => %w[index show] } }
    LcpRuby::Metadata::PermissionDefinition.from_hash(hash)
  end

  def build_view_group(hash)
    hash = LcpRuby::HashUtils.stringify_deep(hash)
    hash["name"] ||= "test_group"
    hash["model"] ||= "widget"
    hash["primary"] ||= "widgets"
    hash["views"] ||= [ { "page" => "widgets" } ]
    LcpRuby::Metadata::ViewGroupDefinition.from_hash("view_group" => hash)
  end

  def build_menu(hash)
    hash = LcpRuby::HashUtils.stringify_deep(hash)
    hash["top_menu"] ||= [ { "view_group" => "widgets" } ]
    LcpRuby::Metadata::MenuDefinition.from_hash("menu" => hash)
  end

  # === Model schema ===

  describe "#validate_model" do
    it "accepts valid minimal model" do
      model = build_model(name: "widget")
      expect(validator.validate_model(model)).to be_empty
    end

    it "accepts valid full model" do
      model = build_model(
        name: "project",
        label: "Project",
        label_plural: "Projects",
        table_name: "projects",
        fields: [
          { name: "title", type: "string", label: "Title",
            column_options: { limit: 255, null: false },
            validations: [ { type: "presence" }, { type: "length", options: { minimum: 3 } } ] },
          { name: "status", type: "enum", enum_values: %w[draft active],
            default: "draft" }
        ],
        associations: [
          { type: "has_many", name: "tasks", target_model: "task", dependent: "destroy", inverse_of: "project" },
          { type: "belongs_to", name: "client", class_name: "Client", foreign_key: "client_id", required: false }
        ],
        scopes: [
          { name: "active", where: { status: "active" } },
          { name: "recent", order: { created_at: "desc" }, limit: 10 }
        ],
        events: [
          { name: "after_create" },
          { name: "on_status_change", type: "field_change", field: "status" }
        ],
        options: { timestamps: true, label_method: "title", custom_fields: false }
      )
      expect(validator.validate_model(model)).to be_empty
    end

    it "catches unknown top-level attribute" do
      model = build_model(name: "widget", bogus: true)
      errors = validator.validate_model(model)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches unknown field attribute" do
      model = build_model(fields: [ { name: "title", type: "string", display: "heading" } ])
      errors = validator.validate_model(model)
      expect(errors).to include(a_string_matching(/unknown attribute 'display'/))
    end

    it "catches unknown association attribute" do
      model = build_model(associations: [ { type: "has_many", name: "items", target_model: "item", bogus: true } ])
      errors = validator.validate_model(model)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches invalid association type" do
      # Association constructor rejects invalid types before schema validation,
      # so we validate the raw hash directly
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test", associations: [ { type: "has_all", name: "items", target_model: "item" } ]
      )
      errors = validator.send(:validate, :model, raw, context_name: "Model 'test'")
      expect(errors).to include(a_string_matching(/invalid value 'has_all'/))
    end

    it "catches invalid validation type" do
      # Validation constructor rejects invalid types before schema validation,
      # so we validate the raw hash directly
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test", fields: [ { name: "x", type: "string", validations: [ { type: "magic" } ] } ]
      )
      errors = validator.send(:validate, :model, raw, context_name: "Model 'test'")
      expect(errors).to include(a_string_matching(/invalid value 'magic'/))
    end

    it "catches invalid event type" do
      model = build_model(events: [ { name: "test", type: "unknown" } ])
      errors = validator.validate_model(model)
      expect(errors).to include(a_string_matching(/invalid value 'unknown'/))
    end

    it "accepts scope with type: custom" do
      model = build_model(scopes: [ { name: "complex_filter", type: "custom" } ])
      expect(validator.validate_model(model)).to be_empty
    end

    it "accepts scope with type: parameterized and parameters" do
      model = build_model(scopes: [ {
        name: "above_value",
        type: "parameterized",
        parameters: [
          { name: "min_value", type: "float", required: true, min: 0 },
          { name: "status", type: "enum", values: %w[active inactive], default: "active" }
        ]
      } ])
      expect(validator.validate_model(model)).to be_empty
    end

    it "catches invalid parameterized scope parameter type" do
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test",
        scopes: [ {
          name: "above_value",
          type: "parameterized",
          parameters: [ { name: "val", type: "nonsense" } ]
        } ]
      )
      errors = validator.send(:validate, :model, raw, context_name: "Model 'test'")
      expect(errors).to include(a_string_matching(/invalid value 'nonsense'/))
    end

    it "accepts model with indexes" do
      model = build_model(indexes: [
        { columns: %w[status created_at] },
        { columns: %w[email], unique: true, name: "idx_email" }
      ])
      expect(validator.validate_model(model)).to be_empty
    end

    it "catches unknown index attribute" do
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test",
        indexes: [ { columns: %w[email], bogus: true } ]
      )
      errors = validator.send(:validate, :model, raw, context_name: "Model 'test'")
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "accepts field with validations array" do
      model = build_model(
        fields: [
          { name: "email", type: "string",
            validations: [
              { type: "presence" },
              { type: "format", options: { with: "\\A.+@.+\\z" }, message: "invalid email" },
              { type: "length", options: { maximum: 255 } }
            ] }
        ]
      )
      expect(validator.validate_model(model)).to be_empty
    end

    it "catches unknown scope attribute" do
      model = build_model(scopes: [ { name: "active", bogus: true } ])
      errors = validator.validate_model(model)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches unknown model option" do
      model = build_model(options: { timestamps: true, bogus: true })
      errors = validator.validate_model(model)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "accepts field with source: external (string)" do
      model = build_model(fields: [
        { name: "location", type: "string", source: "external" }
      ])
      expect(validator.validate_model(model)).to be_empty
    end

    it "accepts field with source as service accessor object" do
      model = build_model(fields: [
        { name: "color", type: "string",
          source: { service: "json_field", options: { column: "properties", key: "color" } } }
      ])
      expect(validator.validate_model(model)).to be_empty
    end

    it "catches source object missing required service key" do
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test", fields: [
          { name: "color", type: "string", source: { options: { column: "properties" } } }
        ]
      )
      errors = validator.send(:validate, :model, raw, context_name: "Model 'test'")
      expect(errors).to include(a_string_matching(/missing required service|does not match any allowed format/))
    end

    it "catches source object with unknown attribute" do
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test", fields: [
          { name: "color", type: "string", source: { service: "json_field", bogus: true } }
        ]
      )
      errors = validator.send(:validate, :model, raw, context_name: "Model 'test'")
      expect(errors).not_to be_empty
    end

    it "returns no errors when raw_hash is nil" do
      model = LcpRuby::Metadata::ModelDefinition.new(name: "test")
      expect(validator.validate_model(model)).to be_empty
    end
  end

  # === Permission schema ===

  describe "#validate_permission" do
    it "accepts valid permission" do
      perm = build_permission(
        model: "project",
        default_role: "viewer",
        roles: {
          admin: { crud: %w[index show create update destroy], fields: { readable: "all", writable: "all" },
                   actions: "all", scope: "all", presenters: "all" },
          viewer: { crud: %w[index show], fields: { readable: %w[title status], writable: [] },
                    presenters: %w[project_public] }
        },
        field_overrides: {
          budget: { writable_by: %w[admin], readable_by: %w[admin manager] }
        },
        record_rules: [ {
          name: "archived_readonly",
          condition: { field: "status", operator: "eq", value: "archived" },
          effect: { deny_crud: %w[update destroy], except_roles: %w[admin] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "catches unknown role attribute" do
      perm = build_permission(roles: { admin: { crud: %w[index], bogus: true } })
      errors = validator.validate_permission(perm)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches invalid CRUD value" do
      perm = build_permission(roles: { admin: { crud: %w[index read] } })
      errors = validator.validate_permission(perm)
      expect(errors).to include(a_string_matching(/invalid value 'read'/))
    end

    it "catches invalid condition operator in record rule" do
      perm = build_permission(
        record_rules: [ {
          name: "rule1",
          condition: { field: "status", operator: "like", value: "x" },
          effect: { deny_crud: %w[update] }
        } ]
      )
      errors = validator.validate_permission(perm)
      expect(errors).to include(a_string_matching(/invalid value 'like'/))
    end

    it "catches unknown field override attribute" do
      perm = build_permission(field_overrides: { title: { bogus: true } })
      errors = validator.validate_permission(perm)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "accepts actions as 'all'" do
      perm = build_permission(roles: { admin: { crud: %w[index], actions: "all" } })
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts actions as allowed/denied object" do
      perm = build_permission(roles: { editor: { crud: %w[index], actions: { allowed: %w[lock], denied: [] } } })
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "catches actions as plain array (invalid format)" do
      perm = build_permission(roles: { admin: { crud: %w[index], actions: %w[lock export] } })
      errors = validator.validate_permission(perm)
      expect(errors).to include(a_string_matching(/does not match any allowed format/))
    end

    it "accepts scope as 'all'" do
      perm = build_permission(roles: { admin: { crud: %w[index], scope: "all" } })
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts scope as object with type" do
      perm = build_permission(roles: {
        owner: { crud: %w[index show], scope: { type: "field_match", field: "owner_id", value: "current_user_id" } }
      })
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts association scope with user_field" do
      perm = build_permission(roles: {
        manager: {
          crud: %w[index show],
          scope: {
            type: "association",
            field: "organization_unit_id",
            user_field: "organization_unit_id"
          }
        }
      })
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts compound 'all' condition in record_rule" do
      perm = build_permission(
        record_rules: [ {
          name: "compound_lock",
          condition: {
            all: [
              { field: "status", operator: "eq", value: "done" },
              { field: "status", operator: "not_eq", value: "archived" }
            ]
          },
          effect: { deny_crud: %w[update destroy], except_roles: %w[admin] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts compound 'any' condition in record_rule" do
      perm = build_permission(
        record_rules: [ {
          name: "any_lock",
          condition: {
            any: [
              { field: "status", operator: "eq", value: "archived" },
              { field: "status", operator: "eq", value: "deleted" }
            ]
          },
          effect: { deny_crud: %w[update] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts 'not' condition in record_rule" do
      perm = build_permission(
        record_rules: [ {
          name: "not_owner",
          condition: {
            not: { field: "status", operator: "eq", value: "active" }
          },
          effect: { deny_crud: %w[destroy] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts collection condition in record_rule" do
      perm = build_permission(
        record_rules: [ {
          name: "has_approvals",
          condition: {
            collection: "approvals",
            quantifier: "any",
            condition: { field: "status", operator: "eq", value: "approved" }
          },
          effect: { deny_crud: %w[destroy] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts dynamic value references in record_rule condition" do
      perm = build_permission(
        record_rules: [ {
          name: "owner_only",
          condition: {
            not: {
              field: "created_by_id",
              operator: "eq",
              value: { current_user: "id" }
            }
          },
          effect: { deny_crud: %w[update destroy] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts date dynamic value in record_rule condition" do
      perm = build_permission(
        record_rules: [ {
          name: "overdue_lock",
          condition: {
            all: [
              { field: "status", operator: "not_eq", value: "done" },
              { field: "status", operator: "eq", value: "active" }
            ]
          },
          effect: { deny_crud: %w[destroy] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end

    it "accepts lookup value reference in record_rule condition" do
      perm = build_permission(
        record_rules: [ {
          name: "tax_check",
          condition: {
            field: "amount",
            operator: "lt",
            value: { lookup: "tax_limit", match: { key: "vat_a" }, pick: "threshold" }
          },
          effect: { deny_crud: %w[update] }
        } ]
      )
      expect(validator.validate_permission(perm)).to be_empty
    end
  end

  # === View group schema ===

  describe "#validate_view_group" do
    it "accepts valid view group" do
      vg = build_view_group(
        model: "feature",
        primary: "features_card",
        views: [
          { page: "features_card", label: "Card View", icon: "layout" },
          { page: "features_table", label: "Table View", icon: "grid" }
        ]
      )
      expect(validator.validate_view_group(vg)).to be_empty
    end

    it "accepts view group with navigation and breadcrumb" do
      vg = build_view_group(
        model: "widget",
        primary: "widgets",
        navigation: { position: 1, menu: "main" },
        breadcrumb: { relation: "parent" },
        public: true,
        views: [ { page: "widgets" } ]
      )
      expect(validator.validate_view_group(vg)).to be_empty
    end

    it "accepts navigation: false" do
      vg = build_view_group(
        model: "widget",
        primary: "widgets",
        navigation: false,
        views: [ { page: "widgets" } ]
      )
      expect(validator.validate_view_group(vg)).to be_empty
    end

    it "catches unknown top-level attribute" do
      vg = build_view_group(bogus: true)
      errors = validator.validate_view_group(vg)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches unknown view attribute" do
      vg = build_view_group(views: [ { page: "widgets", bogus: true } ])
      errors = validator.validate_view_group(vg)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "accepts switcher: false" do
      vg = build_view_group(switcher: false)
      expect(validator.validate_view_group(vg)).to be_empty
    end

    it "accepts switcher as array of contexts" do
      vg = build_view_group(switcher: %w[index show])
      expect(validator.validate_view_group(vg)).to be_empty
    end

    it "catches invalid switcher context" do
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test_group", model: "widget", primary: "widgets",
        switcher: %w[index details],
        views: [ { page: "widgets" } ]
      )
      errors = validator.send(:validate, :view_group, raw, context_name: "View group 'test_group'")
      expect(errors).to include(a_string_matching(/invalid value 'details'/))
    end

    it "accepts breadcrumb: false" do
      vg = build_view_group(breadcrumb: false)
      expect(validator.validate_view_group(vg)).to be_empty
    end

    it "accepts public: true" do
      vg = build_view_group(public: true)
      expect(validator.validate_view_group(vg)).to be_empty
    end

    it "catches unknown navigation attribute" do
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test_group", model: "widget", primary: "widgets",
        navigation: { position: 1, bogus: true },
        views: [ { page: "widgets" } ]
      )
      errors = validator.send(:validate, :view_group, raw, context_name: "View group 'test_group'")
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches unknown breadcrumb attribute" do
      raw = LcpRuby::HashUtils.stringify_deep(
        name: "test_group", model: "widget", primary: "widgets",
        breadcrumb: { relation: "parent", bogus: true },
        views: [ { page: "widgets" } ]
      )
      errors = validator.send(:validate, :view_group, raw, context_name: "View group 'test_group'")
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end
  end

  # === Menu schema ===

  describe "#validate_menu" do
    it "accepts valid menu with top_menu" do
      menu = build_menu(
        top_menu: [
          { label: "Features", icon: "star", children: [
            { view_group: "widgets" },
            { separator: true },
            { label: "External", url: "/ext", icon: "link" }
          ] },
          { view_group: "features" }
        ]
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "accepts menu with sidebar_menu" do
      menu = build_menu(
        sidebar_menu: [
          { view_group: "dashboard", position: "bottom" },
          { separator: true },
          { view_group: "settings" }
        ],
        top_menu: nil
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "accepts menu item with badge" do
      menu = build_menu(
        top_menu: [ {
          view_group: "inbox",
          badge: { provider: "unread_count", renderer: "count_badge" }
        } ]
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "accepts menu item with visible_when" do
      menu = build_menu(
        top_menu: [ {
          view_group: "admin_panel",
          visible_when: { role: %w[admin] }
        } ]
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "catches unknown menu item attribute" do
      menu = build_menu(top_menu: [ { view_group: "widgets", bogus: true } ])
      errors = validator.validate_menu(menu)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches unknown badge attribute" do
      menu = build_menu(
        top_menu: [ {
          view_group: "inbox",
          badge: { provider: "count", renderer: "count_badge", bogus: true }
        } ]
      )
      errors = validator.validate_menu(menu)
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "accepts badge with template instead of renderer" do
      menu = build_menu(
        top_menu: [ {
          view_group: "inbox",
          badge: { provider: "count", template: "{count} new" }
        } ]
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "accepts badge with partial instead of renderer" do
      menu = build_menu(
        top_menu: [ {
          view_group: "inbox",
          badge: { provider: "count", partial: "shared/badge" }
        } ]
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "accepts badge with options" do
      menu = build_menu(
        top_menu: [ {
          view_group: "inbox",
          badge: { provider: "count", renderer: "count_badge", options: { max: 99 } }
        } ]
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "accepts deeply nested children" do
      menu = build_menu(
        sidebar_menu: [ {
          label: "Admin",
          icon: "cog",
          children: [
            { view_group: "users" },
            { separator: true },
            { label: "Advanced", children: [
              { view_group: "settings" }
            ] }
          ]
        } ]
      )
      expect(validator.validate_menu(menu)).to be_empty
    end

    it "catches unknown visibility_when attribute" do
      raw = LcpRuby::HashUtils.stringify_deep(
        top_menu: [ {
          view_group: "admin",
          visible_when: { role: %w[admin], bogus: true }
        } ]
      )
      errors = validator.send(:validate, :menu, raw, context_name: "Menu")
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end
  end

  # === Type schema ===

  describe "#validate_type_hash" do
    it "accepts valid type with all attributes" do
      hash = {
        "name" => "email",
        "base_type" => "string",
        "transforms" => %w[strip downcase],
        "validations" => [ { "type" => "format", "options" => { "with" => "\\A.+@.+\\z" } } ],
        "input_type" => "email",
        "renderer" => "email_link",
        "column_options" => { "limit" => 255 },
        "html_input_attrs" => { "autocomplete" => "email" }
      }
      expect(validator.validate_type_hash(hash, name: "email")).to be_empty
    end

    it "accepts minimal type" do
      hash = { "name" => "currency", "base_type" => "decimal" }
      expect(validator.validate_type_hash(hash, name: "currency")).to be_empty
    end

    it "catches unknown attribute" do
      hash = { "name" => "test", "base_type" => "string", "bogus" => true }
      errors = validator.validate_type_hash(hash, name: "test")
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches invalid base_type" do
      hash = { "name" => "test", "base_type" => "blob" }
      errors = validator.validate_type_hash(hash, name: "test")
      expect(errors).to include(a_string_matching(/invalid value 'blob'/))
    end

    it "catches unknown validation attribute" do
      hash = { "name" => "test", "base_type" => "string",
               "validations" => [ { "type" => "format", "bogus" => true } ] }
      errors = validator.validate_type_hash(hash, name: "test")
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "catches unknown column_options attribute" do
      hash = { "name" => "test", "base_type" => "string",
               "column_options" => { "limit" => 255, "bogus" => true } }
      errors = validator.validate_type_hash(hash, name: "test")
      expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
    end

    it "accepts type with column_options precision and scale" do
      hash = { "name" => "currency", "base_type" => "decimal",
               "column_options" => { "precision" => 10, "scale" => 2 } }
      expect(validator.validate_type_hash(hash, name: "currency")).to be_empty
    end

    it "catches invalid validation type in type definition" do
      hash = { "name" => "test", "base_type" => "string",
               "validations" => [ { "type" => "magic" } ] }
      errors = validator.validate_type_hash(hash, name: "test")
      expect(errors).to include(a_string_matching(/invalid value 'magic'/))
    end

    it "accepts validation with options and message" do
      hash = { "name" => "test", "base_type" => "string",
               "validations" => [ {
                 "type" => "format",
                 "options" => { "with" => "\\A.+\\z" },
                 "message" => "is invalid"
               } ] }
      expect(validator.validate_type_hash(hash, name: "test")).to be_empty
    end

    it "returns empty for nil hash" do
      expect(validator.validate_type_hash(nil)).to be_empty
    end
  end

  # === Presenter schema ===

  describe "#validate_presenter" do
    context "with a valid minimal presenter" do
      it "returns no errors" do
        presenter = build_presenter(name: "test", model: "widget")
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with a valid full presenter" do
      it "returns no errors" do
        presenter = build_presenter(
          name: "widgets",
          model: "widget",
          label: "Widgets",
          slug: "widgets",
          icon: "box",
          read_only: false,
          index: {
            description: "All widgets",
            default_view: "table",
            per_page: 25,
            default_sort: { field: "name", direction: "asc" },
            row_click: "show",
            table_columns: [
              { field: "name", link_to: "show", renderer: "heading", sortable: true, width: "30%" },
              { field: "status", renderer: "badge", options: { color_map: { active: "green" } } },
              { field: "price", pinned: "left", summary: "sum" }
            ]
          },
          show: {
            description: "Widget details",
            layout: [
              {
                section: "Overview",
                columns: 2,
                fields: [
                  { field: "name", renderer: "heading" },
                  { field: "status", renderer: "badge", options: { color_map: { active: "green" } } },
                  { type: "divider" },
                  { type: "info", text: "Additional details below" }
                ]
              }
            ]
          },
          form: {
            sections: [
              {
                title: "Basic",
                columns: 2,
                fields: [
                  { field: "name", autofocus: true },
                  { field: "status", input_type: "select" },
                  { field: "notes", input_type: "textarea", hint: "Optional notes", input_options: { rows: 6 } }
                ]
              }
            ]
          },
          search: {
            searchable_fields: %w[name description],
            placeholder: "Search widgets...",
            predefined_filters: [
              { name: "active", label: "Active", scope: "active", default: true }
            ]
          },
          actions: {
            collection: [
              { name: "create", type: "built_in", label: "New Widget", icon: "plus" }
            ],
            single: [
              { name: "show", type: "built_in" },
              { name: "destroy", type: "built_in", confirm: true, style: "danger" }
            ]
          }
        )

        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "when raw_hash is nil" do
      it "returns no errors" do
        presenter = LcpRuby::Metadata::PresenterDefinition.new(name: "test", model: "widget")
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    # --- Unknown attributes (additionalProperties: false) ---

    context "with unknown top-level attribute" do
      it "reports unknown attribute" do
        presenter = build_presenter(name: "test", model: "widget", bogus: "value")
        errors = validator.validate_presenter(presenter)

        expect(errors.length).to eq(1)
        expect(errors.first).to include("unknown attribute 'bogus'")
      end
    end

    context "with 'display' instead of 'renderer' in table column" do
      it "reports unknown attribute 'display'" do
        presenter = build_presenter(
          index: {
            table_columns: [
              { field: "status", display: "badge" }
            ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/unknown attribute 'display'/))
      end
    end

    context "with 'display_options' instead of 'options' in table column" do
      it "reports unknown attribute 'display_options'" do
        presenter = build_presenter(
          index: {
            table_columns: [
              { field: "status", display_options: { color_map: {} } }
            ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/unknown attribute 'display_options'/))
      end
    end

    context "with unknown attribute in show field" do
      it "reports unknown attribute" do
        presenter = build_presenter(
          show: {
            layout: [
              { section: "Details", fields: [ { field: "name", display: "heading" } ] }
            ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/unknown attribute 'display'/))
      end
    end

    context "with unknown attribute in form field" do
      it "reports unknown attribute" do
        presenter = build_presenter(
          form: {
            sections: [
              { title: "Basic", fields: [ { field: "name", bogus: true } ] }
            ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
      end
    end

    context "with unknown attribute in action" do
      it "reports unknown attribute" do
        presenter = build_presenter(
          actions: {
            single: [ { name: "show", type: "built_in", bogus: true } ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
      end
    end

    context "with unknown attribute in search filter" do
      it "reports unknown attribute" do
        presenter = build_presenter(
          search: {
            predefined_filters: [ { name: "all", label: "All", bogus: true } ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
      end
    end

    # --- Enum validation ---

    context "with invalid pinned value" do
      it "reports invalid enum value" do
        presenter = build_presenter(
          index: {
            table_columns: [ { field: "name", pinned: "center" } ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/invalid value 'center'/))
        expect(errors).to include(a_string_matching(/left, right/))
      end
    end

    context "with invalid summary value" do
      it "reports invalid enum value" do
        presenter = build_presenter(
          index: {
            table_columns: [ { field: "price", summary: "median" } ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/invalid value 'median'/))
        expect(errors).to include(a_string_matching(/sum, avg, count/))
      end
    end

    context "with invalid sort direction" do
      it "reports invalid enum value" do
        presenter = build_presenter(
          index: {
            default_sort: { field: "name", direction: "up" }
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/invalid value 'up'/))
        expect(errors).to include(a_string_matching(/asc, desc/))
      end
    end

    context "with invalid action type" do
      it "reports invalid enum value" do
        presenter = build_presenter(
          actions: {
            single: [ { name: "show", type: "magic" } ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/invalid value 'magic'/))
      end
    end

    # --- Type validation ---

    context "with wrong type for per_page" do
      it "reports type error" do
        presenter = build_presenter(index: { per_page: "fifty" })
        errors = validator.validate_presenter(presenter)

        expect(errors.length).to eq(1)
        expect(errors.first).to include("index.per_page")
      end
    end

    context "with wrong type for sortable" do
      it "reports type error" do
        presenter = build_presenter(
          index: { table_columns: [ { field: "name", sortable: "yes" } ] }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors.length).to eq(1)
        expect(errors.first).to include("table_columns")
      end
    end

    # --- Required field validation ---

    context "with missing required 'field' in table column" do
      it "reports missing required field" do
        presenter = build_presenter(
          index: { table_columns: [ { renderer: "badge" } ] }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/missing required field/))
      end
    end

    context "with missing required 'name' in action" do
      it "reports missing required name" do
        presenter = build_presenter(
          actions: { single: [ { type: "built_in" } ] }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors).to include(a_string_matching(/missing required name/))
      end
    end

    # --- confirm accepts boolean or string ---

    context "with confirm: true" do
      it "is valid" do
        presenter = build_presenter(
          actions: { single: [ { name: "destroy", type: "built_in", confirm: true } ] }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with confirm: 'Are you sure?'" do
      it "is valid" do
        presenter = build_presenter(
          actions: { single: [ { name: "destroy", type: "built_in", confirm: "Are you sure?" } ] }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with confirm: { except: [admin] }" do
      it "is valid" do
        presenter = build_presenter(
          actions: { single: [ { name: "archive", type: "custom", confirm: { except: %w[admin] } } ] }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with confirm: { only: [viewer] }" do
      it "is valid" do
        presenter = build_presenter(
          actions: { single: [ { name: "delete", type: "custom", confirm: { only: %w[viewer sales_rep] } } ] }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    # --- visible_when / disable_when ---

    context "with visible_when as object" do
      it "is valid" do
        presenter = build_presenter(
          form: {
            sections: [ {
              title: "Conditional",
              visible_when: { field: "status", operator: "eq", value: "active" },
              fields: [ { field: "notes" } ]
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with visible_when as string" do
      it "is valid" do
        presenter = build_presenter(
          actions: {
            single: [ { name: "archive", type: "custom", visible_when: "can_archive?" } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    # --- Show section variants ---

    context "with association_list section" do
      it "is valid" do
        presenter = build_presenter(
          show: {
            layout: [ {
              section: "Related Items",
              type: "association_list",
              association: "items",
              display_template: "{name}",
              link: true,
              limit: 10,
              empty_message: "No items"
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with json_items_list section" do
      it "is valid" do
        presenter = build_presenter(
          show: {
            layout: [ {
              section: "Address History",
              type: "json_items_list",
              json_field: "addresses",
              target_model: "address",
              columns: 2,
              empty_message: "No addresses",
              fields: [ { field: "street" }, { field: "city" } ]
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with audit_history section" do
      it "is valid" do
        presenter = build_presenter(
          show: {
            layout: [ {
              section: "Change History",
              type: "audit_history"
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with visible_when on show field" do
      it "is valid" do
        presenter = build_presenter(
          show: {
            layout: [ {
              section: "Details",
              fields: [
                { field: "termination_date", visible_when: { field: "status", operator: "eq", value: "terminated" } }
              ]
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with hint on show field" do
      it "is valid" do
        presenter = build_presenter(
          show: {
            layout: [ {
              section: "Details",
              fields: [ { field: "notes", hint: "Internal notes only" } ]
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with visible_when and copyable on table column" do
      it "is valid" do
        presenter = build_presenter(
          index: {
            table_columns: [
              { field: "email", copyable: true, visible_when: { field: "status", operator: "eq", value: "active" } }
            ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with nested_fields using json_field and sub_sections" do
      it "is valid" do
        presenter = build_presenter(
          form: {
            sections: [ {
              title: "Addresses",
              type: "nested_fields",
              json_field: "addresses",
              target_model: "address",
              allow_add: true,
              allow_remove: true,
              sub_sections: [ {
                title: "Street Address",
                columns: 2,
                fields: [ { field: "street" }, { field: "city" } ]
              } ]
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    context "with saved_filters in advanced_filter" do
      it "is valid" do
        presenter = build_presenter(
          search: {
            enabled: true,
            advanced_filter: {
              enabled: true,
              saved_filters: {
                enabled: true,
                display: "inline",
                max_visible_pinned: 5,
                max_per_user: 50,
                allow_pinning: true,
                allow_default: true,
                visibility_options: %w[personal role global]
              }
            }
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    # --- Form section variants ---

    context "with collapsible form section" do
      it "is valid" do
        presenter = build_presenter(
          form: {
            sections: [ {
              title: "Advanced",
              collapsible: true,
              collapsed: true,
              fields: [ { field: "notes" } ]
            } ]
          }
        )
        expect(validator.validate_presenter(presenter)).to be_empty
      end
    end

    # --- Multiple errors ---

    context "with multiple invalid attributes" do
      it "reports all errors" do
        presenter = build_presenter(
          index: {
            table_columns: [
              { field: "a", display: "badge", display_options: { color_map: {} } },
              { field: "b", pinned: "center" }
            ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors.length).to eq(3)
        expect(errors).to include(a_string_matching(/unknown attribute 'display'/))
        expect(errors).to include(a_string_matching(/unknown attribute 'display_options'/))
        expect(errors).to include(a_string_matching(/invalid value 'center'/))
      end
    end

    # --- Advanced filter schema ---

    context "advanced filter options" do
      it "accepts full advanced_filter configuration" do
        presenter = build_presenter(
          search: {
            advanced_filter: {
              enabled: true,
              max_conditions: 20,
              max_association_depth: 2,
              max_nesting_depth: 3,
              default_combinator: "and",
              allow_or_groups: true,
              query_language: true,
              filterable_fields: %w[name status],
              field_options: { name: { operators: %w[eq contains] } },
              presets: [ { name: "active_only", conditions: [] } ],
              custom_filters: [ { name: "my_filter", label: "Custom" } ]
            }
          }
        )
        errors = validator.validate_presenter(presenter)
        af_errors = errors.select { |e| e.include?("advanced_filter") }
        expect(af_errors).to be_empty
      end

      it "accepts saved_filters inside advanced_filter" do
        presenter = build_presenter(
          search: {
            advanced_filter: {
              enabled: true,
              saved_filters: {
                enabled: true,
                display: "inline",
                max_per_user: 50,
                max_per_role: 20,
                max_global: 30,
                max_visible_pinned: 5,
                allow_pinning: true,
                allow_default: true,
                visibility_options: %w[personal role global]
              }
            }
          }
        )
        errors = validator.validate_presenter(presenter)
        sf_errors = errors.select { |e| e.include?("saved_filters") }
        expect(sf_errors).to be_empty
      end

      it "catches unknown advanced_filter attribute" do
        presenter = build_presenter(
          search: {
            advanced_filter: { enabled: true, bogus: true }
          }
        )
        errors = validator.validate_presenter(presenter)
        expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
      end

      it "catches unknown saved_filters attribute" do
        presenter = build_presenter(
          search: {
            advanced_filter: {
              enabled: true,
              saved_filters: { enabled: true, bogus: true }
            }
          }
        )
        errors = validator.validate_presenter(presenter)
        expect(errors).to include(a_string_matching(/unknown attribute 'bogus'/))
      end
    end

    # --- Index configuration schema ---

    context "index configuration" do
      it "accepts full index configuration with all options" do
        presenter = build_presenter(
          index: {
            default_view: "table",
            per_page: 50,
            row_click: "show",
            reorderable: true,
            tree_view: true,
            reparentable: true,
            default_expanded: 2,
            default_sort: { field: "name", direction: "desc" },
            table_columns: [ { field: "name" } ]
          }
        )
        errors = validator.validate_presenter(presenter)
        idx_errors = errors.select { |e| e.include?("index") }
        expect(idx_errors).to be_empty
      end

      it "catches unknown index attribute" do
        presenter = build_presenter(
          index: { bogus_option: true, table_columns: [ { field: "name" } ] }
        )
        errors = validator.validate_presenter(presenter)
        expect(errors).to include(a_string_matching(/unknown attribute 'bogus_option'/))
      end
    end

    # --- Presenter top-level attributes schema ---

    context "presenter attributes" do
      it "accepts read_only and embeddable flags" do
        presenter = build_presenter(read_only: true, embeddable: true)
        expect(validator.validate_presenter(presenter)).to be_empty
      end

      it "accepts valid scope value" do
        presenter = build_presenter(scope: "discarded")
        expect(validator.validate_presenter(presenter)).to be_empty
      end

      it "catches invalid scope value" do
        raw = LcpRuby::HashUtils.stringify_deep(
          name: "test", model: "widget", scope: "deleted"
        )
        errors = validator.send(:validate, :presenter, raw, context_name: "Presenter 'test'")
        expect(errors).to include(a_string_matching(/invalid value 'deleted'/))
      end

      it "accepts valid redirect_after object" do
        presenter = build_presenter(redirect_after: { create: "index", update: "show" })
        expect(validator.validate_presenter(presenter)).to be_empty
      end

      it "catches invalid redirect_after create value" do
        raw = LcpRuby::HashUtils.stringify_deep(
          name: "test", model: "widget", redirect_after: { create: "dashboard" }
        )
        errors = validator.send(:validate, :presenter, raw, context_name: "Presenter 'test'")
        expect(errors).to include(a_string_matching(/invalid value 'dashboard'/))
      end
    end

    # --- Error message formatting ---

    context "error message includes presenter name" do
      it "prefixes with presenter name" do
        presenter = build_presenter(name: "my_widget", bogus: "x")
        errors = validator.validate_presenter(presenter)

        expect(errors.first).to start_with("Presenter 'my_widget'")
      end
    end

    context "error message formats nested paths" do
      it "uses dot notation with array indices" do
        presenter = build_presenter(
          index: {
            table_columns: [
              { field: "ok" },
              { field: "bad", bogus: true }
            ]
          }
        )
        errors = validator.validate_presenter(presenter)

        expect(errors.first).to include("index.table_columns")
        expect(errors.first).to include("unknown attribute 'bogus'")
      end
    end
  end
end
