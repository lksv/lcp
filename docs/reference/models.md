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
  display_templates: {}
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
| **Type** | string (base type or registered business type) |

Determines the database column type and default form input behavior. Accepts one of the 14 base types below, or any registered [business type](types.md) name (e.g., `email`, `phone`, `url`, `color`).

**Base types:**

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
| `json` | `:jsonb` / `:json` | JSON data. Uses jsonb on PostgreSQL, json on other adapters. |
| `uuid` | `:string` | UUID stored as string. |
| `attachment` | none (uses Active Storage) | File attachment (single or multiple). Requires Active Storage. |

**Built-in business types:**

| Type | Base | Transforms | Input | Description |
|------|------|------------|-------|-------------|
| `email` | string | strip, downcase | `<input type="email">` | Email with format validation |
| `phone` | string | strip, normalize_phone | `<input type="tel">` | Phone with format validation |
| `url` | string | strip, normalize_url | `<input type="url">` | URL with format validation, auto-prepends `https://` |
| `color` | string | strip, downcase | `<input type="color">` | Hex color (`#rrggbb`) with format validation |

Business types bundle transforms (normalization), validations, HTML input hints, and column options into a reusable definition. See [Types Reference](types.md) for defining custom types.

##### Attachment Fields

The `attachment` type uses Active Storage instead of a database column. It supports both single-file (`has_one_attached`) and multi-file (`has_many_attached`) attachments.

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `multiple` | boolean | `false` | Use `has_many_attached` instead of `has_one_attached` |
| `accept` | string | none | HTML `accept` attribute hint for file input (e.g., `"image/*"`). Not validated server-side — use `content_types` for validation. |
| `max_size` | string | global default | Maximum file size per file (e.g., `"10MB"`, `"512KB"`) |
| `min_size` | string | none | Minimum file size per file |
| `content_types` | array | global default | Allowed MIME types. Supports wildcards (e.g., `"image/*"`) |
| `max_files` | integer | none | Maximum number of files (only for `multiple: true`) |
| `variants` | hash | none | Named image variant configurations |

```yaml
fields:
  # Single image attachment with variants
  - name: photo
    type: attachment
    label: "Photo"
    options:
      accept: "image/*"
      max_size: 5MB
      content_types: ["image/jpeg", "image/png", "image/webp"]
      variants:
        thumbnail: { resize_to_limit: [100, 100] }
        medium: { resize_to_limit: [300, 300] }

  # Multiple file attachment
  - name: files
    type: attachment
    label: "Documents"
    options:
      multiple: true
      max_files: 10
      max_size: 50MB
      content_types: ["application/pdf", "image/*"]
```

Attachment fields require Active Storage to be set up in the host application. See the [Attachments Guide](../guides/attachments.md) for prerequisites and complete examples.

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
| **Type** | scalar, string (built-in key), or hash (service) |

Default value for new records. Supports three forms:

**Scalar default** — applied as a database column default:

```yaml
- name: completed
  type: boolean
  default: false

- name: priority
  type: string
  default: "medium"
```

**Built-in dynamic default** — a string matching a built-in default key. Applied at runtime via `after_initialize` (only on new records, only when the field is blank):

| Key | Value | Description |
|-----|-------|-------------|
| `current_date` | `Date.today` | Today's date |
| `current_datetime` | `Time.current` | Current date and time |
| `current_user_id` | `LcpRuby::Current.user&.id` | Current user's ID |

```yaml
- name: start_date
  type: date
  default: current_date
```

**Service dynamic default** — delegates to a registered default service. Applied at runtime via `after_initialize`:

```yaml
- name: expected_close_date
  type: date
  default:
    service: thirty_days_out
```

```ruby
# DSL
field :start_date, :date, default: "current_date"
field :expected_close_date, :date, default: { service: "thirty_days_out" }
```

Service contract: `def self.call(record, field_name) -> value`. Register in `app/lcp_services/defaults/`. See [Extensibility Guide](../guides/extensibility.md).

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

#### `transforms`

| | |
|---|---|
| **Required** | no |
| **Default** | `[]` |
| **Type** | array of strings |

Field-level transforms applied via `ActiveRecord.normalizes`. Transforms run before validation on every assignment. Field-level transforms extend type-level transforms (defined via [custom types](types.md)) — the union is applied, with type-level transforms running first.

```yaml
# YAML
- name: title
  type: string
  transforms: [strip]

# With custom type that already has transforms
- name: email
  type: email  # email type has strip+downcase
  transforms: [strip]  # deduplicated, won't strip twice
```

