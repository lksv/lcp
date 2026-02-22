# Design: Array Field Type

**Status:** Proposed
**Date:** 2026-02-21

## Problem

The platform currently has no native support for multi-valued scalar fields. When a model needs to store a list of strings (tags, labels, categories), integers (IDs, scores), or floats (coordinates, weights), the only options are:

1. **has_many :through** — requires a join model, join table, and presenter boilerplate for each taggable field
2. **JSON field** — untyped, no item-level validation, no DB-level query operators
3. **Comma-separated string** — not queryable, fragile parsing

All three are workarounds. The platform should support `type: array` as a first-class field type with typed items, proper validation, DB-portable query operators, and form/display integration.

## Goals

- Add `array` as a new base field type with a required `item_type` property
- Store as native `text[]`/`integer[]` on PostgreSQL, `json` on SQLite (transparent to the user)
- Provide array-specific validations: length, inclusion, uniqueness of items
- Provide array-specific query scopes: `contains`, `contained_by`, `overlaps`
- Implement both PG-native and SQLite `json_each()`-based query strategies
- Add form input for array fields (tag-style chips with add/remove)
- Default to the existing `collection` renderer for display
- Integrate with `ConditionEvaluator` (new `contains` / `not_contains` operators)
- Support array fields in the DSL, JSON schema, and `ConfigurationValidator`
- Support array fields as a custom field type (future, out of scope for v1)

## Non-Goals

- Arrays of complex objects (use `json` type for that)
- Nested arrays (array of arrays)
- Array fields as association targets (use has_many :through for relational data)
- Custom field definitions with `type: array` (can be added later)

## Design

### YAML Configuration

```yaml
# config/lcp_ruby/models/article.yml
fields:
  - name: tags
    type: array
    item_type: string
    default: []

  - name: scores
    type: array
    item_type: integer
    validations:
      - type: array_length
        options:
          maximum: 10
      - type: array_inclusion
        options:
          in: [1, 2, 3, 4, 5]

  - name: coordinates
    type: array
    item_type: float
    validations:
      - type: array_length
        options:
          minimum: 2
          maximum: 2
```

### DSL Configuration

```ruby
define_model :article do
  field :tags, :array, item_type: :string, default: []
  field :scores, :array, item_type: :integer do
    validates :array_length, maximum: 10
    validates :array_inclusion, in: [1, 2, 3, 4, 5]
  end
end
```

### Supported `item_type` Values

| item_type  | PG column          | SQLite column | Ruby cast  |
|------------|--------------------|---------------|------------|
| `string`   | `text[]`           | `json`        | `to_s`     |
| `integer`  | `integer[]`        | `json`        | `to_i`     |
| `float`    | `float[]`          | `json`        | `to_f`     |

Only scalar item types are supported. `item_type` is required when `type: array`.

### Presenter Configuration

```yaml
# Form: tag-style input
form:
  sections:
    - fields:
        - field: tags
          input_type: array_input  # default for array fields
          input_options:
            placeholder: "Add tag..."
            max: 20                # max number of items
            allow_custom: true     # allow free-form input (default: true)
            suggestions:           # optional static suggestions
              - ruby
              - rails
              - javascript

# Display: uses collection renderer by default
table_columns:
  - field: tags
    renderer: collection
    options:
      item_renderer: badge
      separator: " "
```

When no explicit `input_type` is set for an array field, the engine defaults to `array_input`. When no explicit `renderer` is set, the engine defaults to `collection`.

## Implementation

### 1. `Metadata::FieldDefinition`

Add `item_type` attribute and `array?` predicate:

```ruby
BASE_TYPES = %w[
  string text integer float decimal boolean
  date datetime enum file rich_text json uuid
  attachment array
].freeze

attr_reader :name, :type, :label, :column_options, :validations,
            :enum_values, :default, :type_definition, :transforms, :computed,
            :attachment_options, :source, :item_type

def initialize(attrs = {})
  # ...existing...
  @item_type = attrs[:item_type]&.to_s
  validate!
  resolve_type_definition!
end

def self.from_hash(hash)
  new(
    # ...existing...
    item_type: hash["item_type"]
  )
end

def array?
  type == "array"
end

private

def validate!
  # ...existing validations...
  if array?
    unless %w[string integer float].include?(@item_type)
      raise MetadataError,
        "Field '#{@name}': array type requires item_type (string, integer, or float)"
    end
  end
end
```

