# Design: External Field Accessors

**Status:** Implemented
**Date:** 2026-02-20

## Problem

Users need to expose virtual fields on dynamic models that are not backed by their own database column. The primary use case is editing individual keys within a JSON column as regular form fields, but the mechanism should be general-purpose (e.g., data from an external API, computed aggregations, delegated attributes).

Currently, every field defined in model YAML maps 1:1 to a database column. There is no way to declare a field whose getter/setter is implemented by the host application.

## Goals

- Allow declaring fields that have no database column
- Provide a mechanism for host apps to supply getter/setter logic
- Reuse all existing infrastructure: presenter (form/show), permissions, validations, search, conditions
- Follow the established service-based extensibility pattern

## Non-Goals

- Runtime user-defined virtual fields (covered by Custom Fields)
- Automatic JSON schema validation (can be added later)
- Two-way data binding or client-side reactivity for virtual fields

## Design

### New `source` attribute on FieldDefinition

A field with `source` is **virtual** - the engine skips database column creation but registers a full `FieldDefinition`. Two forms are supported:

#### Form A: `source: external`

The host application provides getter/setter implementation manually (via initializer, concern, or any Ruby mechanism).

```yaml
# config/lcp_ruby/models/order.yml
fields:
  - name: metadata
    type: json

  - name: shipping_address
    type: string
    source: external

  - name: priority
    type: integer
    source: external
    validations:
      - type: numericality
        options:
          greater_than_or_equal_to: 1
          less_than_or_equal_to: 5
```

Host app provides implementation:

```ruby
# config/initializers/lcp_ruby_extensions.rb
Rails.application.config.after_initialize do
  LcpRuby::Dynamic::Order.class_eval do
    def shipping_address
      metadata&.dig("shipping_address")
    end

    def shipping_address=(value)
      self.metadata = (metadata || {}).merge("shipping_address" => value)
    end

    def priority
      metadata&.dig("priority")
    end

    def priority=(value)
      self.metadata = (metadata || {}).merge("priority" => value)
    end
  end
end
```

The engine:
1. Skips column creation in `SchemaManager`
2. Registers a full `FieldDefinition` (type, validations, label, etc.)
3. At boot time, validates that the model responds to `field_name` and `field_name=` — raises `MetadataError` if missing

#### Form B: `source: { service: "<name>", options: {...} }`

The engine auto-generates getter/setter by delegating to an **accessor service** (new service category).

```yaml
fields:
  - name: metadata
    type: json

  - name: shipping_address
    type: string
    source:
      service: json_field
      options:
        column: metadata
        key: shipping_address

  - name: priority
    type: integer
    source:
      service: json_field
      options:
        column: metadata
        key: priority
```

The accessor service:

```ruby
# app/lcp_services/accessors/json_field.rb
module LcpRuby
  module HostServices
    module Accessors
      class JsonField
        def self.get(record, options:)
          record.send(options["column"])&.dig(options["key"])
        end

        def self.set(record, value, options:)
          col = options["column"]
          data = record.send(col) || {}
          record.send("#{col}=", data.merge(options["key"] => value))
        end
      end
    end
  end
end
```

The engine:
1. Looks up the service via `Services::Registry.lookup("accessors", "json_field")`
2. Generates getter/setter via `define_method` in a new `ServiceAccessorApplicator`
3. Validates service existence at boot time

### Model DSL support

Both forms work in the Ruby DSL:

```ruby
define_model :order do
  field :metadata, :json

  # Form A
  field :shipping_address, :string, source: :external

  # Form B
  field :priority, :integer, source: { service: "json_field", options: { column: "metadata", key: "priority" } }
end
```

## Implementation

### Changes by component

#### 1. `Metadata::FieldDefinition`

Add `source` attribute:

```ruby
attr_reader :name, :type, :label, :column_options, :validations,
            :enum_values, :default, :type_definition, :transforms, :computed,
            :attachment_options, :source   # <-- new

def initialize(attrs = {})
  # ...
  @source = attrs[:source]
end

def self.from_hash(hash)
  new(
    # ...existing...
    source: hash["source"]
  )
end

def virtual?
  source.present?
end

def external?
  source == "external" || source == :external
end

def service_accessor?
  source.is_a?(Hash) && source.key?("service")
end
```

#### 2. `ModelFactory::SchemaManager`

Skip column creation for virtual fields:

```ruby
# In create_table!
fields.each do |field|
  next if field.attachment?
  next if field.virtual?       # <-- new
  add_column_to_table(t, field)
end

# In update_table!
model_definition.fields.each do |field|
  next if field.attachment?
  next if field.virtual?       # <-- new
  # ...
end
```

