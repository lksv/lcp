# Feature Specification: Sequence Fields (Auto-Numbering)

**Status:** In Progress
**Date:** 2026-03-06

## Problem / Motivation

Real-world information systems need automatically assigned sequential numbers for business entities — invoice numbers, ticket codes, order references, document registration numbers. These are not database primary keys; they are human-readable business identifiers with specific requirements:

- **Uniqueness** within a defined scope (global, per year, per department, per tenant)
- **Sequential** — no random gaps (regulatory requirement for invoices in many jurisdictions)
- **Formatted** — `INV-2026-000047`, not just `47`
- **Scope reset** — numbering restarts each year, or per parent entity
- **Read-only** — assigned automatically, not editable by users

Without platform support, host apps must implement ad-hoc counters with manual locking, race condition handling, and scope management — error-prone boilerplate that every project repeats.

## User Scenarios

**As a platform configurator building an invoicing system,** I want to define a `invoice_number` field that automatically assigns the next number in format `INV-2026-0001` when a new invoice is created, scoped per year so numbering resets each January.

**As a platform configurator building a help desk,** I want every ticket to get a globally unique sequential code like `TKT-000472` that never resets and never has gaps, so users can reference tickets by number.

**As a platform configurator building a document management system,** I want document registration numbers scoped per department — each department has its own independent counter: `HR-0001`, `HR-0002`, `FIN-0001`, etc.

**As a user creating a new invoice,** I expect the invoice number to be assigned automatically when I save the record. I should see it on the show page immediately after creation. I should not be able to edit it.

**As an admin,** I want to set the starting value of a sequence (e.g., migrating from a legacy system where the last invoice was `INV-2026-3500`, so the next one should be `INV-2026-3501`).

## Configuration & Behavior

### YAML configuration

The `sequence` key on a field definition declares it as an auto-numbered field:

```yaml
# config/lcp_ruby/models/invoice.yml
fields:
  - name: invoice_number
    type: string
    sequence:
      scope: [_year]
      format: "INV-%{_year}-%{sequence:04d}"
      start: 1
      step: 1
```

The shorthand `sequence: true` is equivalent to `sequence: {}` — all options use their defaults (global scope, raw counter, start 1, step 1, readonly).

A sequence field **cannot** be combined with `computed` or `source` — these are mutually exclusive. Attempting to use both raises a `MetadataError` at boot.

### Sequence options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `scope` | array of strings | `[]` (global) | Scope columns or virtual keys (`_year`, `_month`, `_day`). Counter resets independently per unique scope combination. |
| `format` | string | `"%{sequence}"` | Template for the final value. Supports `%{sequence}`, `%{sequence:Nd}` (zero-padded), `%{_year}`, `%{_month}`, `%{_day}`, and any field name from the record via `%{field_name}`. |
| `start` | integer | `1` | Initial counter value for a new scope. |
| `step` | integer | `1` | Increment per record. |
| `readonly` | boolean | `true` | When true, the field is rendered as a disabled input in forms (visible but not editable). |
| `assign_on` | string | `"create"` | When to assign: `create` (before_create only) or `always` (also fills blank values on update — for migration/import scenarios). Invalid values raise `MetadataError` at boot. |

### Scope types

Scopes determine when the counter resets. Each unique combination of scope values gets its own independent counter.

```yaml
# Global — one counter, never resets
sequence:
  format: "TKT-%{sequence:06d}"

# Per year — resets each year
sequence:
  scope: [_year]
  format: "INV-%{_year}-%{sequence:04d}"

# Per year + month
sequence:
  scope: [_year, _month]
  format: "ORD-%{_year}%{_month}-%{sequence:05d}"

# Per belongs_to parent (field on the record)
sequence:
  scope: [department_id]
  format: "DOC-%{sequence:05d}"

# Per parent + year
sequence:
  scope: [tenant_id, _year]
  format: "%{tenant_id}/%{_year}/%{sequence:06d}"
```