### 2. `schemas/model.json`

Add `item_type` to the field definition and `array` to valid types:

```json
"field": {
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "type": { "type": "string" },
    "item_type": {
      "type": "string",
      "enum": ["string", "integer", "float"]
    },
    ...
  },
  "required": ["name", "type"],
  "allOf": [
    {
      "if": { "properties": { "type": { "const": "array" } } },
      "then": { "required": ["item_type"] }
    }
  ]
}
```

### 3. `ModelFactory::SchemaManager`

#### Column creation

```ruby
def add_column_to_table(t, field)
  options = build_column_options(field)
  col_type = field.column_type
  t.column field.name, col_type, **options
end
```

`FieldDefinition#column_type` handles the array case:

```ruby
def column_type
  return nil if attachment?
  return nil if virtual?

  if array?
    if LcpRuby.postgresql?
      # PG native array — actual DB type determined by item_type
      pg_array_column_type
    else
      # SQLite/MySQL — store as JSON
      LcpRuby.json_column_type
    end
  elsif @type_definition
    @type_definition.column_type
  else
    # ...existing switch...
  end
end

private

def pg_array_column_type
  case item_type
  when "string"  then :text
  when "integer" then :integer
  when "float"   then :float
  end
end
```

`SchemaManager#build_column_options` adds the `array: true` flag for PG:

```ruby
def build_column_options(field)
  options = {}
  # ...existing option building...

  if field.array?
    if LcpRuby.postgresql?
      options[:array] = true
      options[:default] = field.default || []
    else
      options[:default] = (field.default || []).to_json
    end
  else
    options[:default] = field.default if field.default && !field.default.is_a?(Hash)
  end

  options
end
```

### 4. `ModelFactory::ArrayTypeApplicator` (new)

New applicator that registers an `ActiveRecord::Type` cast for SQLite array fields and applies array-specific attribute declarations:

```ruby
module LcpRuby
  module ModelFactory
    class ArrayTypeApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.fields.select(&:array?).each do |field|
          if LcpRuby.postgresql?
            apply_pg_array(field)
          else
            apply_json_array(field)
          end
        end
      end

      private

      def apply_pg_array(field)
        # PG arrays work natively — ActiveRecord handles text[], integer[], float[]
        # Just ensure the default is set correctly
        field_name = field.name.to_sym
        @model_class.attribute field_name, default: field.default || []
      end

      def apply_json_array(field)
        # SQLite/MySQL: JSON column needs a custom type to cast between
        # Ruby Array and JSON string transparently
        field_name = field.name.to_sym
        item_type = field.item_type

        @model_class.attribute field_name, ArrayType.new(item_type), default: field.default || []
      end
    end
  end
end
```

#### `ArrayType` — custom ActiveRecord type for non-PG databases

```ruby
module LcpRuby
  module ModelFactory
    class ArrayType < ActiveRecord::Type::Value
      def initialize(item_type = "string")
        @item_type = item_type
        super()
      end

      def type
        :lcp_array
      end

      # Deserialize from DB (JSON string → Ruby Array)
      def deserialize(value)
        case value
        when String
          parsed = JSON.parse(value)
          parsed.is_a?(Array) ? cast_items(parsed) : []
        when Array
          cast_items(value)
        else
          []
        end
      rescue JSON::ParserError
        []
      end

      # Cast from user input (form params, assignment)
      def cast(value)
        case value
        when Array then cast_items(value.reject(&:blank?))
        when String
          # Try JSON parse first, fall back to comma-split
          parsed = JSON.parse(value) rescue nil
          if parsed.is_a?(Array)
            cast_items(parsed)
          else
            cast_items(value.split(",").map(&:strip).reject(&:blank?))
          end
        when nil then []
        else [cast_item(value)]
        end
      end

      # Serialize to DB (Ruby Array → JSON string)
      def serialize(value)
        arr = value.is_a?(Array) ? value : []
        arr.to_json
      end

      def changed_in_place?(raw_old_value, new_value)
        deserialize(raw_old_value) != new_value
      end

      private

      def cast_items(items)
        items.map { |item| cast_item(item) }
      end

      def cast_item(item)
        case @item_type
        when "integer" then item.to_i
        when "float"   then item.to_f
        else item.to_s
        end
      end
    end
  end
end
```

