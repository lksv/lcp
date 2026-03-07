# Computed Fields Guide

Computed fields are model attributes whose values are automatically calculated from other fields before every save. The computed value is persisted in the database, so it is always available for queries, sorting, and indexing without runtime recalculation.

## Quick Start

**YAML:**

```yaml
model:
  name: order_line
  fields:
    - { name: price, type: decimal }
    - { name: quantity, type: integer }
    - name: total
      type: decimal
      computed:
        service: order_line_total
```

**DSL:**

```ruby
define_model :order_line do
  field :price, :decimal
  field :quantity, :integer
  field :total, :decimal, computed: { service: "order_line_total" }
end
```

**Service** in `app/lcp_services/computed/order_line_total.rb`:

```ruby
module LcpRuby
  module HostServices
    module Computed
      class OrderLineTotal
        def self.call(record)
          (record.price.to_f * record.quantity.to_i).round(2)
        end
      end
    end
  end
end
```

Now whenever an `order_line` record is created or updated, `total` is automatically set to `price * quantity` and stored in the database.

## How It Works

The `ComputedApplicator` registers a `before_save` callback on the model. On every save (create and update), it iterates over all computed fields and writes the calculated value to the record before it hits the database.

Key behaviors:

- **Persisted** — the value is written to a real DB column, available for SQL queries, Ransack filters, and sorting
- **Recalculated on every save** — if you change `price` or `quantity`, `total` updates automatically on the next save
- **Readonly in forms** — computed fields are marked as `computed?` and rendered as readonly inputs in generated forms
- **No manual assignment needed** — any value manually set on a computed field is overwritten by the callback

## Two Syntax Options

### Template Syntax (String Interpolation)

For simple concatenation of field values into a string:

```yaml
- name: full_name
  type: string
  computed: "{first_name} {last_name}"
```

```ruby
# DSL
field :full_name, :string, computed: "{first_name} {last_name}"
```

Template syntax replaces `{field_name}` placeholders with `.to_s` of the corresponding field value. This is useful for display names, labels, and codes — but **not for arithmetic**. If a referenced field is `nil`, it renders as an empty string.

More examples:

```yaml
# Code with prefix
- name: code
  type: string
  computed: "ORD-{id}-{year}"

# Descriptive label
- name: display_label
  type: string
  computed: "{name} ({status})"
```

### Service Syntax (Custom Logic)

For any logic beyond string interpolation — arithmetic, conditionals, lookups:

```yaml
- name: total
  type: decimal
  computed:
    service: order_line_total
```

```ruby
# DSL
field :total, :decimal, computed: { service: "order_line_total" }
```

The service class must:
- Live in `app/lcp_services/computed/`
- Be namespaced under `LcpRuby::HostServices::Computed`
- Implement `def self.call(record) -> value`

The return value is assigned directly to the field. The service has full access to the record and can call any method on it.

## Writing a Computed Service

### Basic Arithmetic

```ruby
# app/lcp_services/computed/order_line_total.rb
module LcpRuby
  module HostServices
    module Computed
      class OrderLineTotal
        def self.call(record)
          (record.price.to_f * record.quantity.to_i).round(2)
        end
      end
    end
  end
end
```

### Conditional Logic

```ruby
# app/lcp_services/computed/feature_score.rb
module LcpRuby
  module HostServices
    module Computed
      class FeatureScore
        def self.call(record)
          base = record.amount.to_f
          multiplier = case record.status
          when "active" then 1.5
          when "completed" then 2.0
          when "cancelled" then 0.0
          else 1.0
          end
          (base * multiplier).round(2)
        end
      end
    end
  end
end
```

### Derived from Associations

```ruby
# app/lcp_services/computed/invoice_total.rb
module LcpRuby
  module HostServices
    module Computed
      class InvoiceTotal
        def self.call(record)
          record.line_items.sum(:total)
        end
      end
    end
  end
end
```

> **Note:** Be mindful of N+1 queries when accessing associations in computed services. This service runs on every save of the parent record, so it is fine for single-record operations. For read-only aggregate display on index pages, consider [Virtual Columns](virtual-columns.md) instead.

## Displaying Computed Fields

Computed fields are regular DB columns, so they work in presenters like any other field.

### Index Columns

