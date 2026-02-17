# Types Reference

File: `config/lcp_ruby/types/<name>.yml` or `config/lcp_ruby/types/<name>.rb`

The Type Registry allows defining reusable **business types** that bundle a base storage type with transforms (normalization), validations, HTML input hints, and column options. Instead of repeating validation patterns and column settings across models, define a type once and reference it by name from any field.

## How It Works

1. Types are registered at boot time — built-in types first, then user-defined types from `config/lcp_ruby/types/`
2. When a field uses `type: email` (or any registered type name), the `FieldDefinition` resolves it via the `TypeRegistry`
3. The resolved `TypeDefinition` drives:
   - **Column creation** — base type determines the DB column type; type-level `column_options` are applied (field-level options override)
   - **Transforms** — `ActiveRecord.normalizes` chain assembled from named transform services
   - **Validations** — type-default validations merged with field-level validations (field wins on conflict)
   - **Form input** — `input_type` drives HTML5 input rendering (`<input type="email">`, `<input type="tel">`, etc.)

For step-by-step examples of defining custom types, see the [Custom Types Guide](../guides/custom-types.md).

## Built-in Types

LCP Ruby ships with 4 built-in business types:

| Type | Base | Transforms | Validation | Input | Display | Limit |
|------|------|------------|------------|-------|---------|-------|
| `email` | string | strip, downcase | email format regex | `email` | `email_link` | 255 |
| `phone` | string | strip, normalize_phone | phone format regex | `tel` | `phone_link` | 50 |
| `url` | string | strip, normalize_url | URL format regex | `url` | `url_link` | 2048 |
| `color` | string | strip, downcase | hex color regex (`#rrggbb`) | `color` | `color_swatch` | 7 |

All built-in format validations include `allow_blank: true` — they only validate format when a value is present. To make a typed field required, add a `presence` validation on the field itself.

### Transform Behavior

| Transform | Effect | Example |
|-----------|--------|---------|
| `strip` | Removes leading/trailing whitespace | `"  hello  "` → `"hello"` |
| `downcase` | Converts to lowercase | `"FOO@BAR.COM"` → `"foo@bar.com"` |
| `normalize_url` | Prepends `https://` if no scheme present | `"example.com"` → `"https://example.com"` |
| `normalize_phone` | Strips non-digit characters, preserves leading `+` | `"+1 (555) 123-4567"` → `"+15551234567"` |

Transforms run via `ActiveRecord.normalizes`, which means they execute on attribute assignment — the value is normalized before it reaches the database or validations.

## Usage in Model YAML

Reference a registered type name in a field's `type` attribute:

```yaml
model:
  name: contact
  fields:
    - name: email
      type: email
      validations:
        - type: presence    # additional validation on top of type defaults

    - name: phone
      type: phone

    - name: website
      type: url

    - name: favorite_color
      type: color
```

The field accepts both base types (`string`, `integer`, etc.) and registered type names (`email`, `phone`, etc.). When a registered type is used:

- The DB column uses the type's `base_type` (e.g., `email` → `string` column)
- Type-level `column_options` apply (e.g., `limit: 255` for email)
- Type-level transforms are applied via `normalizes`
- Type-level validations are merged with field-level validations
- The form renders the appropriate HTML5 input type

### Field-Level Overrides

Field-level settings take precedence over type defaults:

**Column options** — field `column_options` override type-level options:

```yaml
- name: short_email
  type: email
  column_options:
    limit: 100    # overrides the email type's default limit of 255
```

**Validations** — if the field defines a validation of the same type as a type default, the field's version wins and the type default is skipped:

```yaml
- name: company_email
  type: email
  validations:
    - type: format
      options:
        with: "\\A.+@company\\.com\\z"    # replaces the default email format regex
    - type: presence                        # additional validation, merged with type defaults
```

## Usage in Model DSL

```ruby
define_model :contact do
  field :email, :email do
    validates :presence
  end

  field :phone, :phone
  field :website, :url
  field :favorite_color, :color
end
```

## YAML Type Definition

Define custom types in `config/lcp_ruby/types/<name>.yml`:

```yaml
type:
  name: currency
  base_type: decimal
  column_options:
    precision: 12
    scale: 2
  transforms:
    - strip
  validations:
    - type: numericality
      options:
        greater_than_or_equal_to: 0
        allow_blank: true
  input_type: number
  display_type: currency
```

### Type Attributes

#### `name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Unique identifier for the type. Used as the `type` value in field definitions.

#### `base_type`

| | |
|---|---|
| **Required** | yes |
| **Type** | string (one of 14 base types) |

The underlying storage type. Must be one of: `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`, `enum`, `file`, `rich_text`, `json`, `uuid`. Determines the database column type.

#### `transforms`

| | |
|---|---|
| **Required** | no |
| **Default** | `[]` |
| **Type** | array of strings |

Ordered list of transform service keys. Each key must be registered in `Services::Registry` under the `"transforms"` category. Transforms are chained in order and applied via `ActiveRecord.normalizes`.

Built-in transforms: `strip`, `downcase`, `normalize_url`, `normalize_phone`.