### 5. `ModelFactory::Builder`

Add the new applicator to the pipeline, after `apply_enums` and before `apply_validations`:

```ruby
def build
  model_class = create_model_class
  apply_table_name(model_class)
  apply_enums(model_class)
  apply_array_types(model_class)    # <-- new
  apply_validations(model_class)
  # ...rest unchanged...
end

def apply_array_types(model_class)
  ArrayTypeApplicator.new(model_class, model_definition).apply!
end
```

The applicator runs early because validations and transforms may depend on the attribute being properly typed.

### 6. Array-Specific Validations

New validation types in `ValidationApplicator`:

```ruby
# In apply_standard_validation:
when "array_length"
  apply_array_length_validation(field_name, opts)
when "array_inclusion"
  apply_array_inclusion_validation(field_name, opts)
when "array_uniqueness"
  apply_array_uniqueness_validation(field_name, opts)
```

```ruby
def apply_array_length_validation(field_name, opts)
  min = opts[:minimum]
  max = opts[:maximum]
  message = opts[:message]

  @model_class.validate do |record|
    value = Array(record.send(field_name))
    if min && value.size < min
      record.errors.add(field_name, message || "must have at least #{min} items")
    end
    if max && value.size > max
      record.errors.add(field_name, message || "must have at most #{max} items")
    end
  end
end

def apply_array_inclusion_validation(field_name, opts)
  allowed = opts[:in] || opts[:within] || []
  message = opts[:message]

  @model_class.validate do |record|
    value = Array(record.send(field_name))
    invalid = value - allowed.map(&:to_s)
    if invalid.any?
      record.errors.add(field_name, message || "contains invalid values: #{invalid.join(', ')}")
    end
  end
end

def apply_array_uniqueness_validation(field_name, opts)
  message = opts[:message]

  @model_class.validate do |record|
    value = Array(record.send(field_name))
    if value.size != value.uniq.size
      record.errors.add(field_name, message || "must not contain duplicate values")
    end
  end
end
```

Update the JSON schema to include the new validation types:

```json
"type": {
  "enum": [
    "presence", "length", "numericality", "format",
    "inclusion", "exclusion", "uniqueness", "confirmation",
    "custom", "comparison", "service",
    "array_length", "array_inclusion", "array_uniqueness"
  ]
}
```

### 7. Array Query Scopes — `ArrayQuery`

New query helper following the pattern established by `CustomFields::Query`:

