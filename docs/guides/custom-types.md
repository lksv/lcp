# Custom Types Guide

Custom business types let you define reusable field blueprints — bundling a base storage type with column options, transforms, validations, and input hints. Define a type once, then reference it by name from any model field.

Use custom types when you find yourself repeating the same validation + column options pattern across multiple models.

> **Tip:** For simple normalization (e.g., stripping whitespace from a string field), you may not need a custom type at all. Fields support `transforms:` directly — see [Field-Level Transforms](../reference/models.md#transforms). Use custom types when you need to bundle multiple concerns (transforms + validations + column options + input hints) into a reusable definition.

For the full attribute reference, see [Types Reference](../reference/types.md).

## Example A: `percentage` (YAML)

A percentage type for discount rates, completion progress, or tax rates.

**Type definition** (`config/lcp_ruby/types/percentage.yml`):

```yaml
type:
  name: percentage
  base_type: decimal
  column_options:
    precision: 5
    scale: 2
  transforms:
    - strip
  validations:
    - type: numericality
      options:
        greater_than_or_equal_to: 0
        less_than_or_equal_to: 100
        allow_blank: true
  input_type: number
```

**Model using the type** (`config/lcp_ruby/models/deal.yml`):

```yaml
model:
  name: deal
  fields:
    - name: title
      type: string
      validations:
        - type: presence
    - name: discount_rate
      type: percentage
    - name: probability
      type: percentage
      validations:
        - type: presence
  options:
    timestamps: true
```

Result:
- `discount_rate` and `probability` get `decimal(5,2)` columns
- Values are stripped of whitespace on assignment
- Values outside 0–100 are rejected
- `probability` additionally requires a value (presence merged on top)

## Example B: `postal_code` (YAML)

A postal code type for address fields. Demonstrates format regex, length validation, and a custom error message.

**Type definition** (`config/lcp_ruby/types/postal_code.yml`):

```yaml
type:
  name: postal_code
  base_type: string
  column_options:
    limit: 20
  transforms:
    - strip
  validations:
    - type: format
      options:
        with: "\\A[A-Za-z0-9 -]{3,10}\\z"
        message: "must be a valid postal code"
        allow_blank: true
    - type: length
      options:
        maximum: 20
  input_type: text
```

**Model using the type** (`config/lcp_ruby/models/address.yml`):

```yaml
model:
  name: address
  fields:
    - name: street
      type: string
    - name: city
      type: string
    - name: postal_code
      type: postal_code
      validations:
        - type: presence
    - name: country
      type: string
  options:
    timestamps: true
```

> **Note on YAML regex escaping:** YAML requires doubling backslashes — `"\\A"` in YAML becomes `\A` in Ruby. See the [Types Reference](../reference/types.md#validations) for details.

## Example C: `slug` (DSL)

A URL-friendly identifier type. Demonstrates multiple chained transforms and uniqueness validation.

**Type definition** (`config/lcp_ruby/types/slug.rb`):

```ruby
define_type :slug do
  base_type :string
  column_option :limit, 100
  transform :strip
  transform :downcase
  validate :format, with: '\A[a-z0-9]+(-[a-z0-9]+)*\z',
                    message: "must contain only lowercase letters, digits, and hyphens",
                    allow_blank: true
  validate :length, maximum: 100
  validate :uniqueness, case_sensitive: false
  input_type :text
end
```

**Model using the type** (`config/lcp_ruby/types/article.rb`):

```ruby
define_model :article do
  field :title, :string do
    validates :presence
  end

  field :slug, :slug do
    validates :presence
  end

  field :body, :text

  options timestamps: true
end
```

Result:
- `slug` gets a `string(100)` column
- Values are stripped and lowercased on assignment
- Only lowercase alphanumeric characters and hyphens are accepted
- Slugs must be unique (case-insensitive)

> **Tip:** For automatic slug generation from the title, you could create a custom `slugify` transform. See [Custom Transforms](../reference/types.md#custom-transforms) for how to register custom transform services.

## Example D: `hex_color` (DSL)

An extended color type that accepts short hex notation (`#RGB`) and alpha channels (`#RRGGBBAA`), unlike the built-in `color` type which only accepts 6-digit hex (`#RRGGBB`).

**Type definition** (`config/lcp_ruby/types/hex_color.rb`):

```ruby
define_type :hex_color do
  base_type :string
  column_option :limit, 9
  transform :strip
  transform :downcase
  validate :format, with: '\A#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})\z',
                    message: "must be a hex color (#RGB, #RRGGBB, or #RRGGBBAA)",
                    allow_blank: true
  input_type :color
  display_type :color_swatch
end
```

**Comparison with built-in `color`:**

| | Built-in `color` | Custom `hex_color` |
|---|---|---|
| Accepts `#RRGGBB` | Yes | Yes |
| Accepts `#RGB` shorthand | No | Yes |
| Accepts `#RRGGBBAA` alpha | No | Yes |
| Column limit | 7 | 9 |

**Model using the type** (`config/lcp_ruby/types/theme.rb`):

```ruby
define_model :theme do
  field :name, :string do
    validates :presence
    validates :uniqueness
  end

  field :primary_color, :hex_color do
    validates :presence
  end

  field :secondary_color, :hex_color
  field :background_color, :hex_color

  options timestamps: true
end
```

## What's Next

- [Types Reference](../reference/types.md) — Full attribute reference for type definitions
- [Custom Transforms](../reference/types.md#custom-transforms) — Creating custom transform services
- [Models Reference](../reference/models.md) — Field definitions that consume types
