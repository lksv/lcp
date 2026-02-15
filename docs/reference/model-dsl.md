# Model DSL Reference

File: `config/lcp_ruby/models/<name>.rb`

The Model DSL is a Ruby alternative to [YAML model definitions](models.md). It produces the same internal representation (`ModelDefinition`, `FieldDefinition`, etc.) and feeds through the same pipeline — the DSL builder outputs a hash identical to parsed YAML, which is then processed by `ModelDefinition.from_hash`.

DSL files live alongside YAML files in `config/lcp_ruby/models/`. A project can mix both formats, but each model name must be unique across all files (defining the same model in both `.yml` and `.rb` raises `MetadataError`).

## Entry Point

```ruby
LcpRuby.define_model :model_name do
  # DSL calls here
end
```

The symbol argument becomes the model name. The block is evaluated on a builder context object that provides all the DSL methods documented below.

In DSL files loaded by the engine, use `define_model` without the `LcpRuby.` prefix:

```ruby
# config/lcp_ruby/models/task.rb
define_model :task do
  label "Task"
  field :title, :string
  timestamps true
end
```

## Model Metadata

### `label`

| | |
|---|---|
| **Required** | no |
| **Default** | `name.humanize` |
| **Type** | string |

Human-readable singular name displayed in the UI.

```ruby
label "Todo Item"
```

### `label_plural`

| | |
|---|---|
| **Required** | no |
| **Default** | `label.pluralize` |
| **Type** | string |

Plural form used in index page headings and navigation.

```ruby
label_plural "Todo Items"
```

### `table_name`

| | |
|---|---|
| **Required** | no |
| **Default** | `name.pluralize` |
| **Type** | string |

Override the database table name.

```ruby
table_name "legacy_todo_items"
```

### `timestamps`

| | |
|---|---|
| **Required** | no |
| **Default** | `true` (when set via options) |
| **Type** | boolean |

Adds `created_at` and `updated_at` columns to the table.

```ruby
timestamps true
```

### `label_method`

| | |
|---|---|
| **Required** | no |
| **Default** | `"to_s"` |
| **Type** | symbol or string |

Method called on records to generate display text (e.g., in association select dropdowns).

```ruby
label_method :title
```

## Fields

```ruby
field :name, :type, **options do
  # optional: field-level validations
end
```

### Positional Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | yes | Column name (symbol). Must be unique within the model. |
| `type` | yes | Field type (symbol). One of the 14 valid types below. |

### Field Types

| Type | DB Column | Description |
|------|-----------|-------------|
| `:string` | `:string` | Short text (varchar). Default form input: text field. |
| `:text` | `:text` | Long text. Default form input: textarea. |
| `:integer` | `:integer` | Whole number. |
| `:float` | `:float` | Floating-point number. |
| `:decimal` | `:decimal` | Precise decimal. Use `precision:` and `scale:` options. |
| `:boolean` | `:boolean` | True/false. Default form input: checkbox. |
| `:date` | `:date` | Date without time. |
| `:datetime` | `:datetime` | Date and time. |
| `:enum` | `:string` | Stored as string. Requires `values:` option. Default form input: select. |
| `:file` | `:string` | File path/reference stored as string. |
| `:rich_text` | `:text` | Rich text content. Default form input: rich text editor. |
| `:json` | `:jsonb` | JSON data stored as PostgreSQL jsonb. |
| `:uuid` | `:string` | UUID stored as string. |

### Keyword Options

| Option | Maps to | Description |
|--------|---------|-------------|
| `label:` | `FieldDefinition.label` | Display label. Default: humanized name. |
| `default:` | `FieldDefinition.default` | Default value for new records. |
| `values:` | `FieldDefinition.enum_values` | Enum values — Hash or Array (see below). |
| `limit:` | `column_options[:limit]` | Maximum character length (string). |
| `precision:` | `column_options[:precision]` | Total number of digits (decimal). |
| `scale:` | `column_options[:scale]` | Digits after decimal point (decimal). |
| `null:` | `column_options[:null]` | Allow NULL values. |

Column options (`limit`, `precision`, `scale`, `null`) are flattened to top-level keyword arguments for conciseness. The builder separates them back into a `column_options` hash internally.

### Examples

```ruby
# String with column constraints and validations
field :title, :string, label: "Title", limit: 255, null: false do
  validates :presence
end

# Decimal with precision
field :price, :decimal, precision: 12, scale: 2

# Boolean with default
field :completed, :boolean, default: false

# Date without options
field :due_date, :date, label: "Due Date"
```

### Enum Values

The `values:` option accepts two formats:

**Hash format** — explicit labels:

```ruby
field :status, :enum, default: "draft",
  values: { draft: "Draft", published: "Published", archived: "Archived" }
```

**Array format** — labels auto-humanized from value names:

```ruby
field :priority, :enum, values: [:low, :medium, :high]
# Produces: low → "Low", medium → "Medium", high → "High"
```