```ruby
module LcpRuby
  class ArrayQuery
    class << self
      # Records where the array field contains ALL of the given values.
      # SQL: PG `@>`, SQLite `json_each` with COUNT match.
      def contains(scope, table_name, field_name, values)
        values = Array(values)
        return scope if values.empty?

        conn = ActiveRecord::Base.connection
        quoted_table = conn.quote_table_name(table_name)
        quoted_field = conn.quote_column_name(field_name)

        condition = if LcpRuby.postgresql?
          # PG: tags @> ARRAY['ruby','rails']::text[]
          array_literal = pg_array_literal(values, conn)
          "#{quoted_table}.#{quoted_field} @> #{array_literal}"
        else
          # SQLite: every value must appear in json_each()
          # SELECT ... WHERE (
          #   SELECT COUNT(DISTINCT je.value) FROM json_each(table.field) je
          #   WHERE je.value IN ('ruby','rails')
          # ) = 2
          in_list = values.map { |v| conn.quote(v.to_s) }.join(", ")
          "(SELECT COUNT(DISTINCT je.value) FROM json_each(#{quoted_table}.#{quoted_field}) je " \
            "WHERE je.value IN (#{in_list})) = #{values.size}"
        end

        scope.where(Arel.sql(condition))
      end

      # Records where the array field contains ANY of the given values.
      # SQL: PG `&&`, SQLite `json_each` with EXISTS.
      def overlaps(scope, table_name, field_name, values)
        values = Array(values)
        return scope.none if values.empty?

        conn = ActiveRecord::Base.connection
        quoted_table = conn.quote_table_name(table_name)
        quoted_field = conn.quote_column_name(field_name)

        condition = if LcpRuby.postgresql?
          array_literal = pg_array_literal(values, conn)
          "#{quoted_table}.#{quoted_field} && #{array_literal}"
        else
          in_list = values.map { |v| conn.quote(v.to_s) }.join(", ")
          "EXISTS (SELECT 1 FROM json_each(#{quoted_table}.#{quoted_field}) je " \
            "WHERE je.value IN (#{in_list}))"
        end

        scope.where(Arel.sql(condition))
      end

      # Records where the array field is a subset of the given values.
      # SQL: PG `<@`, SQLite `json_each` with NOT EXISTS of unmatched.
      def contained_by(scope, table_name, field_name, values)
        values = Array(values)
        return scope if values.empty?

        conn = ActiveRecord::Base.connection
        quoted_table = conn.quote_table_name(table_name)
        quoted_field = conn.quote_column_name(field_name)

        condition = if LcpRuby.postgresql?
          array_literal = pg_array_literal(values, conn)
          "#{quoted_table}.#{quoted_field} <@ #{array_literal}"
        else
          in_list = values.map { |v| conn.quote(v.to_s) }.join(", ")
          "NOT EXISTS (SELECT 1 FROM json_each(#{quoted_table}.#{quoted_field}) je " \
            "WHERE je.value NOT IN (#{in_list}))"
        end

        scope.where(Arel.sql(condition))
      end

      # Size of the array.
      # SQL: PG `array_length()`, SQLite `json_array_length()`.
      def array_length_expression(table_name, field_name)
        conn = ActiveRecord::Base.connection
        quoted_table = conn.quote_table_name(table_name)
        quoted_field = conn.quote_column_name(field_name)

        if LcpRuby.postgresql?
          "COALESCE(array_length(#{quoted_table}.#{quoted_field}, 1), 0)"
        else
          "json_array_length(#{quoted_table}.#{quoted_field})"
        end
      end

      private

      def pg_array_literal(values, conn)
        escaped = values.map { |v| conn.quote(v.to_s) }.join(", ")
        "ARRAY[#{escaped}]::text[]"
      end
    end
  end
end
```

### 8. Declarative Array Scopes via YAML

Array fields automatically get generated scopes for common queries. The `ScopeApplicator` is extended to recognize a new `type: array_contains` scope pattern:

```yaml
# Auto-generated (no YAML needed):
scopes:
  - name: with_tag
    type: array_contains
    field: tags          # inferred from field name
```

`ScopeApplicator` generates these automatically for every array field:

```ruby
def apply!
  @model_definition.scopes.each { |sc| apply_scope(sc) }
  apply_array_scopes  # <-- new
end

def apply_array_scopes
  table = @model_definition.table_name
  @model_definition.fields.select(&:array?).each do |field|
    field_name = field.name

    # Model.with_<field>(values) — contains ALL values
    @model_class.scope :"with_#{field_name}", ->(values) {
      ArrayQuery.contains(all, table, field_name, Array(values))
    }

    # Model.with_any_<field>(values) — contains ANY value
    @model_class.scope :"with_any_#{field_name}", ->(values) {
      ArrayQuery.overlaps(all, table, field_name, Array(values))
    }
  end
end
```

Example usage:

```ruby
Article.with_tags(["ruby", "rails"])       # articles with BOTH tags
Article.with_any_tags(["ruby", "python"])   # articles with EITHER tag
```

### 9. `ConditionEvaluator`

Add array-aware operators for `visible_when` / `disable_when`:

```ruby
# In evaluate():
when "contains"
  # actual is an array, value is a single item or array
  arr = Array(actual)
  Array(value).all? { |v| arr.map(&:to_s).include?(v.to_s) }
when "not_contains"
  arr = Array(actual)
  Array(value).none? { |v| arr.map(&:to_s).include?(v.to_s) }
when "any_of"
  arr = Array(actual)
  Array(value).any? { |v| arr.map(&:to_s).include?(v.to_s) }
when "empty"
  Array(actual).empty?
when "not_empty"
  Array(actual).any?
```