#### 3. `ModelFactory::ServiceAccessorApplicator` (new)

New applicator that handles service-based accessor fields:

```ruby
module LcpRuby
  module ModelFactory
    class ServiceAccessorApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.fields.select(&:service_accessor?).each do |field|
          apply_service_accessor(field)
        end
      end

      private

      def apply_service_accessor(field)
        service_key = field.source["service"]
        options = (field.source["options"] || {}).freeze
        service = Services::Registry.lookup("accessors", service_key)

        unless service
          raise MetadataError,
            "Model '#{@model_definition.name}', field '#{field.name}': " \
            "accessor service '#{service_key}' not found"
        end

        field_name = field.name

        @model_class.define_method(field_name) do
          service.get(self, options: options)
        end

        @model_class.define_method("#{field_name}=") do |value|
          service.set(self, value, options: options)
        end
      end
    end
  end
end
```

#### 4. `ModelFactory::Builder`

Add the new applicator to the build pipeline:

```ruby
def build
  model_class = create_model_class
  apply_table_name(model_class)
  apply_enums(model_class)
  apply_validations(model_class)
  apply_transforms(model_class)
  apply_associations(model_class)
  apply_attachments(model_class)
  apply_scopes(model_class)
  apply_callbacks(model_class)
  apply_defaults(model_class)
  apply_computed(model_class)
  apply_external_fields(model_class)   # <-- new, after computed
  apply_custom_fields(model_class)
  apply_label_method(model_class)
  model_class
end

def apply_external_fields(model_class)
  ServiceAccessorApplicator.new(model_class, model_definition).apply!
end
```

#### 5. `Services::Registry`

Add `accessors` to valid categories:

```ruby
VALID_CATEGORIES = %w[
  transforms validators conditions defaults computed data_providers
  accessors
].freeze
```

#### 6. `Metadata::ConfigurationValidator`

Add boot-time validation for external fields:

```ruby
def validate_model_fields(model)
  model.fields.each do |field|
    validate_enum_field(model, field) if field.enum?
    validate_external_field(model, field) if field.virtual?
  end
end

def validate_external_field(model, field)
  if field.service_accessor?
    service_key = field.source["service"]
    unless Services::Registry.registered?("accessors", service_key)
      @errors << "Model '#{model.name}', field '#{field.name}': " \
                 "accessor service '#{service_key}' not found"
    end

    options = field.source["options"]
    if options.is_a?(Hash) && options["column"]
      col = options["column"]
      unless model.field(col)
        @errors << "Model '#{model.name}', field '#{field.name}': " \
                   "source references column '#{col}' which is not a defined field"
      end
    end
  end
end
```

For `source: external`, validation that the model `method_defined?(:field_name)` cannot happen in `ConfigurationValidator` (which runs before model classes are built). Instead, a post-build check runs after `Builder.build`:

```ruby
# In Builder.build, after all applicators:
validate_external_methods!(model_class)

def validate_external_methods!(model_class)
  model_definition.fields.select(&:external?).each do |field|
    unless model_class.method_defined?(field.name.to_sym)
      raise MetadataError,
        "Model '#{model_definition.name}', field '#{field.name}': " \
        "source is 'external' but no getter method defined. " \
        "Add it via initializer or concern."
    end
    unless model_class.method_defined?(:"#{field.name}=")
      raise MetadataError,
        "Model '#{model_definition.name}', field '#{field.name}': " \
        "source is 'external' but no setter method defined. " \
        "Add it via initializer or concern."
    end
  end
end
```

**Timing note:** `Rails.application.config.after_initialize` blocks run before the engine's `LcpRuby.boot!`, so host-app `class_eval` extensions will be in place when the builder runs. If the host app adds methods later (e.g., via lazy loading), the check can be downgraded to a warning.

### Components that require NO changes

The following already work because they operate on `FieldDefinition` objects:

| Component | Why it works |
|---|---|
| **LayoutBuilder** | Looks up `model_definition.field(name)` - virtual fields are in `fields` array |
| **PermissionEvaluator** | `readable_fields` / `writable_fields` reference field names from permissions YAML |
| **ResourcesController#permitted_params** | Permits fields from `writable_fields` - virtual field names are just strings |
| **FormHelper#render_form_input** | Dispatches on `input_type` / `field_def.type` - works for any field with a `FieldDefinition` |
| **FieldValueResolver** | Calls `record.send(field_name)` - works if getter exists |
| **ValidationApplicator** | Applies `validates` macros to field names - ActiveRecord validates virtual attributes |
| **ConfigurationValidator** (presenter field checks) | Validates field names against `model_field_names` - virtual fields are included |

