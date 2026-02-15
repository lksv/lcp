# Models Reference

File: `config/lcp_ruby/models/<name>.yml`

Model YAML defines the data layer: database columns, validations, associations, scopes, and events. The engine reads these files at boot and dynamically creates ActiveRecord models under the `LcpRuby::Dynamic::` namespace.

## Top-Level Attributes

```yaml
model:
  name: <model_name>
  label: "Display Name"
  label_plural: "Display Names"
  table_name: <custom_table_name>
  fields: []
  validations: []
  associations: []
  scopes: []
  events: []
  options: {}
```

### `name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string (snake_case) |

Internal identifier for the model. Used to generate the AR class name (`LcpRuby::Dynamic::TodoItem` for `todo_item`), default table name, and cross-references from presenters and permissions.

### `label`

| | |
|---|---|
| **Required** | no |
| **Default** | `name.humanize` |
| **Type** | string |

Human-readable singular name displayed in the UI (page titles, flash messages).

### `label_plural`

| | |
|---|---|
| **Required** | no |
| **Default** | `label.pluralize` |
| **Type** | string |

Plural form of the label. Used in index page headings and navigation.

### `table_name`

| | |
|---|---|
| **Required** | no |
| **Default** | `name.pluralize` |
| **Type** | string |

Override the database table name. Use this when integrating with an existing database that has a non-standard table naming convention.

```yaml
model:
  name: todo_item
  table_name: legacy_todo_items
```

## Fields

Each field defines a database column and its metadata.

```yaml
fields:
  - name: title
    type: string
    label: "Title"
    default: "Untitled"
    column_options:
      limit: 255
      "null": false
    enum_values: []
    validations: []
```

### Field Attributes

#### `name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Column name. Must be unique within the model. Used as the ActiveRecord attribute name.

#### `type`

| | |
|---|---|
| **Required** | yes |
| **Type** | string (one of 14 valid types) |

Determines the database column type and default form input behavior.

| Type | DB Column | Description |
|------|-----------|-------------|
| `string` | `:string` | Short text (varchar). Default form input: text field. |
| `text` | `:text` | Long text. Default form input: textarea. |
| `integer` | `:integer` | Whole number. |
| `float` | `:float` | Floating-point number. |
| `decimal` | `:decimal` | Precise decimal. Use `column_options: { precision:, scale: }`. |
| `boolean` | `:boolean` | True/false. Default form input: checkbox. |
| `date` | `:date` | Date without time. |
| `datetime` | `:datetime` | Date and time. |
| `enum` | `:string` | Stored as string. Requires `enum_values`. Default form input: select. |
| `file` | `:string` | File path/reference stored as string. |
| `rich_text` | `:text` | Rich text content. Default form input: rich text editor. |
| `json` | `:jsonb` | JSON data stored as PostgreSQL jsonb. |
| `uuid` | `:string` | UUID stored as string. |

#### `label`

| | |
|---|---|
| **Required** | no |
| **Default** | `name.humanize` |
| **Type** | string |

Display label for form inputs, table headers, and show fields.

#### `default`

| | |
|---|---|
| **Required** | no |
| **Default** | `nil` |
| **Type** | varies by field type |

Default value assigned to new records. Applied as a database column default.

```yaml
- name: completed
  type: boolean
  default: false

- name: priority
  type: string
  default: "medium"
```

#### `column_options`

| | |
|---|---|
| **Required** | no |
| **Default** | `{}` |
| **Type** | hash |

Options passed directly to the ActiveRecord migration column definition.

| Option | Applicable Types | Description |
|--------|-----------------|-------------|
| `limit` | string | Maximum character length |
| `precision` | decimal | Total number of digits |
| `scale` | decimal | Digits after decimal point |
| `null` | all | Allow NULL values (`true`/`false`) |

```yaml
column_options:
  limit: 255
  "null": false
```

> Note: Quote `null` as `"null"` in YAML to avoid it being parsed as a null value.

#### `enum_values`

| | |
|---|---|
| **Required** | yes (when type is `enum`) |
| **Type** | array of strings or hashes |

Defines the allowed values for an enum field. Two formats are supported:

**Simple format** — value and label are the same:

```yaml
enum_values: [draft, published, archived]
```

**Hash format** — separate internal value and display label:

```yaml
enum_values:
  - { value: draft, label: "Draft" }
  - { value: published, label: "Published" }
  - { value: archived, label: "Archived" }
```

#### `validations`

| | |
|---|---|
| **Required** | no |
| **Default** | `[]` |
| **Type** | array of validation objects |