These operators also work with the existing `present` / `blank` operators since `Array([])` is blank.

Update `VALID_CONDITION_OPERATORS` in `ConfigurationValidator`:

```ruby
VALID_CONDITION_OPERATORS = %w[
  eq not_eq neq in not_in gt gte lt lte present blank
  matches not_matches contains not_contains any_of empty not_empty
].freeze
```

### 10. Form Input — `array_input`

New input type in `FormHelper`:

```ruby
when "array_input"
  render_array_input(form, field_name, field_config, field_def)
```

```ruby
def render_array_input(form, field_name, field_config, field_def)
  input_options = field_config["input_options"] || {}
  current_value = Array(form.object&.send(field_name))
  placeholder = input_options["placeholder"] || I18n.t("lcp_ruby.array_input.placeholder", default: "Add item...")
  max = input_options["max"]
  suggestions = input_options["suggestions"] || []

  data_attrs = { lcp_array_input: true }
  data_attrs["lcp-max"] = max if max
  data_attrs["lcp-suggestions"] = suggestions.to_json if suggestions.any?

  content_tag(:div, class: "lcp-array-input-wrapper", data: data_attrs) do
    parts = ActiveSupport::SafeBuffer.new

    # Hidden field to submit the array as JSON
    parts << form.hidden_field(field_name,
      value: current_value.to_json,
      data: { lcp_array_value: true })

    # Tag chips container
    parts << content_tag(:div, class: "lcp-array-chips", data: { lcp_array_chips: true }) {
      safe_join(current_value.map { |item|
        content_tag(:span, class: "lcp-array-chip") do
          content_tag(:span, item.to_s, class: "lcp-array-chip-text") +
            content_tag(:button, "\u00d7", type: "button", class: "lcp-array-chip-remove",
              data: { lcp_array_remove: item.to_s })
        end
      })
    }

    # Text input for adding new items
    parts << tag(:input, type: "text", class: "lcp-array-text-input",
      placeholder: placeholder,
      data: { lcp_array_text_input: true })

    parts
  end
end
```

The JavaScript behavior (adding/removing chips, updating the hidden field) is handled by the Stimulus controller or inline JS that the platform already uses for other interactive inputs. The hidden field submits the array as a JSON string, which the `ArrayType` cast handles on the server side.

### 11. Permitted Params in `ResourcesController`

Array fields must be permitted as JSON strings (from the hidden field) or as arrays. Extend the `permitted_params` method:

```ruby
# In permitted_params, after multi_select detection:
# Detect array fields and permit them as scalar (JSON string from hidden field)
layout_builder.form_sections
  .flat_map { |s| s["fields"] || [] }
  .select { |f| f["input_type"] == "array_input" || current_model_definition.field(f["field"])&.array? }
  .each { |f| flat_fields << f["field"].to_sym unless flat_fields.include?(f["field"].to_sym) }
```

Array fields are permitted as scalar strings (the hidden field contains JSON). The `ArrayType#cast` method handles deserialization from the JSON string to a Ruby array.

### 12. Default Renderer Assignment

`Presenter::LayoutBuilder` should default array fields to the `collection` renderer when no explicit renderer is set:

```ruby
# In normalize_column / normalize_field:
if field_def&.array? && !col.key?("renderer")
  col["renderer"] = "collection"
end
```

And for form fields, default to `array_input`:

```ruby
# In normalize_form_field:
if field_def&.array? && !field_config.key?("input_type")
  field_config["input_type"] = "array_input"
end
```

### 13. `Dsl::ModelBuilder`

Add `item_type` support:

```ruby
def field(name, type, **options, &block)
  field_hash = {
    "name" => name.to_s,
    "type" => type.to_s
  }

  field_hash["item_type"] = options[:item_type].to_s if options.key?(:item_type)
  # ...rest unchanged...
end
```

### 14. `ConfigurationValidator`

Add array field validation:

