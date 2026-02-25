# Custom Fields Guide

Custom fields let users define additional fields on models at runtime — no code changes, no migrations, no server restarts. This is useful for systems where end-users or administrators need to extend the data model to fit their specific needs.

## When to Use Custom Fields

Custom fields are a good fit when:
- End-users need to add domain-specific fields (e.g., a CRM where each company tracks different metadata)
- The set of fields varies per deployment or tenant
- You want to avoid creating a new migration for every client-specific field

Custom fields are **not** a replacement for regular model fields. Use regular fields for core domain attributes that are shared across all deployments.

## Quick Start

### Step 1: Generate custom field definition metadata

Run the generator to create the `custom_field_definition` model, presenter, permissions, and view group:

```bash
rails generate lcp_ruby:custom_fields
```

This creates:
- `config/lcp_ruby/models/custom_field_definition.rb` — model definition (DSL format)
- `config/lcp_ruby/presenters/custom_fields.rb` — presenter definition (DSL format)
- `config/lcp_ruby/permissions/custom_field_definition.yml` — permissions
- `config/lcp_ruby/views/custom_fields.rb` — view group (DSL format)

For YAML format instead of DSL, use `--format=yaml`.

### Step 2: Enable custom fields on a model

```yaml
# config/lcp_ruby/models/project.yml
model:
  name: project
  options:
    custom_fields: true
  fields:
    - name: name
      type: string
      validations:
        - type: presence
    - name: status
      type: string
      default: active
```

Or with the Ruby DSL:

```ruby
# config/lcp_ruby/models/project.rb
define_model :project do
  custom_fields true
  field :name, :string, validations: [{ type: :presence }]
  field :status, :string, default: "active"
end
```

### Step 3: Set up permissions

The `custom_data` virtual field controls access to all custom fields. Include it in `readable` and `writable` field lists:

```yaml
# config/lcp_ruby/permissions/project.yml
permissions:
  model: project
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields:
        readable: all    # 'all' automatically includes custom_data
        writable: all
    viewer:
      crud: [index, show]
      fields:
        readable: all
        writable: []
```

### Step 4: Customize permissions for custom field definitions (optional)

The generator already created a permissions file for the `custom_field_definition` model. You can customize it:

```yaml
# config/lcp_ruby/permissions/custom_field_definition.yml
permissions:
  model: custom_field_definition
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all
      presenters: all
    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      actions: { allowed: [] }
      scope: all
      presenters: all
  default_role: viewer
```

### Step 5: Boot the app and create field definitions

After starting the application, navigate to `/projects/custom-fields` (the nested custom fields management route). Create a new custom field definition:

- **Field name**: `website` (lowercase, no spaces)
- **Type**: `string`
- **Label**: `Website URL`
- **Section**: `Contact Info` (custom fields are grouped by section)

The `target_model` is automatically set from the parent URL context (e.g., `/projects/custom-fields` sets it to `project`).

### Manage Page (Bulk Editing)

For editing all custom field definitions at once, use the **Manage All** page at `/:lcp_slug/custom-fields/manage`. This page renders all definitions in a bulk form with add/remove/reorder support.

The manage page UI is fully **presenter-driven** — it reads the `custom_fields` presenter definition to determine which fields, sections, and conditions to render. There is no hardcoded field HTML. To customize what appears on the manage page, modify the `custom_fields` presenter:

```ruby
# config/lcp_ruby/presenters/custom_fields.rb
define_presenter :custom_fields do
  model :custom_field_definition
  # ...

  form do
    section "General", columns: 3 do
      field :field_name, readonly: true
      field :custom_type
      field :label
      field :section
      field :position
      field :active
    end

    # This section only appears when custom_type is string or text
    section "Text Constraints", columns: 2,
      visible_when: { field: :custom_type, operator: :in, value: "string,text" } do
        field :min_length
        field :max_length
        field :default_value
        field :placeholder
    end

    # This section only appears when custom_type is a numeric type
    section "Numeric Constraints", columns: 2,
      visible_when: { field: :custom_type, operator: :in, value: "integer,float,decimal" } do
        field :min_value
        field :max_value
        field :precision,
          visible_when: { field: :custom_type, operator: :eq, value: "decimal" }
    end

    section "Enum Values",
      visible_when: { field: :custom_type, operator: :eq, value: "enum" } do
        field :enum_values
    end
  end
end
```