```yaml
index:
  columns:
    - { field: name, link_to: show }
    - { field: price, renderer: currency }
    - { field: quantity }
    - { field: total, renderer: currency, sortable: true }
```

### Show Page

```yaml
show:
  layout:
    - title: "Order Line"
      fields:
        - { field: price, renderer: currency }
        - { field: quantity }
        - { field: total, renderer: currency }
```

### Forms

Computed fields are **automatically readonly** in forms. You can include them for visibility, but users cannot edit them:

```yaml
form:
  layout:
    - title: "Order Line"
      fields:
        - { field: price }
        - { field: quantity }
        - { field: total }   # displayed as readonly
```

Or simply omit them from the form — the value is calculated regardless of whether the field appears in the form.

## Computed Fields vs. Virtual Columns

Both produce derived values, but they serve different purposes:

| | Computed Fields | Virtual Columns |
|---|---|---|
| **Storage** | Persisted in DB column | Not stored (SQL at query time) |
| **Recalculation** | On every save of the record | On every query |
| **Source** | Fields on the same record (or associations via service) | Associated records, JOINs, SQL expressions |
| **Queryable** | Yes (regular column — filter, sort, index) | Yes (via SQL subquery/expression) |
| **Use case** | `total = price * quantity` | `orders_count` from child records, `is_overdue` flag |

**Rule of thumb:** If the value depends on fields of the **same record** and should be persisted, use a computed field. If it summarizes data from **associated records**, derives from SQL expressions, or should always reflect the current state without saving, use a [virtual column](virtual-columns.md).

## Computed Fields vs. Transforms

[Transforms](../reference/models.md#transforms) normalize a single field's own value (e.g., `strip`, `downcase`). Computed fields derive a value from **other** fields. They do not overlap — you can use both on the same model.

## Permissions

Computed fields follow standard field permissions. Since they should never be user-editable, keep them out of `writable` lists:

```yaml
roles:
  editor:
    fields:
      readable: [price, quantity, total]
      writable: [price, quantity]       # total is not writable
```

When `readable: all` is used, computed fields are automatically included.

## Validation

The `ConfigurationValidator` raises an error if a field has both `source` and `computed` — these are mutually exclusive. A field is either computed from other fields or sourced from an external accessor, not both.

## Complete Example

### Model

```ruby
define_model :order_line do
  label "Order Line"
  label_plural "Order Lines"

  field :product_name, :string, null: false do
    validates :presence
  end
  field :price, :decimal, precision: 10, scale: 2, null: false
  field :quantity, :integer, null: false, default: 1
  field :discount_pct, :decimal, precision: 5, scale: 2, default: 0
  field :total, :decimal, precision: 12, scale: 2,
    computed: { service: "order_line_total" }
  field :label, :string,
    computed: "{product_name} x{quantity}"

  timestamps true
  label_method :label
end
```

### Computed Service

```ruby
# app/lcp_services/computed/order_line_total.rb
module LcpRuby
  module HostServices
    module Computed
      class OrderLineTotal
        def self.call(record)
          price = record.price.to_f
          qty = record.quantity.to_i
          discount = record.discount_pct.to_f / 100.0
          (price * qty * (1 - discount)).round(2)
        end
      end
    end
  end
end
```

### Presenter

```ruby
define_presenter :order_line do
  model :order_line
  label "Order Lines"
  slug "order-lines"

  index do
    default_sort :created_at, :desc
    column :product_name, link_to: :show, sortable: true
    column :price, renderer: :currency
    column :quantity
    column :discount_pct, renderer: :percentage
    column :total, renderer: :currency, sortable: true
  end

  show do
    section "Order Line" do
      field :product_name
      field :price, renderer: :currency
      field :quantity
      field :discount_pct, renderer: :percentage
      field :total, renderer: :currency
      field :label
    end
  end

  form do
    section "Order Line" do
      field :product_name, autofocus: true
      field :price
      field :quantity
      field :discount_pct
    end
  end

  action :create, type: :built_in, on: :collection
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
```

## Reference

- [Models Reference — `computed`](../reference/models.md#computed) — YAML/DSL syntax reference
- [Extensibility Guide — Computed Fields](extensibility.md#computed-fields) — Service registration and discovery
- Source: `lib/lcp_ruby/model_factory/computed_applicator.rb`