Field-level validations. See [Validations](#validations) below.

## Validations

Validations can be defined at the field level (inside a field's `validations` array) or at the model level (in the top-level `validations` array). Model-level validations only support the `custom` type.

### Validation Types

Each validation has a `type` and optional `options` hash.

#### `presence`

Validates that the field is not blank.

```yaml
validations:
  - type: presence
```

With conditional options:

```yaml
validations:
  - type: presence
    options: { if: "requires_title?" }
```

#### `length`

Validates string length.

| Option | Type | Description |
|--------|------|-------------|
| `minimum` | integer | Minimum length |
| `maximum` | integer | Maximum length |
| `is` | integer | Exact length |
| `in` | range | Length range (e.g., `3..100`) |

```yaml
validations:
  - type: length
    options: { minimum: 3, maximum: 100 }
```

#### `numericality`

Validates numeric constraints.

| Option | Type | Description |
|--------|------|-------------|
| `greater_than` | number | Must be > value |
| `greater_than_or_equal_to` | number | Must be >= value |
| `less_than` | number | Must be < value |
| `less_than_or_equal_to` | number | Must be <= value |
| `equal_to` | number | Must be exactly value |
| `allow_nil` | boolean | Skip validation when nil |

```yaml
validations:
  - type: numericality
    options: { greater_than_or_equal_to: 0, allow_nil: true }
```

#### `format`

Validates against a regular expression.

| Option | Type | Description |
|--------|------|-------------|
| `with` | string | Regex pattern (converted to `Regexp` at runtime) |

```yaml
validations:
  - type: format
    options: { with: "\\A[a-zA-Z0-9]+\\z" }
```

#### `inclusion`

Validates that the value is in a given set.

| Option | Type | Description |
|--------|------|-------------|
| `in` | array | Allowed values |

```yaml
validations:
  - type: inclusion
    options: { in: [low, medium, high] }
```

#### `exclusion`

Validates that the value is not in a given set.

| Option | Type | Description |
|--------|------|-------------|
| `in` | array | Excluded values |

```yaml
validations:
  - type: exclusion
    options: { in: [banned, restricted] }
```

#### `uniqueness`

Validates uniqueness of the value.

| Option | Type | Description |
|--------|------|-------------|
| `scope` | string or array | Columns to scope uniqueness to |
| `case_sensitive` | boolean | Case-sensitive comparison |

```yaml
validations:
  - type: uniqueness
    options: { scope: company_id, case_sensitive: false }
```

#### `confirmation`

Validates that a `<field>_confirmation` attribute matches the field.

```yaml
validations:
  - type: confirmation
```

#### `custom`

Delegates to a custom validator class. The class must inherit from `ActiveModel::Validator`.

| Attribute | Type | Description |
|-----------|------|-------------|
| `validator_class` | string | Fully qualified class name |

```yaml
# Field-level custom validation
fields:
  - name: email
    type: string
    validations:
      - type: custom
        validator_class: "EmailFormatValidator"

# Model-level custom validation
validations:
  - type: custom
    validator_class: "BusinessRuleValidator"
```

### Common Validation Options

These options can be added to any validation type:

| Option | Type | Description |
|--------|------|-------------|
| `message` | string | Custom error message |
| `allow_blank` | boolean | Skip validation when value is blank |
| `if` | string | Method name; only validate when method returns true |
| `unless` | string | Method name; skip validation when method returns true |

```yaml
validations:
  - type: presence
    options: { message: "must be provided", if: "active?" }
  - type: numericality
    options: { greater_than: 0, allow_blank: true, unless: "draft?" }
```

The `if` and `unless` options reference method names on the model instance. These methods must be defined in a model extension or custom validator.

## Associations

Associations define relationships between models.

```yaml
associations:
  # Standard belongs_to
  - type: belongs_to
    name: company
    target_model: company
    foreign_key: company_id
    required: true
    inverse_of: employees

  # Polymorphic belongs_to (creates _id + _type columns automatically)
  - type: belongs_to
    name: commentable
    polymorphic: true
    required: false

  # has_many with polymorphic inverse
  - type: has_many
    name: comments
    target_model: comment
    as: commentable

  # has_many through (join model)
  - type: has_many
    name: taggings
    target_model: tagging
  - type: has_many
    name: tags
    through: taggings
    source: tag
```

### Association Attributes

#### `type`

| | |
|---|---|
| **Required** | yes |
| **Allowed** | `belongs_to`, `has_many`, `has_one` |

The ActiveRecord association type.

#### `name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

The association name. Used as the method name on the model (e.g., `record.company`).

#### `target_model`

| | |
|---|---|
| **Required** | conditionally (see below) |
| **Type** | string |

Name of another LCP model. The engine resolves this to `LcpRuby::Dynamic::<TargetModel>` at runtime. Use this for associations between LCP-managed models.

At least one of `target_model`, `class_name`, `polymorphic`, `as`, or `through` must be present.

```yaml
- type: belongs_to
  name: todo_list
  target_model: todo_list
  foreign_key: todo_list_id
```

#### `class_name`

| | |
|---|---|
| **Required** | conditionally (see `target_model`) |
| **Type** | string |

Fully qualified class name for associations pointing to non-LCP models (e.g., your host app's `User` model). When `target_model` is set, `class_name` is ignored — the engine generates it automatically.

```yaml
- type: belongs_to
  name: author
  class_name: "User"
  foreign_key: author_id
```

#### `foreign_key`

| | |
|---|---|
| **Required** | no |
| **Default** | Rails convention (`<name>_id` for `belongs_to`) |
| **Type** | string |

The foreign key column name. Specify this when the column name does not follow Rails naming conventions.

#### `dependent`

| | |
|---|---|
| **Required** | no |
| **Default** | none |
| **Type** | string |
| **Allowed** | `destroy`, `delete_all`, `nullify`, `restrict_with_error`, `restrict_with_exception` |

What happens to associated records when the parent is destroyed. Applicable to all association types.

#### `required`

| | |
|---|---|
| **Required** | no |
| **Default** | `true` for `belongs_to`, `false` for `has_many`/`has_one` |
| **Type** | boolean |

Whether the association is mandatory. For `belongs_to`, setting `required: false` allows the foreign key to be NULL.

#### `inverse_of`

| | |
|---|---|
| **Required** | no |
| **Default** | none (Rails auto-detection) |
| **Type** | string |
| **Applies to** | all types |

Specifies the inverse association on the target model. Rails usually infers this, but explicit setting avoids ambiguity and improves performance by preventing extra queries.

```yaml
associations:
  - type: has_many
    name: tasks
    target_model: task
    inverse_of: project
```

#### `counter_cache`

| | |
|---|---|
| **Required** | no |
| **Default** | none |
| **Type** | boolean or string |
| **Applies to** | `belongs_to` |

Maintains a count column on the parent model. Set to `true` to use the default column name (`<children>_count`), or a string for a custom column name.

The counter column must be added as a field on the parent model.

```yaml
# On child model
associations:
  - type: belongs_to
    name: project
    target_model: project
    counter_cache: true

# Or with custom column name
    counter_cache: tasks_count
```

#### `touch`

| | |
|---|---|
| **Required** | no |
| **Default** | none |
| **Type** | boolean or string |
| **Applies to** | `belongs_to` |

Updates the parent's `updated_at` timestamp when the child is saved. Set to `true` for `updated_at`, or a string for a custom timestamp column.

```yaml
associations:
  - type: belongs_to
    name: project
    target_model: project
    touch: true
```

#### `polymorphic`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |
| **Applies to** | `belongs_to` |

Creates a polymorphic association. When `true`, the engine automatically creates both `<name>_id` and `<name>_type` columns. No `target_model` or `class_name` is needed — the type is determined at runtime from the `_type` column.

```yaml
# On child model (e.g., comment)
associations:
  - type: belongs_to
    name: commentable
    polymorphic: true
    required: false
```

#### `as`

| | |
|---|---|
| **Required** | no |
| **Default** | none |
| **Type** | string |
| **Applies to** | `has_many`, `has_one` |

The polymorphic interface name on the target model. Used with `polymorphic` belongs_to on the other side.

```yaml
# On parent model (e.g., post)
associations:
  - type: has_many
    name: comments
    target_model: comment
    as: commentable
```

#### `through`

| | |
|---|---|
| **Required** | no |
| **Default** | none |
| **Type** | string |
| **Applies to** | `has_many`, `has_one` |

Creates a through association via a join model. The value is the name of another association on this model that serves as the join. No FK columns are created for through associations.

```yaml
associations:
  - type: has_many
    name: taggings
    target_model: tagging
  - type: has_many
    name: tags
    through: taggings
```

#### `source`

| | |
|---|---|
| **Required** | no |
| **Default** | none (Rails infers from association name) |
| **Type** | string |
| **Applies to** | `has_many`, `has_one` (with `through`) |

Specifies the source association on the join model. Only needed when the name cannot be inferred automatically.

```yaml
associations:
  - type: has_many
    name: authors
    through: authorships
    source: person
```

#### `autosave`

| | |
|---|---|
| **Required** | no |
| **Default** | none (Rails default) |
| **Type** | boolean |
| **Applies to** | all types |

When `true`, saves associated records whenever the parent is saved.

```yaml
associations:
  - type: has_many
    name: items
    target_model: item
    autosave: true
```

#### `validate`

| | |
|---|---|
| **Required** | no |
| **Default** | none (Rails default) |
| **Type** | boolean |
| **Applies to** | all types |

When `true`, validates associated records on save. Set to `false` to skip validation of associated records.

```yaml
associations:
  - type: has_many
    name: items
    target_model: item
    validate: false
```

## Scopes

Scopes define named query methods on the model.

```yaml
scopes:
  - name: open_deals
    where_not: { stage: [closed_won, closed_lost] }
  - name: won
    where: { stage: closed_won }
  - name: recent
    order: { created_at: desc }
    limit: 10
```

### Scope Attributes

#### `name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

The scope method name. Called as `ModelClass.scope_name` in queries and referenced from [predefined filters](presenters.md#search-configuration).

#### `where`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Generates `scope :name, -> { where(...) }`. Keys are column names, values are the expected values (scalar or array).

#### `where_not`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Generates `scope :name, -> { where.not(...) }`. Same syntax as `where` but negated.

#### `order`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Generates ordering. Keys are column names, values are `asc` or `desc`.

#### `limit`

| | |
|---|---|
| **Required** | no |
| **Type** | integer |

Limits the number of returned records. Combine with `order` for "top N" queries.

#### `type`

| | |
|---|---|
| **Required** | no |
| **Allowed** | `custom` |

When set to `custom`, the scope is not generated from YAML. Instead, it must be defined in Ruby code via a model extension. The scope entry in YAML serves as documentation and allows it to be referenced from predefined filters.

### Combined Scopes

Scope attributes are additive. A single scope can combine `where`, `where_not`, `order`, and `limit`:

```yaml
scopes:
  - name: top_open_deals
    where_not: { stage: [closed_won, closed_lost] }
    order: { value: desc }
    limit: 5
```

This generates: `scope :top_open_deals, -> { where.not(stage: [...]).order(value: :desc).limit(5) }`

## Events

Events trigger [event handlers](../guides/event-handlers.md) in response to record changes.

```yaml
events:
  - name: after_create
    type: lifecycle
  - name: on_stage_change
    type: field_change
    field: stage
    condition: "active"
```

### Event Attributes

#### `name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Event identifier. Matched against `HandlerBase.handles_event` in registered handlers. For lifecycle events, use one of the predefined names.

#### `type`

| | |
|---|---|
| **Required** | no |
| **Default** | inferred from `name` |
| **Allowed** | `lifecycle`, `field_change` |

- `lifecycle` — triggered by ActiveRecord callbacks
- `field_change` — triggered when a specific field's value changes during an update

If omitted, the type is inferred: names matching `after_create`, `after_update`, `before_destroy`, or `after_destroy` are treated as lifecycle; all others as field_change.

#### `field`

| | |
|---|---|
| **Required** | yes (for `field_change` type) |
| **Type** | string |

The field to monitor for changes. The event fires only when this field's value changes.

#### `condition`

| | |
|---|---|
| **Required** | no |
| **Type** | string |

Optional condition for the event. When specified, provides additional context for event filtering.

### Lifecycle Events

| Name | Trigger |
|------|---------|
| `after_create` | After a new record is created |
| `after_update` | After an existing record is updated |
| `before_destroy` | Before a record is destroyed |
| `after_destroy` | After a record is destroyed |

## Options

```yaml
options:
  timestamps: true
  label_method: title
```

### `timestamps`

| | |
|---|---|
| **Default** | `true` |
| **Type** | boolean |

Adds `created_at` and `updated_at` columns to the table.

### `label_method`

| | |
|---|---|
| **Default** | `"to_s"` |
| **Type** | string |

Method called on records to generate display text (e.g., in association select dropdowns). Should return a human-readable string.

## Complete Example

```yaml
model:
  name: todo_item
  label: "Todo Item"
  label_plural: "Todo Items"

  fields:
    - name: title
      type: string
      label: "Title"
      column_options:
        limit: 255
        "null": false
      validations:
        - type: presence

    - name: completed
      type: boolean
      label: "Completed"
      default: false

    - name: due_date
      type: date
      label: "Due Date"

  associations:
    - type: belongs_to
      name: todo_list
      target_model: todo_list
      foreign_key: todo_list_id
      required: true

  options:
    timestamps: true
    label_method: title
```

Source: `lib/lcp_ruby/metadata/model_definition.rb`, `lib/lcp_ruby/metadata/field_definition.rb`, `lib/lcp_ruby/metadata/validation_definition.rb`, `lib/lcp_ruby/metadata/association_definition.rb`, `lib/lcp_ruby/metadata/event_definition.rb`