```ruby
def validate_model_fields(model)
  model.fields.each do |field|
    validate_enum_field(model, field) if field.enum?
    validate_virtual_field(model, field) if field.virtual?
    validate_array_field(model, field) if field.array?
  end
end

def validate_array_field(model, field)
  unless %w[string integer float].include?(field.item_type)
    @errors << "Model '#{model.name}', field '#{field.name}': " \
               "array field requires item_type (string, integer, or float), " \
               "got '#{field.item_type}'"
  end

  if field.default && !field.default.is_a?(Array)
    @errors << "Model '#{model.name}', field '#{field.name}': " \
               "array field default must be an array, got #{field.default.class}"
  end
end
```

### 15. Search Integration

In `ApplicationController#apply_search`, array string fields should participate in text search:

```ruby
# In apply_search:
array_string_fields = model_definition.fields
  .select { |f| f.array? && f.item_type == "string" }
  .map(&:name)

array_string_fields.each do |field_name|
  # PG: field @> ARRAY[query]
  # SQLite: EXISTS (SELECT 1 FROM json_each(field) WHERE value LIKE ...)
  conditions << ArrayQuery.text_search_condition(table_name, field_name, query)
end
```

```ruby
# New method in ArrayQuery:
def self.text_search_condition(table_name, field_name, query)
  conn = ActiveRecord::Base.connection
  quoted_table = conn.quote_table_name(table_name)
  quoted_field = conn.quote_column_name(field_name)
  quoted_query = conn.quote("%#{query}%")

  if LcpRuby.postgresql?
    "EXISTS (SELECT 1 FROM unnest(#{quoted_table}.#{quoted_field}) item " \
      "WHERE item ILIKE #{quoted_query})"
  else
    "EXISTS (SELECT 1 FROM json_each(#{quoted_table}.#{quoted_field}) je " \
      "WHERE je.value LIKE #{quoted_query})"
  end
end
```

## Components Requiring No Changes

| Component | Why it works |
|---|---|
| **PermissionEvaluator** | `readable_fields` / `writable_fields` reference field names — array fields are just strings |
| **FieldValueResolver** | Calls `record.send(field_name)` — returns the Ruby Array |
| **Display::Renderers::Collection** | Already handles `Array(value)` and renders with separator and item_renderer |
| **TransformApplicator** | Skipped for virtual fields; for array fields, transforms would apply to the whole array (not useful, but harmless) |
| **DefaultApplicator** | Array defaults (`[]`) are handled by `build_column_options` for DB-backed columns and by `attribute default:` for the AR type |

## File Changes Summary

| File | Change |
|------|--------|
| `lib/lcp_ruby/metadata/field_definition.rb` | Add `item_type` attr, `array?` predicate, column_type logic |
| `lib/lcp_ruby/schemas/model.json` | Add `item_type` property, conditional requirement, new validation types |
| `lib/lcp_ruby/model_factory/array_type_applicator.rb` | **New** — registers AR attribute type |
| `lib/lcp_ruby/model_factory/array_type.rb` | **New** — custom AR::Type for SQLite JSON serialization |
| `lib/lcp_ruby/model_factory/builder.rb` | Add `apply_array_types` to pipeline |
| `lib/lcp_ruby/model_factory/schema_manager.rb` | Handle `array: true` column option for PG |
| `lib/lcp_ruby/model_factory/validation_applicator.rb` | Add `array_length`, `array_inclusion`, `array_uniqueness` |
| `lib/lcp_ruby/model_factory/scope_applicator.rb` | Auto-generate `with_<field>` / `with_any_<field>` scopes |
| `lib/lcp_ruby/array_query.rb` | **New** — DB-portable array query helpers |
| `lib/lcp_ruby/condition_evaluator.rb` | Add `contains`, `not_contains`, `any_of`, `empty`, `not_empty` operators |
| `lib/lcp_ruby/dsl/model_builder.rb` | Pass through `item_type` |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Validate array fields, new condition operators |
| `app/helpers/lcp_ruby/form_helper.rb` | Add `array_input` renderer |
| `app/controllers/lcp_ruby/resources_controller.rb` | Permit array fields in params |
| `app/controllers/lcp_ruby/application_controller.rb` | Include array fields in text search |
| `lib/lcp_ruby/presenter/layout_builder.rb` | Default renderer/input_type for array fields |

