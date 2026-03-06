# Sequence Fields Guide

Sequence fields are model attributes whose values are automatically assigned from a gap-free counter on record creation. They produce human-readable business identifiers like `INV-2026-0001` or `TKT-000472`.

## Quick Start

**YAML:**

```yaml
# config/lcp_ruby/models/ticket.yml
name: ticket
fields:
  - name: code
    type: string
    sequence:
      format: "TKT-%{sequence:06d}"
  - name: subject
    type: string
```

**DSL:**

```ruby
define_model :ticket do
  field :code, :string, sequence: { format: "TKT-%{sequence:06d}" }
  field :subject, :string
end
```

Now whenever a ticket is created, `code` is automatically assigned `TKT-000001`, `TKT-000002`, etc.

## Prerequisites

Run the generator to create the counter table model:

```bash
bundle exec rails generate lcp_ruby:gapfree_sequences
```

This creates:
- `config/lcp_ruby/models/gapfree_sequence.yml` — counter table model
- `config/lcp_ruby/permissions/gapfree_sequence.yml` — admin-only permissions

The counter table is created automatically at boot by `SchemaManager`, like any other YAML model.

## How It Works

The `SequenceApplicator` registers a `before_create` callback on the model. When a new record is saved:

1. **Resolve scope** — build a scope key from the record's field values and virtual time keys
2. **Increment counter** — atomically increment the counter row in `lcp_gapfree_sequences` (UPDATE + SELECT in a single transaction)
3. **Format** — interpolate the counter value into the format template
4. **Assign** — set the field value on the record

Key behaviors:

- **Gap-free** — the counter increment runs inside the same transaction as the record INSERT. If the transaction rolls back, the counter rolls back too — no gaps.
- **Persisted** — the formatted value is stored in a real DB column, available for SQL queries, Ransack filters, and sorting
- **Readonly in forms** — sequence fields are rendered as disabled inputs by default (`readonly: true`)
- **No manual assignment needed** — the value is always overwritten by the callback on create

## Scoping

Scopes determine when the counter resets. Each unique combination of scope values gets its own independent counter.

### Global scope (default)

One counter, never resets:

```yaml
- name: code
  type: string
  sequence:
    format: "TKT-%{sequence:06d}"
```

Result: `TKT-000001`, `TKT-000002`, ... forever.

### Yearly scope

Counter resets each year:

```yaml
- name: invoice_number
  type: string
  sequence:
    scope: [_year]
    format: "INV-%{_year}-%{sequence:04d}"
```

Result: `INV-2026-0001`, ..., `INV-2027-0001` (resets in January).

### Monthly scope

```yaml
- name: order_ref
  type: string
  sequence:
    scope: [_year, _month]
    format: "ORD-%{_year}%{_month}-%{sequence:05d}"
```

Result: `ORD-202603-00001`, ..., `ORD-202604-00001` (resets each month).

### Field-based scope

Counter per parent entity:

```yaml
- name: reg_number
  type: string
  sequence:
    scope: [department_id]
    format: "DOC-%{sequence:05d}"
```

Result: Department 1 gets `DOC-00001`, `DOC-00002`; Department 2 gets its own `DOC-00001`, `DOC-00002`.

### Combined scope

```yaml
- name: ref
  type: string
  sequence:
    scope: [tenant_id, _year]
    format: "%{tenant_id}/%{_year}/%{sequence:06d}"
```

### Virtual scope keys

`_year`, `_month`, `_day` are resolved from the record's `created_at` timestamp (or `Time.current` if timestamps are disabled). The underscore prefix prevents collisions with user-defined field names.

All other scope keys must be existing fields or association foreign keys on the model.

## Format Templates

The `format` string supports these placeholders:

| Placeholder | Example | Result |
|-------------|---------|--------|
| `%{sequence}` | `NUM-%{sequence}` | `NUM-42` |
| `%{sequence:04d}` | `TKT-%{sequence:04d}` | `TKT-0042` |
| `%{_year}` | `INV-%{_year}` | `INV-2026` |
| `%{_month}` | `%{_month}` | `03` |
| `%{_day}` | `%{_day}` | `06` |
| `%{field_name}` | `%{dept_code}-%{sequence:04d}` | `HR-0042` |

