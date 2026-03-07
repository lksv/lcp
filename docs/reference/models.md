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
  aggregates: {}
  positioning: true | { field: position, scope: parent_id }
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

#### Virtual Models

Set `table_name: _virtual` to create a metadata-only model — no database table and no ActiveRecord class are created. Virtual models exist purely for field metadata (types, labels, validations, transforms, defaults) and are used as item definitions for JSON field nested editing.

```yaml
model:
  name: address
  table_name: _virtual
  fields:
    - name: street
      type: string
      validations: [{ type: presence }]
    - name: city
      type: string
      validations: [{ type: presence }]
    - name: zip
      type: string
    - name: country
      type: string
      default: "CZ"
```

Virtual models:
- Are loaded by `Metadata::Loader` and available via `LcpRuby.loader.model_definitions`
- Are **not** registered in `LcpRuby.registry` (no AR class to register)
- Are **not** built by `ModelFactory::Builder` — `SchemaManager.ensure_table!` skips them
- Should not have associations or scopes (these produce warnings in `ConfigurationValidator`)
- Are referenced from presenter `nested_fields` sections via `target_model:` — see [JSON Field with Target Model](presenters.md#json-field-source-model-backed)

When a `json_field:` + `target_model:` nested section is rendered, each hash item from the JSON array is wrapped in a `JsonItemWrapper` that uses the virtual model's field definitions for type coercion, getter/setter access, and per-item validation.

#### API-Backed Models

Add a `data_source` key to create a model backed by an external REST API or host-provided adapter instead of the database:

```yaml
model:
  name: external_building
  data_source:
    type: rest_json                  # rest_json | host
    base_url: "https://api.example.com"
    resource: "/buildings"
    auth:
      type: bearer
      token_env: "API_TOKEN"
    cache:
      enabled: true
      ttl: 300
  fields:
    - name: name
      type: string
```

API-backed models use `ActiveModel` instead of `ActiveRecord`. They support index and show views, cross-source associations (DB model → API model), permissions, and display renderers. Features requiring database access (soft_delete, auditing, userstamps, tree, positioning, custom_fields) are not available.

See [API-Backed Models Reference](api-backed-models.md) and [API-Backed Models Guide](../guides/api-backed-models.md) for full documentation.

### `positioning`

| | |
|---|---|
| **Required** | no |
| **Type** | boolean or hash |

Enables automatic record positioning via the [`positioning`](https://github.com/brendon/positioning) gem. When present, records get automatic sequential position assignment on create, gap closing on destroy, and atomic reorder support.

**Minimal form** — uses `position` field with no scope:

```yaml
positioning: true
```

**Hash form** — custom field and/or scoped positioning:

```yaml
positioning:
  field: position          # optional, default: "position"
  scope: pipeline_id       # optional, string or array of strings
```

**Multi-column scope:**

```yaml
positioning:
  scope: [pipeline_id, category]
```

When `positioning` is set:
- The `positioned` gem macro is applied to the dynamic model
- The position column gets a `NOT NULL` constraint
- A unique index on `[scope_columns..., position_column]` is added (except on SQLite)
- The `positioning.field` must reference a declared field of type `integer`
- Each `positioning.scope` entry must be a declared field or a belongs_to FK

See [Record Positioning](../design/record_positioning.md) for the full design.

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
| `array` | PG: native array / SQLite: `:json` | Typed array of scalars. Requires `item_type`. Default form input: tag chips. |
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

##### Array Fields

The `array` type stores a list of scalar values. It requires an `item_type` to specify the element type.

**Supported item types:** `string`, `integer`, `float`

**Storage:** On PostgreSQL, uses native array columns (`text[]`, `integer[]`, `float[]`). On SQLite and other adapters, uses a JSON column with transparent serialization.

```yaml
fields:
  # String array (e.g., tags)
  - name: tags
    type: array
    item_type: string
    default: []

  # Integer array (e.g., scores)
  - name: scores
    type: array
    item_type: integer
    default: []

  # Float array (e.g., measurements)
  - name: measurements
    type: array
    item_type: float
```

**Auto-generated scopes:** Each array field automatically creates two scopes:

| Scope | Description | SQL (PostgreSQL) |
|-------|-------------|------------------|
| `with_<field>(values)` | Records whose array contains ALL given values | `@>` (array containment) |
| `with_any_<field>(values)` | Records whose array contains ANY of the given values | `&&` (array overlap) |

```ruby
# Find records tagged with both "ruby" AND "rails"
Article.with_tags(["ruby", "rails"])

# Find records tagged with "ruby" OR "python"
Article.with_any_tags(["ruby", "python"])
```

**Quick search:** Array fields with `item_type: string` are automatically included in quick search (`?qs=`). The search matches any element that contains the query text (case-insensitive on PostgreSQL, case-sensitive on SQLite).

**Presenter defaults:** Array fields automatically use the `array_input` form input (tag-style chips) and the `collection` renderer. These can be overridden in the presenter.

See also: [Array validations](#array_length), [Condition operators for arrays](condition-operators.md#array-operators).

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

#### `item_type`

| | |
|---|---|
| **Required** | yes (when type is `array`) |
| **Type** | string |

Specifies the scalar type of array elements. Must be one of: `string`, `integer`, `float`.

```yaml
- name: tags
  type: array
  item_type: string
```

```ruby
# DSL
field :tags, :array, item_type: :string
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

#### `array_length`

Validates the number of items in an array field.

| Option | Type | Description |
|--------|------|-------------|
| `minimum` | integer | Minimum number of items |
| `maximum` | integer | Maximum number of items |

```yaml
fields:
  - name: tags
    type: array
    item_type: string
    validations:
      - type: array_length
        options: { minimum: 1, maximum: 10 }
```

```ruby
# DSL
field :tags, :array, item_type: :string do
  validates :array_length, minimum: 1, maximum: 10
end
```

#### `array_inclusion`

Validates that all items in the array are within an allowed set.

| Option | Type | Description |
|--------|------|-------------|
| `in` | array | Allowed values |

```yaml
fields:
  - name: tags
    type: array
    item_type: string
    validations:
      - type: array_inclusion
        options: { in: [ruby, python, java, go, rust] }
```

```ruby
# DSL
field :tags, :array, item_type: :string do
  validates :array_inclusion, in: %w[ruby python java go rust]
end
```

#### `array_uniqueness`

Validates that all items in the array are unique (no duplicates).

```yaml
fields:
  - name: tags
    type: array
    item_type: string
    validations:
      - type: array_uniqueness
```

```ruby
# DSL
field :tags, :array, item_type: :string do
  validates :array_uniqueness
end
```

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
| **Allowed** | `destroy`, `delete`, `delete_all`, `nullify`, `restrict_with_error`, `restrict_with_exception`, `discard` |

What happens to associated records when the parent is destroyed (or discarded). Applicable to all association types.

The `discard` value is special — it is **not** passed to ActiveRecord. Instead, when the parent record is discarded (soft-deleted), the `SoftDeleteApplicator` cascades the discard to child records with `dependent: :discard`. This requires:
- The parent model must have `soft_delete` enabled
- The target (child) model must also have `soft_delete` enabled
- Only valid on `has_many` / `has_one` associations (not `belongs_to`)

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
| **Allowed** | `custom`, `parameterized` |

- `custom` — the scope is not generated from YAML. Instead, it must be defined in Ruby code via a model extension. The scope entry in YAML serves as documentation and allows it to be referenced from predefined filters.
- `parameterized` — the scope accepts typed parameters at runtime. The `parameters` attribute defines the parameter schema (see below). The actual scope must be defined in Ruby — either as a standard AR scope with keyword arguments, or as a `filter_*` interceptor method.

#### `parameters`

| | |
|---|---|
| **Required** | only when `type: parameterized` |
| **Type** | array of parameter definitions |

Each parameter has:

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `name` | string | yes | Parameter name (used as keyword argument) |
| `type` | string | yes | One of: `boolean`, `string`, `integer`, `float`, `enum`, `date`, `datetime`, `model_select` |
| `default` | any | no | Default value when the parameter is not provided |
| `required` | boolean | no | Whether the parameter must be provided (default: `false`). If a required parameter is missing, the scope is skipped |
| `min` | number | no | Minimum value (integer/float only). Values below this are clamped |
| `max` | number | no | Maximum value (integer/float only). Values above this are clamped |
| `values` | array | no | Allowed values (enum type only). Values not in the list are rejected |
| `model` | string | no | Target model name (model_select only) |
| `display_field` | string | no | Field to display in the select dropdown (model_select only) |

### Parameterized Scopes

Parameterized scopes let users configure scope arguments at runtime. Parameters are cast, validated, and clamped before being passed to the scope.

```yaml
scopes:
  - name: created_recently
    type: parameterized
    parameters:
      - name: days
        type: integer
        default: 30
        min: 1
        max: 365

  - name: by_min_price
    type: parameterized
    parameters:
      - name: min_price
        type: float
        default: 0.0
        min: 0

  - name: by_status_filter
    type: parameterized
    parameters:
      - name: status
        type: enum
        values: [draft, published, archived]
        required: true
```

The Ruby implementation can be either a standard scope or a `filter_*` interceptor:

```ruby
# Option A: AR scope with keyword arguments
scope :created_recently, ->(days: 30) {
  where("created_at >= ?", days.to_i.days.ago)
}

# Option B: filter_* interceptor (more flexible)
def self.filter_by_min_price(scope, params, evaluator)
  min = params[:min_price] || 0
  scope.where("price >= ?", min)
end
```

In the [query language](../design/advanced_search.md), parameterized scopes use `@` prefix syntax:

```
@created_recently(days: 7)
@by_status_filter(status: 'published')
```

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

### NULL / Empty Value Scopes

YAML `null` maps to Ruby `nil`, which ActiveRecord translates to `WHERE column IS NULL`. This works in both `where` and `where_not` conditions.

```yaml
scopes:
  # Records where phone is NULL
  - name: without_phone
    where:
      phone: null

  # Records where phone is NOT NULL
  - name: with_phone
    where_not:
      phone: null

  # Records where phone is NULL or empty string
  - name: blank_phone
    where:
      phone: [null, ""]
```

Generated SQL:

| Scope | SQL |
|-------|-----|
| `without_phone` | `WHERE phone IS NULL` |
| `with_phone` | `WHERE phone IS NOT NULL` |
| `blank_phone` | `WHERE phone IS NULL OR phone = ''` |

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

## Aggregates

Virtual computed columns derived from associated records via SQL subqueries. Aggregates are not stored in the database — they are calculated at query time and injected into SELECT statements as correlated subqueries. They can be referenced in presenter table columns and show sections just like regular fields.

Aggregate names must not collide with field names on the same model.

### YAML Syntax

```yaml
aggregates:
  issues_count:
    function: count
    association: issues

  open_issues_count:
    function: count
    association: issues
    where: { status: open }

  total_revenue:
    function: sum
    association: orders
    source_field: amount
    default: 0

  weighted_score:
    sql: "SELECT SUM(r.score * r.weight) / NULLIF(SUM(r.weight), 0) FROM ratings r WHERE r.project_id = %{table}.id"
    type: float

  health_score:
    service: project_health
    type: integer
```

### DSL Syntax

```ruby
aggregate :issues_count, function: :count, association: :issues
aggregate :open_issues_count, function: :count, association: :issues,
  where: { status: "open" }
aggregate :total_revenue, function: :sum, association: :orders,
  source_field: :amount, default: 0
```

### Three Aggregate Types

| Type | Detected by | Description |
|------|-------------|-------------|
| **Declarative** | `function` + `association` | SQL aggregate function over a has_many association |
| **SQL** | `sql` key | Custom SQL subquery returning a single value |
| **Service** | `service` key | Ruby service class from `app/lcp_services/aggregates/` |

### Declarative Aggregate Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `function` | string | yes | SQL aggregate function: `count`, `sum`, `min`, `max`, `avg` |
| `association` | string | yes | Name of a `has_many` association on the model |
| `source_field` | string | for sum/min/max/avg | Field on the target model to aggregate. Optional for `count` (defaults to `*`) |
| `where` | hash | no | Equality conditions on the target model (see [Where Conditions](#where-conditions)) |
| `distinct` | boolean | no | Use `DISTINCT` in the aggregate function (default: `false`) |
| `default` | any | no | Default value via `COALESCE`. `count` always defaults to `0` even without this |
| `include_discarded` | boolean | no | Include soft-deleted records (default: `false`). Only relevant when the target model uses `soft_delete` |

### SQL Aggregate Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `sql` | string | yes | Custom SQL subquery. Use `%{table}` for the parent model's quoted table name |
| `type` | string | yes | Result type: `string`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime` |
| `default` | any | no | Default value via `COALESCE` |

### Service Aggregate Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `service` | string | yes | Service key looked up in `app/lcp_services/aggregates/` |
| `type` | string | yes | Result type |
| `options` | hash | no | Options hash passed to the service's `call` method |

The service class must implement `self.call(record, options:)`. Optionally implement `self.sql_expression(model_class, options:)` to return a SQL string — this enables sorting and avoids per-record evaluation.

### Where Conditions

The `where` hash applies equality conditions to the subquery:

```yaml
where: { status: open }                         # WHERE status = 'open'
where: { status: [open, in_progress] }           # WHERE status IN ('open', 'in_progress')
where: { deleted_at: null }                      # WHERE deleted_at IS NULL
where: { status: active, priority: high }        # WHERE status = 'active' AND priority = 'high'
where: { assignee_id: :current_user }            # WHERE assignee_id = <current_user.id>
```

The `:current_user` placeholder resolves to `current_user.id` at query time. When no user is signed in, it resolves to `nil` (producing `IS NULL`). This enables per-user aggregates like "my open issues count".

### Type Inference

Declarative aggregates infer their result type automatically:

| Function | Inferred type |
|----------|---------------|
| `count` | `integer` (always) |
| `sum`, `min`, `max` | Same as `source_field` type |
| `avg` | `float` (or `decimal` if source is `decimal`) |

SQL and service aggregates require an explicit `type` attribute.

### Soft Delete Awareness

When the target model uses `soft_delete`, aggregates automatically exclude soft-deleted records (`WHERE discarded_at IS NULL`). Set `include_discarded: true` to include them.

### Presenter Usage

Aggregates are referenced in presenters as regular fields:

```yaml
# Index — sortable aggregate column
table_columns:
  - { field: issues_count, sortable: true }
  - { field: total_revenue, renderer: currency, sortable: true }

# Show — in a section
layout:
  - section: "Statistics"
    fields:
      - { field: issues_count }
      - { field: total_revenue, renderer: currency }
```

Aggregates are visible to all roles regardless of field permissions — they are computed values, not stored data.

### Complete Example

```yaml
model:
  name: company
  fields:
    - { name: name, type: string }
  associations:
    - { type: has_many, name: contacts, target_model: contact, foreign_key: company_id }
    - { type: has_many, name: deals, target_model: deal, foreign_key: company_id }
  aggregates:
    contacts_count:
      function: count
      association: contacts
    deals_count:
      function: count
      association: deals
    total_deal_value:
      function: sum
      association: deals
      source_field: value
      default: 0
    won_deals_value:
      function: sum
      association: deals
      source_field: value
      where: { stage: closed_won }
      default: 0
    my_deals_count:
      function: count
      association: deals
      where: { assignee_id: :current_user }
```

## Options

```yaml
options:
  timestamps: true
  label_method: title
  soft_delete: true                    # or { column: deleted_at }
  auditing: true                       # or { only: [title, status], ... }
  userstamps: true                     # or { created_by: author_id, updated_by: editor_id, store_name: true }
  tree: true                           # or { parent_field: parent_category_id, ... }
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

### `soft_delete`

| | |
|---|---|
| **Default** | `false` (disabled) |
| **Type** | `true` or Hash |

Enables soft delete (logical deletion) for this model. Instead of permanently deleting records, the engine sets a timestamp column to mark them as discarded.

**Simple form** — uses default column `discarded_at`:

```yaml
options:
  soft_delete: true
```

**Hash form** — custom column name:

```yaml
options:
  soft_delete:
    column: deleted_at
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `column` | string | `"discarded_at"` | Name of the datetime column that stores the discard timestamp |

When `soft_delete` is enabled, the engine automatically:

- Creates the timestamp column (`discarded_at` by default) plus tracking columns (`discarded_by_type`, `discarded_by_id`)
- Adds scopes: `kept` (non-discarded), `discarded` (discarded only), `with_discarded` (all records)
- Adds instance methods: `discard!`, `undiscard!`, `discarded?`, `kept?`, `cascade_discarded?`
- Changes the controller `destroy` action to soft-delete (sets `discarded_at`) instead of hard-delete
- Filters discarded records from the default index view (applies `kept` scope)
- Supports `dependent: :discard` on `has_many` associations for automatic cascade discard/undiscard

The `discard!(by:)` method accepts an optional `by:` parameter to track which record triggered the discard (used for cascade tracking). The `undiscard!` method only restores cascade-discarded children — manually discarded records are left as-is.

See [Soft Delete Guide](../guides/soft-delete.md) for setup and usage examples.

### `auditing`

| | |
|---|---|
| **Default** | `false` (disabled) |
| **Type** | `true` or Hash |

Enables change auditing for this model. When enabled, all field changes are tracked and stored via the configured `audit_writer`.

**Simple form** — tracks all fields:

```yaml
options:
  auditing: true
```

**Hash form** — fine-grained control:

```yaml
options:
  auditing:
    only:
      - title
      - status
    track_associations: true
    track_attachments: true
    expand_custom_fields: true
    expand_json_fields:
      - addresses
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `only` | array of strings | all fields | Track only these fields. Mutually exclusive with `ignore`. |
| `ignore` | array of strings | none | Track all fields except these. Mutually exclusive with `only`. |
| `track_associations` | boolean | `true` | Include nested_attributes child changes in parent audit entry |
| `track_attachments` | boolean | `false` | Include attachment changes in audit trail (reserved, not yet implemented) |
| `expand_custom_fields` | boolean | `true` | Expand `custom_data` JSON into individual `cf:` prefixed field changes |
| `expand_json_fields` | array of strings | `[]` | JSON columns to expand into dot-path key changes |

> **Note:** `only` and `ignore` are mutually exclusive — specifying both causes a validation error.

See [Auditing Reference](auditing.md) for the audit log model contract, changes data format, and configuration options. See [Auditing Guide](../guides/auditing.md) for setup and usage examples.

### `userstamps`

| | |
|---|---|
| **Default** | `false` (disabled) |
| **Type** | `true` or Hash |

Enables automatic user tracking — stores the ID of the user who created and last updated each record via a `before_save` callback that reads from `LcpRuby::Current.user`.

**Simple form** — uses default columns `created_by_id` and `updated_by_id`:

```yaml
options:
  userstamps: true
```

**Hash form** — custom column names and name snapshots:

```yaml
options:
  userstamps:
    created_by: author_id
    updated_by: editor_id
    store_name: true
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `created_by` | string | `"created_by_id"` | Column name for the creating user's FK |
| `updated_by` | string | `"updated_by_id"` | Column name for the last updating user's FK |
| `store_name` | boolean | `false` | Add denormalized `_name` snapshot columns (e.g., `created_by_name`, `updated_by_name`) |

The applicator automatically:
- Adds `bigint` columns (nullable, indexed) for creator and updater FK
- Adds `string` columns for name snapshots when `store_name: true`
- Adds `belongs_to` associations pointing to `LcpRuby.configuration.user_class`
- Sets `created_by_id` only on `new_record?`, `updated_by_id` on every save
- Writes `nil` when `LcpRuby::Current.user` is not set (seeds, jobs, console)
- `update_columns` bypasses the callback by design (same as Rails timestamps)

### `tree`

| | |
|---|---|
| **Default** | `false` (disabled) |
| **Type** | `true` or Hash |

Enables tree/hierarchy structure for this model. The model becomes self-referencing with parent-child relationships, enabling nested structures like categories, organizational units, or threaded comments.

**Simple form** — uses defaults:

```yaml
options:
  tree: true
```

**Hash form** — custom configuration:

```yaml
options:
  tree:
    parent_field: parent_category_id
    parent_name: parent_category
    children_name: subcategories
    dependent: nullify
    max_depth: 5
    ordered: true
    position_field: position
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `parent_field` | string | `"parent_id"` | Foreign key column for the parent record |
| `parent_name` | string | `"parent"` | Name of the `belongs_to` parent association |
| `children_name` | string | `"children"` | Name of the `has_many` children association |
| `dependent` | string | `"destroy"` | What happens to children when parent is deleted. Values: `destroy`, `nullify`, `restrict_with_exception`, `restrict_with_error`, `discard` (requires soft_delete) |
| `max_depth` | integer | `10` | Maximum allowed tree depth. Enforced by cycle detection validation |
| `ordered` | boolean | `false` | Enable position-based ordering of siblings. Automatically configures `positioning` scoped to parent |
| `position_field` | string | `"position"` | Column name for sibling ordering (only used when `ordered: true`) |

The `TreeApplicator` automatically:
- Creates `belongs_to` / `has_many` self-referential associations
- Adds `roots` and `leaves` scopes
- Adds traversal instance methods: `root?`, `leaf?`, `ancestors`, `descendants`, `subtree`, `subtree_ids`, `siblings`, `depth`, `path`, `root`
- Adds cycle detection validation (prevents self-reference, circular chains, and max_depth violations)
- Adds a database index on the parent field
- When `ordered: true`, configures `positioning` scoped to the parent field (unless the model already has explicit positioning)

See [Tree Structures Reference](tree-structures.md) for full details on scopes, methods, and presenter integration.

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