## Examples

### Tags on Articles

```yaml
# models/article.yml
name: article
fields:
  - name: title
    type: string
    validations:
      - type: presence
  - name: tags
    type: array
    item_type: string
    default: []
    validations:
      - type: array_length
        options: { maximum: 10 }
      - type: array_uniqueness
```

```yaml
# presenters/articles.yml
model: article
slug: articles
table_columns:
  - field: title
  - field: tags
    renderer: collection
    options:
      item_renderer: badge
      separator: " "
form:
  sections:
    - title: Details
      fields:
        - field: title
        - field: tags
          input_options:
            placeholder: "Add tag..."
            suggestions: [news, tutorial, review, opinion]
search:
  searchable_fields: [title, tags]
```

### Conditional Rendering Based on Array Content

```yaml
form:
  sections:
    - title: Review Settings
      visible_when:
        field: tags
        operator: contains
        value: review
      fields:
        - field: review_score
```

### Querying in Code

```ruby
# All articles tagged with both "ruby" AND "rails"
Article.with_tags(["ruby", "rails"])

# All articles tagged with "ruby" OR "python"
Article.with_any_tags(["ruby", "python"])

# Using ArrayQuery directly
ArrayQuery.contains(Article.all, "articles", "tags", ["ruby"])
ArrayQuery.overlaps(Article.all, "articles", "tags", ["ruby", "python"])
```

## Migration / Compatibility

- **Additive feature** — no changes to existing models or fields
- **No database migration needed** — columns created at boot by SchemaManager
- **No breaking changes** — existing `json` fields continue to work as before
- **PG ↔ SQLite transparency** — same YAML works on both databases; only the storage and query strategy differs

## Test Plan

1. **FieldDefinition** — `array?`, `item_type`, `column_type` for PG and SQLite, validation of missing `item_type`
2. **ArrayType (custom AR type)** — `cast`, `deserialize`, `serialize` round-trip for string/integer/float items
3. **SchemaManager** — PG creates `text[]` column with `array: true`; SQLite creates `json` column
4. **ArrayTypeApplicator** — PG uses native attribute; SQLite registers custom type
5. **ValidationApplicator** — `array_length` (min/max), `array_inclusion`, `array_uniqueness`
6. **ArrayQuery** — `contains`, `overlaps`, `contained_by`, `text_search_condition` on both PG and SQLite (SQLite tests use `json_each`)
7. **ScopeApplicator** — auto-generated `with_<field>` and `with_any_<field>` scopes
8. **ConditionEvaluator** — `contains`, `not_contains`, `any_of`, `empty`, `not_empty` operators
9. **FormHelper** — `array_input` renders chips, hidden field, text input
10. **ResourcesController** — array fields permitted in params, JSON string cast to array
11. **LayoutBuilder** — default renderer (`collection`) and input_type (`array_input`) for array fields
12. **ConfigurationValidator** — catches missing `item_type`, invalid `item_type`, non-array default
13. **Integration** — full CRUD cycle with array fields (create with tags, display in index/show, edit, update, search)
14. **DSL** — `field :tags, :array, item_type: :string` works
15. **JSON Schema** — validates `item_type` is required when `type: array`

### SQLite-Specific Test Notes

All `ArrayQuery` tests run on SQLite in the default test suite using `json_each()`. PG-specific tests (native `@>`, `&&` operators, `text[]` column creation) can be gated with:

```ruby
before { skip "PostgreSQL only" unless LcpRuby.postgresql? }
```

## Open Questions

1. **Should `item_type: decimal` be supported?** Decimals have precision/scale concerns that complicate array storage. Omitted for now — can be added later if needed.

2. **Should transforms apply to individual array items?** Currently transforms run on the whole field value. For arrays, it could be useful to strip/downcase each item (e.g., tag normalization). This could be a `before_validation` callback that maps transforms over items. Deferred to a follow-up.

3. **GIN index for PG array columns?** PG arrays benefit from GIN indexes for `@>` and `&&` queries. Should the engine auto-create GIN indexes for array fields (like it does for `custom_data` JSONB)? Recommendation: yes, opt-in via `column_options: { index: gin }`.