```ruby
# DSL
field :first_name, :string, transforms: [:strip, :titlecase]
```

Built-in transforms: `strip`, `downcase`, `normalize_url`, `normalize_phone`. Custom transforms can be registered in `app/lcp_services/transforms/`. See [Extensibility Guide](../guides/extensibility.md).

#### `computed`

| | |
|---|---|
| **Required** | no |
| **Default** | `nil` |
| **Type** | string (template) or hash (service) |

Computed fields are automatically calculated before save. They are rendered as readonly in forms.

**Template syntax** — interpolates other field values:

```yaml
- name: full_name
  type: string
  computed: "{first_name} {last_name}"
```

**Service syntax** — delegates to a registered computed service:

```yaml
- name: weighted_value
  type: decimal
  computed:
    service: weighted_deal_value
```

```ruby
# DSL
field :full_name, :string, computed: "{first_name} {last_name}"
field :weighted_value, :decimal, computed: { service: "weighted_deal_value" }
```

Service contract: `def self.call(record) -> value`. Register in `app/lcp_services/computed/`. See [Extensibility Guide](../guides/extensibility.md).

#### `validations`

| | |
|---|---|
| **Required** | no |
| **Default** | `[]` |
| **Type** | array of validation objects |

Field-level validations. See [Validations](#validations) below.

## Validations

Validations can be defined at the field level (inside a field's `validations` array) or at the model level (in the top-level `validations` array). Model-level validations support the `custom` and `service` types.

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

#### `comparison`

Compares the field value against another field on the same record. Skipped when either value is nil.

| Attribute | Type | Description |
|-----------|------|-------------|
| `operator` | string | Comparison operator: `gt`, `gte`, `lt`, `lte`, `eq`, `not_eq` |
| `field_ref` | string | Name of the field to compare against |
| `message` | string | Custom error message |

```yaml
fields:
  - name: due_date
    type: date
    validations:
      - type: comparison
        operator: gte
        field_ref: start_date
        message: "must be on or after start date"
```

```ruby
# DSL
field :due_date, :date do
  validates :comparison, operator: :gte, field_ref: :start_date,
    message: "must be on or after start date"
end
```

#### `service`

Delegates validation to a registered service class. The service receives the record and can add errors.

| Attribute | Type | Description |
|-----------|------|-------------|
| `service` | string | Service key registered in `app/lcp_services/validators/` |

```yaml
# Model-level service validation
validations:
  - type: service
    service: deal_credit_limit
```

```ruby
# DSL
validates_model :service, service: "deal_credit_limit"
```

Service contract: `def self.call(record, **opts) -> void` (adds errors directly to `record.errors`). Register in `app/lcp_services/validators/`. See [Extensibility Guide](../guides/extensibility.md).

### Conditional Validations (`when:`)

Any validation can be made conditional using the `when:` key. When present, the validation only runs if the condition evaluates to true. The condition uses the same `{ field:, operator:, value: }` syntax as [`visible_when`](presenters.md#field-visibility) and [`condition`](condition-operators.md).

```yaml
fields:
  - name: value
    type: decimal
    validations:
      - type: presence
        when:
          field: stage
          operator: not_in
          value: [lead]
      - type: numericality
        options: { greater_than_or_equal_to: 0, allow_nil: true }
```

```ruby
# DSL
field :value, :decimal do
  validates :presence, when: { field: :stage, operator: :not_in, value: %w[lead] }
  validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
end
```

Service-based conditions are also supported:

```yaml
validations:
  - type: presence
    when:
      service: requires_approval
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
| **Allowed** | `destroy`, `delete`, `delete_all`, `nullify`, `restrict_with_error`, `restrict_with_exception` |

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

#### `order`

| | |
|---|---|
| **Required** | no |
| **Default** | none |
| **Type** | hash |
| **Applies to** | `has_many`, `has_one` |

Default ordering for associated records. The engine passes this as a scope lambda to the ActiveRecord association. Keys are column names, values are `asc` or `desc`.

```yaml
associations:
  - type: has_many
    name: todo_items
    target_model: todo_item
    order:
      position: asc
```

This generates: `has_many :todo_items, -> { order(position: :asc) }, ...`

Useful for sortable nested forms where child records have a position field.

## Nested Attributes

Associations can declare `nested_attributes` to enable creating and updating associated records through the parent model's form. This uses Rails' `accepts_nested_attributes_for` under the hood.

```yaml
associations:
  - type: has_many
    name: todo_items
    target_model: todo_item
    dependent: destroy
    inverse_of: todo_list
    nested_attributes:
      allow_destroy: true
      reject_if: all_blank
      limit: 50
      update_only: false
```

### Nested Attributes Keys

#### `allow_destroy`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |

When `true`, nested records can be marked for deletion by passing `_destroy: true` in the nested attributes hash. Without this option, nested records can only be created and updated, not removed through the parent form.

```yaml
nested_attributes:
  allow_destroy: true
```

#### `reject_if`

| | |
|---|---|
| **Required** | no |
| **Default** | none |
| **Type** | string |

Controls when nested records are silently rejected (not saved). The special value `"all_blank"` rejects any nested record where every attribute value is blank. This is useful for forms that render empty rows for new records — blank rows are ignored instead of causing validation errors.

Can also be set to a symbol name referencing a custom method on the model that returns `true` to reject the record.

```yaml
nested_attributes:
  reject_if: all_blank
```

#### `limit`

| | |
|---|---|
| **Required** | no |
| **Default** | none (unlimited) |
| **Type** | integer |

Maximum number of nested records that can be processed at once. If the incoming attributes hash contains more records than the limit, a `TooManyRecords` exception is raised. Use this to prevent abuse or accidental mass-creation of associated records.

```yaml
nested_attributes:
  limit: 50
```

#### `update_only`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |

When `true`, only existing associated records can be updated — no new records are created through nested attributes. Nested attribute hashes without a matching `id` are ignored.

```yaml
nested_attributes:
  update_only: true
```

### Requirements

- The parent association **must** specify `inverse_of` for nested attributes to work correctly. Without `inverse_of`, Rails cannot properly link the parent and child records during validation, which can cause unexpected behavior or validation failures.
- Nested attributes are typically used with `has_many` and `has_one` associations.

### Full Example

```yaml
model:
  name: todo_list
  label: "Todo List"

  fields:
    - name: name
      type: string
      validations:
        - type: presence

  associations:
    - type: has_many
      name: todo_items
      target_model: todo_item
      dependent: destroy
      inverse_of: todo_list
      nested_attributes:
        allow_destroy: true
        reject_if: all_blank
        limit: 50
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
    condition:
      field: stage
      operator: not_in
      value: [lead]
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
| **Type** | hash (recommended) or string (deprecated) |

Optional condition that must be met for the event to fire. Uses the same `{ field:, operator:, value: }` syntax as [condition operators](condition-operators.md). When a `field_change` event fires, the condition is evaluated against the record's current state — the event is only dispatched if the condition returns true.

```yaml
# Hash condition (recommended)
events:
  - name: on_stage_change
    type: field_change
    field: stage
    condition:
      field: stage
      operator: not_eq
      value: draft
```

```ruby
# DSL
on_field_change :on_stage_change, field: :stage,
  condition: { field: :stage, operator: :not_in, value: %w[lead] }
```

> **Deprecated:** String conditions (evaluated via `instance_eval`) are deprecated and will be removed in a future version. Migrate to Hash conditions.

### Lifecycle Events

| Name | Trigger |
|------|---------|
| `after_create` | After a new record is created |
| `after_update` | After an existing record is updated |
| `before_destroy` | Before a record is destroyed |
| `after_destroy` | After a record is destroyed |

## Display Templates

Display templates define rich HTML representations for records when displayed in contexts like `association_list`. Unlike `to_label` (which remains plain text), display templates support structured layouts with titles, subtitles, icons, and badges — or delegate to custom renderers/partials.

Templates live on the **model** (not the presenter), so the same record can be rendered consistently across different presenters. The presenter selects which template to use by name.

### YAML Syntax

```yaml
display_templates:
  default:
    template: "{first_name} {last_name}"
    subtitle: "{position} at {company.name}"
    icon: user
    badge: "{status}"
  compact:
    template: "{last_name}, {first_name}"
  card:
    renderer: ContactCardRenderer
  mini:
    partial: "contacts/mini_label"
```

### Three Forms

| Form | Detected by | Description |
|------|-------------|-------------|
| **Structured** | `template` key | Title, optional subtitle/icon/badge with `{field}` interpolation |
| **Renderer** | `renderer` key | Delegates to a registered `Display::BaseRenderer` subclass |
| **Partial** | `partial` key | Renders a Rails partial with `record` local |

### Structured Template Keys

| Key | Type | Description |
|-----|------|-------------|
| `template` | string | **Required.** Main text with `{field}` placeholders |
| `subtitle` | string | Secondary text below the title |
| `icon` | string | Icon identifier (rendered as text; style via CSS) |
| `badge` | string | Small label, supports `{field}` placeholders |

Field placeholders use the same dot-path syntax as presenter fields: `{field_name}` for direct fields, `{association.field}` for related records.

### Renderer Form

| Key | Type | Description |
|-----|------|-------------|
| `renderer` | string | Class name of a registered `Display::BaseRenderer` |
| `options` | hash | Passed to the renderer's `render` method |

### Partial Form

| Key | Type | Description |
|-----|------|-------------|
| `partial` | string | Rails partial path (e.g., `"contacts/mini_label"`) |

### DSL Syntax

```ruby
define_model :contact do
  display_template :default,
    template: "{first_name} {last_name}",
    subtitle: "{position} at {company.name}",
    icon: "user"

  display_template :card, renderer: "ContactCardRenderer"
  display_template :mini, partial: "contacts/mini_label"
end
```

### Permission Filtering

Fields referenced in templates are resolved through `FieldValueResolver`, which respects the current user's `PermissionEvaluator`. If a field is not readable, it renders as blank rather than exposing unauthorized data.

### Eager Loading

The `IncludesResolver` automatically detects dot-path fields in display templates (e.g., `{company.name}`) and generates nested eager loading (e.g., `{ contacts: :company }`) to prevent N+1 queries.

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

### `custom_fields`

| | |
|---|---|
| **Default** | `false` |
| **Type** | boolean |

Enables user-defined custom fields on this model. When `true`, the engine:
- Adds a `custom_data` column (JSONB on PostgreSQL, JSON on SQLite) to the model's table
- Creates a GIN index on the column (PostgreSQL only)
- Installs dynamic accessor methods for each custom field definition
- Validates custom field values based on their definition constraints
- Auto-generates a management presenter at `/custom-fields-<model_name>`

Custom field definitions are stored in the built-in `custom_field_definition` model. Access is controlled through the `custom_data` virtual field in permissions.

```yaml
options:
  custom_fields: true
```

See [Custom Fields Reference](custom-fields.md) for the complete attribute reference and [Custom Fields Guide](../guides/custom-fields.md) for a step-by-step tutorial.

## Complete Example

### YAML (TODO App)

```yaml
model:
  name: todo_item
  label: "Todo Item"
  label_plural: "Todo Items"

  fields:
    - name: title
      type: string
      label: "Title"
      transforms: [strip]
      column_options:
        limit: 255
        "null": false
      validations:
        - type: presence

    - name: completed
      type: boolean
      label: "Completed"
      default: false

    - name: start_date
      type: date
      label: "Start Date"
      default: current_date

    - name: due_date
      type: date
      label: "Due Date"
      default:
        service: one_week_from_now
      validations:
        - type: comparison
          operator: gte
          field_ref: start_date
          message: "must be on or after start date"
        - type: presence
          when:
            field: completed
            operator: eq
            value: false

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

### Ruby DSL (CRM App)

```ruby
define_model :deal do
  label "Deal"
  label_plural "Deals"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end

  field :stage, :enum, label: "Stage", default: "lead",
    values: {
      lead: "Lead", qualified: "Qualified", proposal: "Proposal",
      negotiation: "Negotiation", closed_won: "Closed Won",
      closed_lost: "Closed Lost"
    }

  field :value, :decimal, label: "Value", precision: 12, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
    validates :presence, when: { field: :stage, operator: :not_in, value: %w[lead] }
  end

  field :weighted_value, :decimal, label: "Weighted Value", precision: 12, scale: 2,
    computed: { service: "weighted_deal_value" }

  field :expected_close_date, :date, label: "Expected Close",
    default: { service: "thirty_days_out" } do
    validates :comparison, operator: :gte, field_ref: :created_at,
      message: "cannot be before deal creation"
  end

  belongs_to :company, model: :company, required: true
  belongs_to :contact, model: :contact, required: false

  validates :contact_id, :presence,
    when: { field: :stage, operator: :in, value: %w[negotiation closed_won closed_lost] }

  validates_model :service, service: "deal_credit_limit"

  scope :open_deals, where_not: { stage: ["closed_won", "closed_lost"] }

  on_field_change :on_stage_change, field: :stage,
    condition: { field: :stage, operator: :not_in, value: %w[lead] }

  timestamps true
  label_method :title
end
```

Source: `lib/lcp_ruby/metadata/model_definition.rb`, `lib/lcp_ruby/metadata/field_definition.rb`, `lib/lcp_ruby/metadata/validation_definition.rb`, `lib/lcp_ruby/metadata/association_definition.rb`, `lib/lcp_ruby/metadata/event_definition.rb`