**Virtual scope keys:** `_year`, `_month`, `_day` are resolved from the record's `created_at` (or `Time.current` if timestamps are disabled). The underscore prefix prevents collisions with user-defined fields of the same name (e.g., a `year` field on an academic record). All other scope keys are field names on the record and must exist as defined fields or association foreign keys.

### DSL alternative

```ruby
LcpRuby.define_model :invoice do
  field :invoice_number, :string,
    sequence: { scope: [:_year], format: "INV-%{_year}-%{sequence:04d}", start: 1 }
end
```

### Format interpolation

The `format` string supports these placeholders:

| Placeholder | Resolves to |
|-------------|-------------|
| `%{sequence}` | Raw counter value (e.g., `47`) |
| `%{sequence:Nd}` | Zero-padded to N digits (e.g., `%{sequence:04d}` → `0047`) |
| `%{_year}` | 4-digit year from `created_at` or current time |
| `%{_month}` | 2-digit month (zero-padded) |
| `%{_day}` | 2-digit day (zero-padded) |
| `%{field_name}` | Value of any field on the record (e.g., `%{department_code}`) |

When `format` is omitted, the raw integer counter value is stored. The field type should be `integer` in that case instead of `string`.

### Presenter behavior

Sequence fields with `readonly: true` (the default):
- Are rendered as **disabled inputs** in form views (new/edit) — visible but not editable. The value appears blank on the new form (assigned on save) and read-only on the edit form.
- Must be **explicitly listed in presenter** columns/sections to appear on show and index views (like any other field — the presenter controls layout and ordering)
- Are **searchable** via quick search and advanced filters (type: string) when included in the presenter

### Validation

An index is automatically created on the sequence field (compound with real scope columns). When the scope contains only real DB columns (e.g., `[department_id]`), the index is **unique** — a safety net against duplicate business numbers. When the scope contains virtual keys (`_year`, `_month`, `_day`), the index is **non-unique** (for query performance only), because virtual scope values are not stored as columns in the target table and cannot be included in a DB index. In that case, uniqueness is guaranteed by the atomic counter increment in the `gapfree_sequences` table.

## Usage Examples

### Invoice with yearly numbering

```yaml
# config/lcp_ruby/models/invoice.yml
name: invoice
fields:
  - name: invoice_number
    type: string
    sequence:
      scope: [_year]
      format: "INV-%{_year}-%{sequence:06d}"
  - name: amount
    type: decimal
    column_options: { precision: 10, scale: 2 }
  - name: issued_at
    type: date
```

Result: `INV-2026-000001`, `INV-2026-000002`, ..., `INV-2027-000001` (resets each year).

### Help desk ticket with global counter

```yaml
name: ticket
fields:
  - name: code
    type: string
    sequence:
      format: "TKT-%{sequence:06d}"
  - name: subject
    type: string
  - name: status
    type: enum
    enum_values: [open, in_progress, resolved, closed]
```

Result: `TKT-000001`, `TKT-000002`, ... (never resets).

### Document per department

```yaml
name: document
fields:
  - name: reg_number
    type: string
    sequence:
      scope: [department_id]
      format: "DOC-%{sequence:05d}"
  - name: title
    type: string
associations:
  - name: department
    type: belongs_to
    target_model: department
```

Result: Department 1 gets `DOC-00001`, `DOC-00002`; Department 2 gets its own `DOC-00001`, `DOC-00002` independently.

### Raw integer counter (no formatting)

```yaml
name: order
fields:
  - name: order_seq
    type: integer
    sequence:
      scope: [_year]
      start: 1000
```

Result: `1000`, `1001`, `1002`, ... (resets to `1000` each year).

## General Implementation Approach

### Counter table strategy

The chosen approach uses a dedicated counter table that works identically across PostgreSQL, MariaDB/MySQL, and SQLite. Each row tracks the current counter value for a specific model + scope combination.