The manage page uses [row-scoped conditional rendering](conditional-rendering.md#row-scoped-conditions-in-nested-fields) — each row evaluates `visible_when` conditions independently against its own data. Changing `custom_type` in one row only affects that row's visible sections.

### Step 6: Use the custom fields

Navigate to `/projects/new`. A new "Contact Info" section appears at the bottom of the form with the "Website URL" field. Fill it in, save, and the value persists.

## Working with Sections

Custom fields are grouped into sections by their `section` attribute. All fields sharing the same section value appear under the same heading.

```
Section: "Contact Info"     →  renders as <h2>Contact Info</h2>
  - website (string)
  - phone_number (string)

Section: "Custom Fields"    →  renders as <h2>Custom Fields</h2>  (default)
  - priority (integer)
  - internal_notes (text)
```

Use the `position` attribute to control ordering within a section. Lower numbers appear first.

## Field Types

Each custom field has a `custom_type` that determines its behavior:

| Type | Form Input | Validation Support |
|------|-----------|-------------------|
| `string` | Text field | `min_length`, `max_length`, `required` |
| `text` | Textarea | `min_length`, `max_length`, `required` |
| `integer` | Number field | `min_value`, `max_value`, `required` |
| `float` | Number field | `min_value`, `max_value`, `required` |
| `decimal` | Number field | `min_value`, `max_value`, `precision`, `required` |
| `boolean` | Checkbox | `required` |
| `date` | Date picker | `required` |
| `datetime` | Datetime picker | `required` |
| `enum` | Select dropdown | `enum_values` (required), `required` |

## Enum Fields

When defining an enum custom field, provide the `enum_values` attribute as a JSON array:

```json
["low", "medium", "high"]
```

Or with custom labels:

```json
[
  { "value": "low", "label": "Low Priority" },
  { "value": "medium", "label": "Medium Priority" },
  { "value": "high", "label": "High Priority" }
]
```

Validation ensures only allowed values are accepted.

## Enabling Search

Set `searchable: true` on a custom field definition to include it in the index page's text search. When a user types in the search box, custom searchable fields are searched alongside regular searchable fields.

> **Note:** Search on custom fields uses JSON extraction functions, which may be slower than searching regular indexed columns on large datasets. Use `searchable: true` selectively.

## Table Column Visibility

By default, custom fields do not appear in the index table. Set `show_in_table: true` to add them as table columns. You can also control:

- `sortable: true` — allows clicking the column header to sort
- `column_width: "150px"` — sets a CSS width for the column

## Programmatic Access

Custom field values can be read and written in Ruby code:

```ruby
model = LcpRuby.registry.model_for("project")
record = model.find(1)

# Using dynamic accessors (after definitions are loaded)
record.website                      # => "https://example.com"
record.website = "https://new.com"
record.save!

# Using the generic low-level API
record.read_custom_field("website")
record.write_custom_field("website", "https://new.com")
record.save!
```

### Creating Definitions Programmatically

```ruby
cfd = LcpRuby.registry.model_for("custom_field_definition")

cfd.create!(
  target_model: "project",
  field_name: "budget",
  custom_type: "decimal",
  label: "Budget",
  section: "Financials",
  required: false,
  min_value: 0,
  precision: 2,
  show_in_table: true,
  sortable: true
)
```

After creating a definition, the `after_commit` callback automatically refreshes the accessor cache on the target model. No restart needed.

## Default Values

Custom fields support default values. When a definition has `default_value` set, new records automatically receive that value:

```ruby
cfd.create!(
  target_model: "project",
  field_name: "status_cf",
  custom_type: "string",
  label: "Status",
  default_value: "active"
)

record = project_model.new(name: "New Project")
record.status_cf  # => "active"  (applied automatically)

record.status_cf = "draft"
record.status_cf  # => "draft"  (explicit value wins)
```

Defaults are applied via `after_initialize` only for `new_record?` — existing records loaded from the database are never modified.

## Deleting Custom Field Definitions

When a custom field definition is deleted:
1. The cached definitions are cleared for the affected model
2. Dynamic accessors (getter/setter methods) for the deleted field are **removed** from the model class
3. The field value in `custom_data` JSON is preserved (data is not deleted)
4. The field no longer appears in forms, show views, or table columns

This means `record.respond_to?(:deleted_field)` returns `false` after deletion and re-apply.

## Permission Model

Custom fields support both aggregate and per-field permissions.

### Aggregate: `custom_data` catch-all

The `custom_data` key grants access to **all** active custom fields at once:

| Scenario | Permission Config | Result |
|----------|------------------|--------|
| Full access | `readable: all, writable: all` | All custom fields visible and editable |
| Read-only | `readable: all, writable: []` | Custom fields visible but not editable |
| No access | `readable: [name, status]` (no `custom_data`) | Custom fields hidden entirely |
| Explicit | `readable: [name, custom_data], writable: [custom_data]` | Only custom fields writable |

### Per-field: individual custom field names

Individual custom field names can appear in `readable`, `writable`, and `field_overrides`:

```yaml
permissions:
  model: project
  roles:
    editor:
      fields:
        readable: [name, status, website, phone]
        writable: [name, website]
    viewer:
      fields:
        readable: [name, custom_data]  # catch-all: ALL custom fields
        writable: []
  field_overrides:
    internal_notes:
      readable_by: [admin, manager]
      writable_by: [admin]
```

The `custom_data` catch-all and individual field names are backward compatible — `custom_data` still works as before, but you can now selectively grant access to specific custom fields.

> **Note:** The `readable_by_roles` and `writable_by_roles` attributes on individual field definitions are reserved for future use. Per-field role-based access control is currently managed through the permission system's `field_overrides`.

## Management UI

Custom field definitions are managed via nested routes under the parent model's slug:

```
GET    /:lcp_slug/custom-fields          # Index
GET    /:lcp_slug/custom-fields/new      # New form
POST   /:lcp_slug/custom-fields          # Create
GET    /:lcp_slug/custom-fields/:id      # Show
GET    /:lcp_slug/custom-fields/:id/edit # Edit form
PATCH  /:lcp_slug/custom-fields/:id      # Update
DELETE /:lcp_slug/custom-fields/:id      # Destroy
```

For example, if your model presenter has slug `projects`, the management URL is `/projects/custom-fields`. The `target_model` is resolved from the parent URL context and cannot be tampered with via form params.

Authorization is controlled by the `permissions/custom_field_definition.yml` file. Per-target-model restrictions are possible via `record_rules` on the `target_model` field.

## Database Details

### Storage

Custom field values are stored in a single `custom_data` column:

- **PostgreSQL**: `jsonb` type with a GIN index for efficient querying
- **SQLite**: `json` type (no special indexing)

The column is auto-created when the model table is first built or updated by the schema manager.

### Conflict Avoidance

The engine prevents custom field names from conflicting with:
- Existing database columns on the model
- Reserved names: `id`, `type`, `created_at`, `updated_at`, `custom_data`

If a custom field definition has the same name as an existing column, the dynamic accessor is not created (the real column takes precedence).

## Architecture

The custom fields system consists of eight components:

| Component | Location | Purpose |
|-----------|----------|---------|
| `CustomFields::Registry` | `lib/lcp_ruby/custom_fields/registry.rb` | Per-model cache of active definitions |
| `CustomFields::Applicator` | `lib/lcp_ruby/custom_fields/applicator.rb` | Installs read/write methods, accessors, validations, and defaults |
| `CustomFields::ContractValidator` | `lib/lcp_ruby/custom_fields/contract_validator.rb` | Validates the custom_field_definition model contract at boot |
| `CustomFields::Query` | `lib/lcp_ruby/custom_fields/query.rb` | DB-portable JSON query helpers with field name validation |
| `CustomFields::DefinitionChangeHandler` | `lib/lcp_ruby/custom_fields/definition_change_handler.rb` | Cache invalidation on definition changes |
| `CustomFields::Setup` | `lib/lcp_ruby/custom_fields/setup.rb` | Shared boot logic (registry, handlers, accessors, scopes) |
| `CustomFields::Utils` | `lib/lcp_ruby/custom_fields/utils.rb` | Environment-aware JSON parsing and numeric conversion |

### Data Flow

```
custom_field_definitions table
  │
  ├── CustomFields::Registry.for_model("project")
  │   └── returns cached Array of definition records
  │
  ├── CustomFields::Applicator
  │   └── defines read_custom_field / write_custom_field
  │   └── defines dynamic getters/setters via apply_custom_field_accessors!
  │   │   (tracks defined accessors; removes stale ones on re-apply)
  │   └── installs validate :validate_custom_fields
  │   └── applies default_value to new records via after_initialize
  │
  ├── CustomFields::Setup.apply!(loader)
  │   └── orchestrates boot: registry, handlers, accessors, scopes
  │
  ├── Presenter::LayoutBuilder
  │   └── appends custom field sections to form_sections / show_sections
  │
  ├── Presenter::ColumnSet
  │   └── filters custom fields by custom_data permission
  │
  ├── CustomFieldsController
  │   └── nested routes: /:lcp_slug/custom-fields
  │   └── resolves target_model from parent URL context
  │   └── scopes records by target_model
  │
  └── ResourcesController
      └── permits custom field params when custom_data is writable
      └── includes searchable custom fields in text search
```

## See Also

- [Custom Fields Reference](../reference/custom-fields.md) — complete attribute reference for all definition fields
- [Models Reference](../reference/models.md#custom_fields) — `custom_fields` option
- [Permissions Reference](../reference/permissions.md) — field-level access control
- [Model DSL Reference](../reference/model-dsl.md#custom_fields) — DSL syntax