Both formats produce the same `enum_values` structure as the [YAML hash format](models.md#enum_values).

## Validations

Validations can be placed in two locations:

### Style A — Inside a Field Block

Preferred for field-specific validations. The field context is implicit — only the validation type and options are needed.

```ruby
field :title, :string do
  validates :presence
  validates :length, minimum: 3, maximum: 255
end

field :budget, :decimal do
  validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
end
```

### Style B — At Model Level

ActiveRecord-like style where the field name is the first argument. Useful when adding validations to fields defined elsewhere or when preferring the AR convention.

```ruby
field :email, :string
field :title, :string

validates :email, :format, with: '\A[^@\s]+@[^@\s]+\z', allow_blank: true
validates :title, :presence
validates :title, :length, minimum: 3, maximum: 255
```

Both styles produce the same result — a `ValidationDefinition` attached to the field's `validations` array. The referenced field must be defined in the same model; referencing an unknown field raises `MetadataError`.

### Model-Level Validations

For validations not attached to a specific field (e.g., cross-field validators), use `validates_model`:

```ruby
validates_model :custom, validator_class: "DateRangeValidator"
```

### Validation Types

#### `presence`

Validates that the field is not blank.

```ruby
validates :presence
```

#### `length`

Validates string length.

| Option | Type | Description |
|--------|------|-------------|
| `minimum` | integer | Minimum length |
| `maximum` | integer | Maximum length |
| `is` | integer | Exact length |
| `in` | range | Length range |

```ruby
validates :length, minimum: 3, maximum: 100
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

```ruby
validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
```

#### `format`

Validates against a regular expression pattern.

| Option | Type | Description |
|--------|------|-------------|
| `with` | string | Regex pattern (converted to `Regexp` at runtime) |

```ruby
validates :format, with: '\A[a-zA-Z0-9]+\z'
```

> Note: Use string patterns instead of Ruby regex literals (`/.../`) for portability.

#### `inclusion`

Validates that the value is in a given set.

```ruby
validates :inclusion, in: ["low", "medium", "high"]
```

#### `exclusion`

Validates that the value is not in a given set.

```ruby
validates :exclusion, in: ["banned", "restricted"]
```

#### `uniqueness`

Validates uniqueness of the value.

| Option | Type | Description |
|--------|------|-------------|
| `scope` | symbol or array | Columns to scope uniqueness to |
| `case_sensitive` | boolean | Case-sensitive comparison |

```ruby
validates :uniqueness, scope: :company_id, case_sensitive: false
```

#### `confirmation`

Validates that a `<field>_confirmation` attribute matches the field.

```ruby
validates :confirmation
```

#### `custom`

Delegates to a custom validator class.

| Option | Type | Description |
|--------|------|-------------|
| `validator_class` | string | Fully qualified class name (required) |

```ruby
validates :custom, validator_class: "EmailFormatValidator", strict: true
```

All additional keyword arguments are passed as validation options.

### Common Validation Options

These options can be added to any validation type:

| Option | Type | Description |
|--------|------|-------------|
| `message` | string | Custom error message |
| `allow_blank` | boolean | Skip validation when value is blank |
| `if` | string | Method name; only validate when method returns true |
| `unless` | string | Method name; skip validation when method returns true |

```ruby
validates :presence, message: "must be provided", if: "active?"
validates :numericality, greater_than: 0, unless: "draft?"
```

The `if` and `unless` options accept method name strings (not procs) for portability.

## Associations

### `belongs_to`

```ruby
belongs_to :company, model: :company, required: true
belongs_to :author, class_name: "User", foreign_key: :author_id
```

### `has_many`

```ruby
has_many :contacts, model: :contact, dependent: :destroy
has_many :items, model: :item, foreign_key: :parent_id
```

### `has_one`

```ruby
has_one :profile, model: :profile, dependent: :destroy
```

### Association Options

| Option | Maps to | Description |
|--------|---------|-------------|
| `model:` | `AssociationDefinition.target_model` | Target LCP model name. For associations between LCP-managed models. |
| `class_name:` | `AssociationDefinition.class_name` | Target class name. For external (non-LCP) ActiveRecord models. |
| `foreign_key:` | `AssociationDefinition.foreign_key` | Foreign key column. Auto-inferred for `belongs_to` (e.g., `:company` → `company_id`). |
| `required:` | `AssociationDefinition.required` | Whether association is mandatory. Default: `true` for `belongs_to`, `false` otherwise. |
| `dependent:` | `AssociationDefinition.dependent` | What happens on parent destroy: `:destroy`, `:nullify`, `:delete_all`, `:restrict_with_error`. |

One of `model:` or `class_name:` is required. Use `model:` for LCP models; use `class_name:` for host app models (e.g., `User`).

## Scopes

```ruby
scope :name, where: { ... }, where_not: { ... }, order: { ... }, limit: N
```

Purely declarative — no lambdas, no raw SQL. Options are additive (a single scope can combine all of them).

### Scope Options

| Option | Type | Description |
|--------|------|-------------|
| `where:` | hash | `where(...)` conditions. Keys = columns, values = expected values. |
| `where_not:` | hash | `where.not(...)` conditions. Same syntax, negated. |
| `order:` | hash | Ordering. Keys = columns, values = `:asc` or `:desc`. |
| `limit:` | integer | Maximum number of returned records. |

### Examples

```ruby
scope :active,       where: { status: "active" }
scope :not_closed,   where_not: { stage: ["closed_won", "closed_lost"] }
scope :recent,       order: { created_at: :desc }, limit: 10
scope :top_active,   where: { status: "active" }, order: { value: :desc }, limit: 5
```

Scopes can be referenced from [predefined filters](presenters.md#search-configuration) in presenters.

## Events

Events trigger [event handlers](../guides/event-handlers.md) in response to record changes.

### Lifecycle Events

```ruby
after_create                    # name defaults to "after_create"
after_create :my_custom_name    # custom event name
after_update
before_destroy
after_destroy
```

Each method accepts an optional symbol argument to set a custom event name. When omitted, the method name itself is used.

| Method | Trigger |
|--------|---------|
| `after_create` | After a new record is created |
| `after_update` | After an existing record is updated |
| `before_destroy` | Before a record is destroyed |
| `after_destroy` | After a record is destroyed |

### Field Change Events

```ruby
on_field_change :event_name, field: :field_name
on_field_change :on_priority_change, field: :priority, condition: "priority_increased?"
```

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | yes | Event identifier (symbol). |
| `field:` | yes | Field to monitor for changes. |
| `condition:` | no | Method name string for additional filtering. |

## DSL vs YAML Equivalence

The DSL produces the exact same hash structure as parsed YAML. Every DSL construct has a 1:1 YAML equivalent:

| DSL | YAML Equivalent |
|-----|----------------|
| `label "Deal"` | `label: "Deal"` |
| `field :title, :string` | `fields: [{ name: title, type: string }]` |
| `field ... do validates :presence end` | `validations: [{ type: presence }]` inside field |
| `values: { a: "A" }` | `enum_values: [{ value: a, label: "A" }]` |
| `limit: 255, null: false` | `column_options: { limit: 255, "null": false }` |
| `belongs_to :x, model: :x` | `associations: [{ type: belongs_to, name: x, target_model: x }]` |
| `scope :a, where: { ... }` | `scopes: [{ name: a, where: { ... } }]` |
| `after_create` | `events: [{ name: after_create }]` |
| `on_field_change :e, field: :f` | `events: [{ name: e, type: field_change, field: f }]` |
| `timestamps true` | `options: { timestamps: true }` |

For the full YAML attribute reference, see [Models Reference](models.md).

## Debugging

The builder exposes two methods for inspecting the generated output:

### `to_hash`

Returns the hash that would be passed to `ModelDefinition.from_hash`. Useful for verifying DSL output matches expected YAML structure.

```ruby
builder = LcpRuby::Dsl::ModelBuilder.new(:task)
builder.instance_eval do
  field :title, :string
  timestamps true
end
puts builder.to_hash.inspect
# => {"name"=>"task", "fields"=>[{"name"=>"title", "type"=>"string"}], "options"=>{"timestamps"=>true}}
```

### `to_yaml`

Serializes the hash to a YAML string with the `model:` root key. Useful for migrating from DSL to YAML or comparing output.

```ruby
puts builder.to_yaml
# => ---
#    model:
#      name: task
#      fields:
#      - name: title
#        type: string
#      options:
#        timestamps: true
```

## Complete Example

A deal-tracking model demonstrating all DSL features:

```ruby
# config/lcp_ruby/models/deal.rb
define_model :deal do
  label "Deal"
  label_plural "Deals"

  field :title, :string, label: "Title" do
    validates :presence
    validates :length, minimum: 3, maximum: 255
  end

  field :stage, :enum, default: "lead",
    values: { lead: "Lead", closed_won: "Closed Won", closed_lost: "Closed Lost" }

  field :value, :decimal, precision: 12, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :description, :text

  belongs_to :company, model: :company, required: true
  belongs_to :contact, model: :contact, required: false

  scope :open_deals, where_not: { stage: ["closed_won", "closed_lost"] }
  scope :won,        where: { stage: "closed_won" }

  on_field_change :on_stage_change, field: :stage
  after_create

  timestamps true
  label_method :title
end
```

**YAML equivalent** — the same model in [YAML format](models.md#complete-example) would be approximately 50 lines.

Source: `lib/lcp_ruby/dsl/model_builder.rb`, `lib/lcp_ruby/dsl/field_builder.rb`, `lib/lcp_ruby/dsl/dsl_loader.rb`