#### Counter table schema

The counter table is a regular platform model defined in YAML, not internal infrastructure. A generator (`lcp_ruby:gapfree_sequences`) creates the model YAML and permissions for the configurator, similar to how `lcp_ruby:custom_fields` and `lcp_ruby:roles` generators work. The configurator is responsible for including the generated YAML in their configuration and setting appropriate permissions.

```
lcp_gapfree_sequences
  id:            bigint (PK)
  seq_model:     string (NOT NULL)     — e.g., "invoice"
  seq_field:     string (NOT NULL)     — e.g., "invoice_number"
  scope_key:     string (NOT NULL)     — e.g., "_year:2026" or "_global"
  current_value: integer (NOT NULL)    — last assigned number
  created_at:    datetime
  updated_at:    datetime

  UNIQUE INDEX on (seq_model, seq_field, scope_key)
```

The generator produces a model YAML with presence validations and the compound unique index using the `indexes` feature.

#### Assignment flow

When a new record is created:

1. **Resolve scope key** — build the scope string from the record's field values and virtual keys. E.g., for `scope: [_year]` on an invoice created in 2026: `"_year:2026"`. For global scope: `"_global"`.

2. **Increment counter atomically** — `UPDATE lcp_gapfree_sequences SET current_value = current_value + :step, updated_at = NOW() WHERE seq_model = :model AND seq_field = :field AND scope_key = :scope` inside a transaction. The UPDATE acquires an implicit row lock, then a SELECT reads the new value within the same transaction.

3. **Handle new scope** — if the UPDATE affects zero rows (new scope combination), INSERT with `start` value. On `RecordNotUnique` (concurrent INSERT race), retry with UPDATE + SELECT. The losing thread gets `start + step` (the winner got `start`).

4. **Format** — interpolate the counter value and record fields into the format template.

5. **Assign** — set the field value on the record (in a `before_create` callback).

The UPDATE + SELECT pair runs inside a single transaction. The row lock on the counter row serializes concurrent inserts within the same scope, preventing duplicates.

#### Gap-free guarantee

Because the counter increment happens inside the same database transaction as the record INSERT:
- If the transaction commits → counter is incremented and record exists (consistent)
- If the transaction rolls back → counter increment is also rolled back (no gap)

This is the key advantage over database sequences (which operate outside transactions and always produce gaps on rollback).

#### Performance characteristics

The counter table row acts as a serialization point — concurrent inserts to the same scope wait for each other. This is acceptable for typical business entity creation rates (invoices, tickets, orders). For high-throughput scenarios (thousands of inserts per second to the same scope), the row lock becomes a bottleneck. In practice, business entities with sequential numbering requirements rarely hit this limit.

### Alternatives considered

**A) App-level MAX+1 query** — `SELECT MAX(field) + 1 FROM table WHERE scope`. Simple but has a race condition window between SELECT and INSERT. Requires advisory locks or retry loops. Rejected because the counter table approach is equally simple and inherently safe.

**B) Native database sequences** — PostgreSQL `CREATE SEQUENCE` delivers the best performance (no row lock contention) but only works on PostgreSQL, produces gaps on rollback, and does not support scoped reset. Could be offered as an opt-in optimization for PostgreSQL users who accept gaps (`type: native` option), but the counter table is the default and portable implementation.

### Boot and schema management

At boot, when `Metadata::Loader` encounters a field with `sequence:` config:

1. `ConfigurationValidator` verifies that the `gapfree_sequence` model exists in the configuration, that scope fields exist on the model (virtual keys like `_year` are allowed), that the format template references only valid placeholders, and that `assign_on` is a valid value (`create` or `always`)
2. `SequenceApplicator` installs `before_create` (and optionally `before_update` for `assign_on: "always"`) callbacks on the dynamic model
3. `SchemaManager` adds an index on the sequence field (unique when scope has no virtual keys, non-unique otherwise)