When `format` is omitted, the raw integer counter value is stored. Use `type: integer` in that case:

```yaml
- name: order_seq
  type: integer
  sequence:
    start: 1000
```

Result: `1000`, `1001`, `1002`, ...

## Custom Start and Step

```yaml
- name: order_seq
  type: integer
  sequence:
    start: 1000
    step: 5
```

Result: `1000`, `1005`, `1010`, ...

## Multiple Sequence Fields

A model can have multiple independent sequence fields:

```yaml
fields:
  - name: reg_number
    type: string
    sequence:
      scope: [department_id]
      format: "REG-%{sequence:04d}"
  - name: global_seq
    type: string
    sequence:
      format: "GBL-%{sequence:06d}"
```

Each field gets its own counter row in the `gapfree_sequences` table.

## Filling Blank Values on Update

By default, sequences are assigned only on create. Use `assign_on: "always"` to also fill blank values on update — useful for migration/import scenarios where records may be created without a sequence value:

```yaml
- name: code
  type: string
  sequence:
    format: "CODE-%{sequence:04d}"
    assign_on: always
```

With `assign_on: "always"`:
- On **create**: always assigns a new value
- On **update**: assigns a new value only if the field is blank (nil or empty)
- Existing values are never overwritten on update

## Shorthand Syntax

The shorthand `sequence: true` uses all defaults (global scope, raw counter, start 1, step 1, readonly):

```yaml
- name: seq
  type: integer
  sequence: true
```

Equivalent to `sequence: {}`.

## Managing Counter Values

### Programmatic API

```ruby
# Set counter value (e.g., after migrating from a legacy system)
LcpRuby::Sequences::SequenceManager.set(
  model: :invoice,
  field: :invoice_number,
  scope: { _year: 2026 },
  value: 3500
)

# Read current counter value
LcpRuby::Sequences::SequenceManager.current(
  model: :invoice,
  field: :invoice_number,
  scope: { _year: 2026 }
)
# => 3500

# List all counters (optionally filtered by model)
LcpRuby::Sequences::SequenceManager.list(model: :invoice)
```

### Rake Tasks

```bash
# List all counters
bundle exec rake lcp_ruby:gapfree_sequences:list

# Set a counter value
bundle exec rake lcp_ruby:gapfree_sequences:set \
  MODEL=invoice FIELD=invoice_number SCOPE=_year:2026 VALUE=3500
```

### UI Management

Since the counter table is a regular platform model, you can create a presenter for `gapfree_sequence` to manage counters through the platform's UI.

## Database Indexes

An index is automatically created on the sequence field (compound with real scope columns):

- **Scope with only real DB columns** (e.g., `[department_id]`) — **unique index** as a safety net against duplicate values
- **Scope with virtual keys** (e.g., `[_year]`, `[department_id, _year]`) — **non-unique index** for query performance only, because virtual scope values are not stored as columns

In both cases, uniqueness is guaranteed by the atomic counter increment in the `gapfree_sequences` table.

## Constraints

- A field **cannot** have both `sequence` and `computed` — they are mutually exclusive
- A field **cannot** have both `sequence` and `source` — they are mutually exclusive
- The `gapfree_sequence` model must exist in the configuration (run the generator)
- Scope columns must reference existing fields or association foreign keys (virtual keys `_year`, `_month`, `_day` are always valid)
- `assign_on` must be `"create"` or `"always"` — invalid values raise `MetadataError` at boot

## Concurrency

The counter uses an optimistic insert pattern:

1. Try `UPDATE ... SET current_value = current_value + step` (most common path)
2. If no rows affected (new scope), `INSERT` with start value
3. On `RecordNotUnique` (concurrent insert race), retry with UPDATE

The UPDATE acquires an implicit row lock held until transaction commit, serializing concurrent inserts within the same scope. This is safe across PostgreSQL, MySQL, and SQLite.

## See Also

- [Models Reference — `sequence`](../reference/models.md#sequence) — YAML field attribute reference
- [Model DSL Reference](../reference/model-dsl.md) — DSL syntax for sequence fields
- [Computed Fields Guide](computed-fields.md) — Related feature for auto-calculated fields
- [Design Spec](../design/sequences.md) — Full design document with decisions and trade-offs
