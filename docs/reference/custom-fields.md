# Custom Fields Reference

Custom fields allow users to add new fields to models at runtime without code changes or database migrations. Field definitions are stored in the database and values are persisted in a `custom_data` JSON/JSONB column on target model tables.

## How It Works

1. Run `rails generate lcp_ruby:custom_fields` to generate the `custom_field_definition` model, presenter, permissions, and view group
2. A model opts in via `options: { custom_fields: true }`
3. The engine automatically adds a `custom_data` column to the model's table
4. Custom field management is available via nested routes at `/<model_slug>/custom-fields`
5. Custom fields appear in form and show views grouped by section
6. Values are stored in the `custom_data` JSON column and accessed via dynamic getters/setters

## Enabling Custom Fields

### YAML

```yaml
model:
  name: project
  options:
    custom_fields: true
  fields:
    - name: name
      type: string
```

### Ruby DSL

```ruby
define_model :project do
  custom_fields true
  field :name, :string
end
```

When `custom_fields: true` is set, the engine:
- Adds a `custom_data` column (JSONB on PostgreSQL, JSON on SQLite) with a default of `{}`
- Creates a GIN index on the column (PostgreSQL only)
- Installs `read_custom_field` / `write_custom_field` instance methods
- Installs a class method `apply_custom_field_accessors!` that generates dynamic getters/setters from the definitions in the database (and removes stale accessors for deleted definitions)
- Installs validation logic that enforces constraints defined in `custom_field_definition` records
- Applies `default_value` from definitions to new records via `after_initialize`

## Custom Field Definition Attributes

Custom field definitions are records in the `custom_field_definitions` table. They describe the metadata for each custom field. You can manage them through the auto-generated presenter UI or programmatically via the `custom_field_definition` model.

### Core Attributes

#### `target_model`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Name of the model this custom field belongs to. Must match a model with `custom_fields: true` enabled.

#### `field_name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |
| **Format** | `[a-z][a-z0-9_]*` (lowercase, starts with letter) |

The programmatic name used as the getter/setter method and the key within `custom_data`. Must be unique per `target_model`. Cannot conflict with existing model column names or reserved names (`id`, `type`, `created_at`, `updated_at`, `custom_data`).

#### `custom_type`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |
| **Default** | `"string"` |
| **Allowed values** | `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`, `enum` |

The data type of the custom field. Determines validation behavior and form input rendering.

#### `label`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Human-readable label displayed in forms, show views, and table columns.

### Display Attributes

#### `description`

| | |
|---|---|
| **Type** | text |

Optional description text for the field.

#### `section`

| | |
|---|---|
| **Default** | `"Custom Fields"` |
| **Type** | string |

Section heading under which the field is grouped in forms and show views. Fields with the same `section` value appear together.

#### `position`

| | |
|---|---|
| **Default** | `0` |
| **Type** | integer |

Sort order within the section. Lower numbers appear first.

#### `active`

| | |
|---|---|
| **Default** | `true` |
| **Type** | boolean |

Whether the field is currently active. Inactive fields are hidden from UI and excluded from validation.

### Validation Attributes

#### `required`

| | |
|---|---|
| **Default** | `false` |
| **Type** | boolean |

Whether the field must have a non-blank value.

#### `min_length`

| | |
|---|---|
| **Type** | integer |

Minimum string length. Applied when `custom_type` is `string` or `text`.

#### `max_length`

| | |
|---|---|
| **Type** | integer |

Maximum string length. Applied when `custom_type` is `string` or `text`.

#### `min_value`

| | |
|---|---|
| **Type** | decimal |

Minimum numeric value. Applied when `custom_type` is `integer`, `float`, or `decimal`.

#### `max_value`

| | |
|---|---|
| **Type** | decimal |

Maximum numeric value. Applied when `custom_type` is `integer`, `float`, or `decimal`.

#### `precision`

| | |
|---|---|
| **Type** | integer |

Decimal precision (number of digits after decimal point). Informational for rendering.

#### `default_value`

| | |
|---|---|
| **Type** | string |

Default value for the field (stored as string). When set, new records automatically receive this value via `after_initialize` (unless the field is already set explicitly). Existing records are not affected.

#### `placeholder`

| | |
|---|---|
| **Type** | string |

Placeholder text for form inputs.

#### `enum_values`

| | |
|---|---|
| **Type** | json |

Allowed values when `custom_type` is `enum`. Accepts an array of strings or an array of `{ "value": "...", "label": "..." }` objects.

```json
["low", "medium", "high"]
```

```json
[
  { "value": "low", "label": "Low Priority" },
  { "value": "medium", "label": "Medium Priority" },
  { "value": "high", "label": "High Priority" }
]
```

### Visibility Attributes

#### `show_in_table`

| | |
|---|---|
| **Default** | `false` |
| **Type** | boolean |

Whether to show this field as a column in the index table.

#### `show_in_form`

| | |
|---|---|
| **Default** | `true` |
| **Type** | boolean |

Whether to show this field in create/edit forms.

#### `show_in_show`

| | |
|---|---|
| **Default** | `true` |
| **Type** | boolean |

Whether to show this field on the detail (show) page.

#### `sortable`

| | |
|---|---|
| **Default** | `false` |
| **Type** | boolean |

Whether the table column is sortable. Sorting uses JSONB/JSON extraction functions.

#### `searchable`

| | |
|---|---|
| **Default** | `false` |
| **Type** | boolean |

Whether the field is included in the text search query. Searchable custom fields are combined with regular searchable fields using OR logic.

### Rendering Attributes