The counter table itself is created by `SchemaManager` like any other YAML-defined model — no special handling needed.

### Sequence management

For administrative tasks (setting initial value after migration, inspecting current counters), the platform provides:

- `SequenceManager.set(model: :invoice, field: :invoice_number, scope: { _year: 2026 }, value: 3500)` — set counter value
- `SequenceManager.current(model: :invoice, field: :invoice_number, scope: { _year: 2026 })` — read current value
- `SequenceManager.list(model: :invoice)` — list all counters (optionally filtered by model)
- Rake tasks: `bundle exec rake lcp_ruby:gapfree_sequences:list` and `bundle exec rake lcp_ruby:gapfree_sequences:set MODEL=invoice FIELD=invoice_number SCOPE=_year:2026 VALUE=3500`

Since the counter table is a regular platform model, administrators can also manage counter values directly through the platform's UI (if the configurator exposes a presenter for it).

## Decisions

1. **Counter table over native sequences.** The counter table approach is the only strategy that works identically across PostgreSQL, MariaDB/MySQL, and SQLite while providing gap-free numbering. Native sequences are PostgreSQL-only, produce gaps, and don't support scoped reset. The performance trade-off (row-level lock per scope) is acceptable for business entity creation rates.

2. **Scope key as concatenated string.** The scope is stored as a single string column (`"_year:2026"`, `"department_id:5/_year:2026"`, `"_global"`) rather than separate columns for each scope dimension. This keeps the table schema fixed regardless of how many scope combinations exist across models.

3. **Format as field-level config, not computed field.** Although the existing `computed` field system supports template interpolation, sequence formatting is tightly coupled to the counter assignment (same callback, same moment). Keeping `format` inside the `sequence:` config block avoids a dependency between two features and makes the YAML self-contained.

4. **Counter table as regular YAML model via generator.** Following the Configuration Source Principle and the "all tables via YAML" rule, the counter table is a standard platform model created by a generator (`lcp_ruby:gapfree_sequences`). The configurator runs the generator, which produces model YAML with the correct schema and unique constraints. This is consistent with how `lcp_ruby:custom_fields`, `lcp_ruby:roles`, and `lcp_ruby:saved_filters` generators work. The configurator is responsible for permissions and can optionally expose a presenter for administrative access to counter values.

5. **Model name: `gapfree_sequence`, table: `lcp_gapfree_sequences`.** The model name is singular (`gapfree_sequence`) following the platform convention. The `lcp_` table prefix avoids collisions with host app tables. Column names use `seq_model`/`seq_field` to avoid conflicts with ActiveRecord internals (`model_name` is an AR method).

6. **Multiple sequence fields per model.** Supported from the start. A document can have both `reg_number` (per department) and `global_seq` (system-wide). The counter table keys rows by `(model_name, field_name, scope_key)`.

7. **Bulk import.** Not yet implemented. Planned: lock once and increment by N, assign `end - N + 1` through `end`.

8. **Soft delete behavior.** When a record is soft-deleted, its sequence number is preserved. New records get the next number — soft-deleted numbers are not reused. Restored records keep their original number. This is not configurable.

9. **Editability is the configurator's responsibility.** The counter table is a regular model with standard permissions. The generator creates sensible defaults (e.g., admin-only write access), but the configurator has full control. Sequence fields on business models use `readonly: true` by default; if an admin needs to correct a value, the configurator grants `writable_fields` access for that role.

## Prerequisites

**Compound unique index support** — implemented as part of this feature. `ModelDefinition` parses `indexes` from YAML, `SchemaManager` creates them at boot (with `index_exists?` guard for idempotency), `ConfigurationValidator` validates column references, and the DSL supports `index` declarations. This is a general-purpose feature (not sequence-specific) that benefits any model needing compound indexes.

## Open Questions

None at this time.