> **Note:** Fields can also define their own transforms via the `transforms:` attribute. Field-level transforms extend type-level transforms — the union of both is applied, with type-level transforms running first and duplicates removed. For simple cases like adding `strip` to a plain `string` field, field-level transforms may be sufficient without defining a custom type. See [Field-Level Transforms](models.md#transforms).

#### `validations`

| | |
|---|---|
| **Required** | no |
| **Default** | `[]` |
| **Type** | array of validation objects |

Default validations applied to every field that uses this type. Each entry follows the same format as [field-level validations](models.md#validations): a hash with `type` and optional `options`.

If a field explicitly defines a validation of the same `type`, the type-default validation is skipped for that field.

#### `input_type`

| | |
|---|---|
| **Required** | no |
| **Default** | `nil` (falls back to base type) |
| **Type** | string |

HTML input type hint used in form rendering. The form template resolves the input type as: explicit presenter `input_type` > `type_definition.input_type` > base field type.

Supported values: `email`, `tel`, `url`, `color`, `number`, `text`, `date`, `datetime`, `select`, `boolean`, `association_select`.

#### `display_type`

| | |
|---|---|
| **Required** | no |
| **Default** | `nil` |
| **Type** | string |

Display hint for show and index views. Reserved for use by view partials (PR3 of the Type Registry feature).

#### `column_options`

| | |
|---|---|
| **Required** | no |
| **Default** | `{}` |
| **Type** | hash |

Default column options applied to every field that uses this type. Supports `limit`, `precision`, `scale`, `null`. Field-level `column_options` override type-level options.

#### `html_input_attrs`

| | |
|---|---|
| **Required** | no |
| **Default** | `{}` |
| **Type** | hash |

Additional HTML attributes to include on form inputs. Reserved for future use by view partials.

## DSL Type Definition

Define custom types in `config/lcp_ruby/types/<name>.rb`:

```ruby
define_type :currency do
  base_type :decimal
  column_option :precision, 12
  column_option :scale, 2
  transform :strip
  validate :numericality, greater_than_or_equal_to: 0, allow_blank: true
  input_type :number
  display_type :currency
end
```

### DSL Methods

| Method | Maps to | Description |
|--------|---------|-------------|
| `base_type(value)` | `TypeDefinition.base_type` | Set the underlying storage type (required). |
| `transform(key)` | `TypeDefinition.transforms` | Add a transform to the chain. Can be called multiple times. |
| `validate(type, **options)` | `TypeDefinition.validations` | Add a default validation. Can be called multiple times. |
| `input_type(value)` | `TypeDefinition.input_type` | Set the HTML input type hint. |
| `display_type(value)` | `TypeDefinition.display_type` | Set the display type hint. |
| `column_option(key, value)` | `TypeDefinition.column_options` | Add a column option. Can be called multiple times. |
| `html_attr(key, value)` | `TypeDefinition.html_input_attrs` | Add an HTML input attribute. Can be called multiple times. |

### Programmatic Registration

Types can also be registered from an initializer or anywhere in Ruby:

```ruby
LcpRuby.define_type :percentage do
  base_type :decimal
  column_option :precision, 5
  column_option :scale, 2
  transform :strip
  validate :numericality, greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_blank: true
  input_type :number
end
```

## Custom Transforms

To add a custom transform, create a class that inherits from `LcpRuby::Types::Transforms::BaseTransform` and register it in `Services::Registry`:

```ruby
# lib/transforms/titlecase.rb
class TitlecaseTransform < LcpRuby::Types::Transforms::BaseTransform
  def call(value)
    value.respond_to?(:titlecase) ? value.titlecase : value
  end
end

# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  LcpRuby::Services::Registry.register("transforms", "titlecase", TitlecaseTransform.new)
end
```

Then use it in type definitions:

```yaml
type:
  name: proper_name
  base_type: string
  transforms:
    - strip
    - titlecase
```

## Loading Order

Types are loaded before models to ensure all type references can be resolved:

1. Built-in types registered (`BuiltInTypes.register_all!`)
2. Built-in transforms registered (`Services::BuiltInTransforms.register_all!`)
3. User YAML types loaded from `config/lcp_ruby/types/*.yml`
4. User DSL types loaded from `config/lcp_ruby/types/*.rb`
5. Models loaded (fields can now reference any registered type)
6. Presenters loaded
7. Permissions loaded

## Directory Structure

```
config/lcp_ruby/
  types/              # Custom type definitions (optional)
    currency.yml
    percentage.rb
  models/             # Model definitions (reference types by name)
    contact.yml
  presenters/
  permissions/
```

## Complete Example

A custom `currency` type used by a deal model:

**Type definition** (`config/lcp_ruby/types/currency.yml`):

```yaml
type:
  name: currency
  base_type: decimal
  column_options:
    precision: 12
    scale: 2
  transforms:
    - strip
  validations:
    - type: numericality
      options:
        greater_than_or_equal_to: 0
        allow_blank: true
  input_type: number
  display_type: currency
```

**Model using the type** (`config/lcp_ruby/models/invoice.yml`):

```yaml
model:
  name: invoice
  fields:
    - name: number
      type: string
      validations:
        - type: presence
    - name: amount
      type: currency
    - name: tax
      type: currency
    - name: total
      type: currency
      validations:
        - type: presence    # merged with type-default numericality
  options:
    timestamps: true
```

Result:
- All `currency` fields get `decimal(12,2)` columns
- Values are stripped of whitespace on assignment
- Negative values are rejected by the numericality validation
- Forms render `<input type="number">` for currency fields
- The `total` field additionally requires a value (presence validation merged on top)

Source: `lib/lcp_ruby/types/type_registry.rb`, `lib/lcp_ruby/types/type_definition.rb`, `lib/lcp_ruby/types/built_in_types.rb`, `lib/lcp_ruby/services/registry.rb`, `lib/lcp_ruby/services/built_in_transforms.rb`, `lib/lcp_ruby/dsl/type_builder.rb`, `lib/lcp_ruby/model_factory/transform_applicator.rb`