### Why virtual fields do NOT use `attribute`

Virtual fields are implemented with plain `define_method` getter/setter — we intentionally
do **not** call `attribute :name, :type` on the AR model. Declaring `attribute` would create
a second internal storage slot in AR's `@attributes` hash that our getter/setter bypasses,
leading to a dual source of truth:

- `record.attributes["color"]` would return `nil` (AR's internal storage) while
  `record.color` returns the actual value from the JSON column.
- `record.color_changed?` would report `false` because AR's dirty tracking is unaware
  of changes made through the JSON column.
- `record.as_json` would include `color: nil` instead of the real value.

This is safe because the entire codebase uses metadata-driven field discovery
(`FieldDefinition`, `PermissionEvaluator`, `FieldValueResolver`) and duck typing
(`respond_to?` + `public_send`). No code path depends on `attribute_names` or
`record.attributes` for dynamic model fields. Mass assignment (`Model.new(color: "red")`)
works without `attribute` because `assign_attributes` calls `public_send("color=", value)`.

### Accessor service contract

```ruby
# app/lcp_services/accessors/<name>.rb
module LcpRuby::HostServices::Accessors::<Name>
  # Read the virtual field value from the record
  # @param record [ActiveRecord::Base] the model instance
  # @param options [Hash] frozen options from YAML source.options
  # @return [Object] the field value
  def self.get(record, options:)
  end

  # Write a value to the virtual field on the record
  # @param record [ActiveRecord::Base] the model instance
  # @param value [Object] the value to set
  # @param options [Hash] frozen options from YAML source.options
  def self.set(record, value, options:)
  end
end
```

### Built-in `json_field` accessor

The engine ships a built-in `json_field` accessor service so the common JSON use case works without host app code:

```ruby
# lib/lcp_ruby/services/built_in_accessors/json_field.rb
module LcpRuby
  module Services
    module BuiltInAccessors
      class JsonField
        def self.get(record, options:)
          column = options["column"]
          key = options["key"]
          record.send(column)&.dig(key)
        end

        def self.set(record, value, options:)
          column = options["column"]
          key = options["key"]
          data = record.send(column) || {}
          record.send("#{column}=", data.merge(key => value))
        end
      end
    end
  end
end
```

Registered at boot alongside other built-ins:

```ruby
Services::Registry.register("accessors", "json_field",
  Services::BuiltInAccessors::JsonField)
```

## Examples

### JSON column with virtual editors

```yaml
# models/order.yml
name: order
fields:
  - name: title
    type: string
  - name: metadata
    type: json
  - name: color
    type: string
    source:
      service: json_field
      options: { column: metadata, key: color }
  - name: weight
    type: decimal
    source:
      service: json_field
      options: { column: metadata, key: weight }
    validations:
      - type: numericality
        options: { greater_than: 0 }
```

```yaml
# presenters/orders.yml
form:
  sections:
    - title: Basic
      fields:
        - field: title
    - title: Properties
      fields:
        - field: color
          input_type: color
        - field: weight
          input_type: number
```

```yaml
# permissions/order.yml
roles:
  admin:
    crud: [index, show, create, update, destroy]
    fields:
      readable: all
      writable: [title, color, weight]
```

### External API-backed field

```yaml
# models/product.yml
fields:
  - name: name
    type: string
  - name: stock_count
    type: integer
    source: external
```

```ruby
# config/initializers/lcp_ruby_extensions.rb
Rails.application.config.after_initialize do
  LcpRuby::Dynamic::Product.class_eval do
    def stock_count
      InventoryApi.stock_for(sku: name)
    end

    def stock_count=(value)
      InventoryApi.update_stock(sku: name, count: value)
    end
  end
end
```

## Migration / Compatibility

No migration needed. This is a purely additive feature:
- Existing models without `source` are unaffected
- No database changes for existing tables
- No changes to existing YAML files

## Test Plan

1. **FieldDefinition** - `virtual?`, `external?`, `service_accessor?` predicates
2. **SchemaManager** - verify virtual fields do not create DB columns
3. **ServiceAccessorApplicator** - service lookup, getter/setter generation, error on missing service
4. **Builder** - post-build validation for `source: external` (missing methods)
5. **Built-in json_field service** - get/set/nil-safety
6. **Integration** - full CRUD cycle with virtual fields (create, read in show, edit, update)
7. **Permissions** - virtual fields respect readable/writable permissions
8. **Validations** - standard validations work on virtual fields
9. **ConfigurationValidator** - catches invalid service references, missing column references