#### `input_type`

| | |
|---|---|
| **Type** | string |

Override the default form input type (e.g., `textarea`, `number`, `select`).

#### `renderer`

| | |
|---|---|
| **Type** | string |

Override the default display renderer for show/index views.

#### `renderer_options`

| | |
|---|---|
| **Type** | json |

Options hash passed to the renderer.

#### `column_width`

| | |
|---|---|
| **Type** | string |

CSS width for the table column (e.g., `"120px"`, `"15%"`).

### Advanced Attributes

#### `extra_validations`

| | |
|---|---|
| **Type** | json |

Reserved for future use. Additional validation rules in JSON format.

#### `readable_by_roles`

| | |
|---|---|
| **Type** | json |

Reserved for future use. Per-field role-based read access control.

#### `writable_by_roles`

| | |
|---|---|
| **Type** | json |

Reserved for future use. Per-field role-based write access control.

## Permissions

Custom field access supports both aggregate and per-field permission granularity.

### Aggregate Access (`custom_data`)

The `custom_data` virtual field acts as a catch-all: when present in `readable` or `writable`, it grants access to **all** active custom fields.

```yaml
permissions:
  model: project
  roles:
    admin:
      fields:
        readable: all      # includes custom_data → all custom fields readable
        writable: all      # includes custom_data → all custom fields writable
    viewer:
      fields:
        readable: all      # can see all custom fields
        writable: []        # cannot edit any custom fields
    restricted:
      fields:
        readable: [name, status]   # no custom_data → custom fields hidden
        writable: []
```

### Per-Field Access

Individual custom field names can appear directly in `readable`, `writable`, and `field_overrides`:

```yaml
permissions:
  model: project
  roles:
    editor:
      fields:
        readable: [name, status, website, phone]  # specific custom fields
        writable: [name, website]                   # only website writable
    support:
      fields:
        readable: [name, custom_data]  # name + ALL custom fields
        writable: [custom_data]        # ALL custom fields writable
```

### Resolution Rules

| Permission Config | Result |
|-------------------|--------|
| `readable: all` | All custom fields readable |
| `readable: [title, custom_data]` | title + ALL custom fields |
| `readable: [title, website]` | title + only "website" custom field |
| `readable: [title]` | No custom fields visible |

### Field Overrides for Custom Fields

Per-field role-based overrides work for custom fields:

```yaml
permissions:
  model: project
  field_overrides:
    internal_notes:
      readable_by: [admin, manager]
      writable_by: [admin]
```

See also [Permission Source](permission-source.md) for DB-backed permission management.

## Management Routes

Custom field definitions are managed via nested routes under the parent model's slug:

```
GET    /:lcp_slug/custom-fields          # Index (scoped to target_model)
GET    /:lcp_slug/custom-fields/new      # New form (target_model set from URL)
POST   /:lcp_slug/custom-fields          # Create (target_model set from URL)
GET    /:lcp_slug/custom-fields/:id      # Show
GET    /:lcp_slug/custom-fields/:id/edit # Edit form
PATCH  /:lcp_slug/custom-fields/:id      # Update
DELETE /:lcp_slug/custom-fields/:id      # Destroy
```

For example, if your model presenter has slug `projects`, the management UI is available at `/projects/custom-fields`. The `target_model` is resolved from the parent URL context. Record lookups are scoped to prevent cross-model access.

The `CustomFieldsController` uses the generated `custom_fields` presenter definition that provides:
- **Index**: table with field_name, custom_type, label, section, position, active, required columns
- **Form**: grouped sections for general info, text constraints, numeric constraints, enum values, and display options
- **Show**: all field definition attributes in organized sections

Authorization is controlled by the `permissions/custom_field_definition.yml` file, separate from the parent model's permissions.

## Cache Invalidation

When a custom field definition is created, updated, or destroyed, the engine automatically:
1. Clears the cached definitions for the affected `target_model`
2. Re-applies dynamic accessors on the target model class (adding new ones and removing stale ones)

This happens via an `after_commit` callback on the `custom_field_definition` model, so changes take effect immediately without requiring a server restart.

## Database Portability

Custom field queries (search, sort, exact match) use database-specific JSON functions:

| Operation | PostgreSQL | SQLite |
|-----------|-----------|--------|
| Extract value | `custom_data ->> 'field'` | `JSON_EXTRACT(custom_data, '$.field')` |
| Text search | `ILIKE` | `LIKE` |
| Index | GIN index on `custom_data` | None (no native JSON indexing) |

## Programmatic API

### Reading and Writing Values

```ruby
project = LcpRuby.registry.model_for("project")
record = project.find(1)

# Low-level access (always available when custom_fields enabled)
record.read_custom_field("website")            # => "https://example.com"
record.write_custom_field("website", "https://new.com")
record.save!

# Dynamic accessors (available after apply_custom_field_accessors!)
record.website                                  # => "https://new.com"
record.website = "https://updated.com"
record.save!
```

### Querying

```ruby
query = LcpRuby::CustomFields::Query

# Text search
results = query.text_search(Project.all, "projects", "website", "example")

# Exact match
results = query.exact_match(Project.all, "projects", "status", "active")

# Sort expression
Project.all.order(query.sort_expression("projects", "website", "asc"))
Project.all.order(query.sort_expression("projects", "score", "desc", cast: :integer))
```

### Registry

```ruby
registry = LcpRuby::CustomFields::Registry

# Get definitions for a model
definitions = registry.for_model("project")  # => Array of definition records

# Clear cache
registry.reload!("project")   # single model
registry.reload!               # all models
```
