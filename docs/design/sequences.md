# Feature Specification: Sequence Fields (Auto-Numbering)

**Status:** Proposed
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

### Sequence options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `scope` | array of strings | `[]` (global) | Scope columns or virtual keys (`_year`, `_month`, `_day`). Counter resets independently per unique scope combination. |
| `format` | string | `"%{sequence}"` | Template for the final value. Supports `%{sequence}`, `%{sequence:Nd}` (zero-padded), `%{_year}`, `%{_month}`, `%{_day}`, and any field name from the record via `%{field_name}`. |
| `start` | integer | `1` | Initial counter value for a new scope. |
| `step` | integer | `1` | Increment per record. |
| `readonly` | boolean | `true` | When true, the field is excluded from forms and rejected in `permitted_params`. |
| `assign_on` | string | `"create"` | When to assign: `create` (before_create only) or `always` (also fills blank values on update — for migration/import scenarios). |

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
  field :invoice_number, :string do
    sequence scope: [:_year],
             format: "INV-%{_year}-%{sequence:04d}",
             start: 1
  end
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

Sequence fields with `readonly: true`:
- Are **excluded from form views** (new/edit) — the value is assigned automatically, the field is rejected in `permitted_params`
- Must be **explicitly listed in presenter** columns/sections to appear on show and index views (like any other field — the presenter controls layout and ordering)
- Are **searchable** via quick search and advanced filters (type: string) when included in the presenter
- Support **copy-to-clipboard** (useful for sharing ticket numbers)

### Validation

A unique index is automatically created on the sequence field (compound with scope columns if scoped). This serves as a safety net — if the application-level counter ever produces a duplicate (e.g., due to a bug), the database rejects the insert rather than creating a duplicate business number.

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
gapfree_sequences (default, configurable by generator)
  id:            bigint (PK)
  model_name:    string (NOT NULL)     — e.g., "invoice"
  field_name:    string (NOT NULL)     — e.g., "invoice_number"
  scope_key:     string (NOT NULL)     — e.g., "_year:2026" or "_global"
  current_value: bigint (NOT NULL)     — last assigned number
  created_at:    datetime
  updated_at:    datetime

  UNIQUE INDEX on (model_name, field_name, scope_key)
```

**Note:** The UNIQUE INDEX on `(model_name, field_name, scope_key)` is essential for correctness. The platform must support compound unique indexes in model YAML — if not yet supported, this needs to be extended. The generator should produce the YAML with the correct unique constraint.

#### Assignment flow

When a new record is created:

1. **Resolve scope key** — build the scope string from the record's field values and virtual keys. E.g., for `scope: [_year]` on an invoice created in 2026: `"_year:2026"`. For global scope: `"_global"`.

2. **Increment counter atomically** — in a single SQL statement:
   - PostgreSQL / MySQL: `UPDATE gapfree_sequences SET current_value = current_value + :step, updated_at = NOW() WHERE model_name = :model AND scope_key = :scope RETURNING current_value` (PostgreSQL) or `UPDATE ... ; SELECT current_value ...` (MySQL, in transaction with `FOR UPDATE`).
   - SQLite: Same UPDATE + SELECT in an exclusive transaction.

3. **Handle new scope** — if the UPDATE affects zero rows (new scope combination), INSERT with `start` value. Use `INSERT ... ON CONFLICT DO UPDATE` (upsert) on PG/SQLite, `INSERT ... ON DUPLICATE KEY UPDATE` on MySQL to handle concurrent first-inserts.

4. **Format** — interpolate the counter value and record fields into the format template.

5. **Assign** — set the field value on the record (in a `before_create` callback).

The entire increment is one atomic SQL statement (no SELECT-then-UPDATE). The row lock on the `gapfree_sequences` row serializes concurrent inserts within the same scope, preventing duplicates.

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

1. `ConfigurationValidator` verifies that the counter table model exists in the configuration, that scope fields exist on the model, and that the format template references only valid placeholders
2. `SequenceApplicator` installs a `before_create` callback on the dynamic model
3. A unique index is added on the sequence field (compound with scope columns)

The counter table itself is created by `SchemaManager` like any other YAML-defined model — no special handling needed.

### Sequence management

For administrative tasks (setting initial value after migration, inspecting current counters), the platform provides:

- A `SequenceManager` service class: `SequenceManager.set(model: :invoice, field: :invoice_number, scope: { _year: 2026 }, value: 3500)`
- A rake task: `bundle exec rake lcp_ruby:gapfree_sequences:list` (shows all counters), `bundle exec rake lcp_ruby:gapfree_sequences:set MODEL=invoice FIELD=invoice_number SCOPE=_year:2026 VALUE=3500`

Since the counter table is a regular platform model, administrators can also manage counter values directly through the platform's UI (if the configurator exposes a presenter for it).

## Decisions

1. **Counter table over native sequences.** The counter table approach is the only strategy that works identically across PostgreSQL, MariaDB/MySQL, and SQLite while providing gap-free numbering. Native sequences are PostgreSQL-only, produce gaps, and don't support scoped reset. The performance trade-off (row-level lock per scope) is acceptable for business entity creation rates.

2. **Scope key as concatenated string.** The scope is stored as a single string column (`"_year:2026"`, `"department_id:5/_year:2026"`, `"_global"`) rather than separate columns for each scope dimension. This keeps the table schema fixed regardless of how many scope combinations exist across models.

3. **Format as field-level config, not computed field.** Although the existing `computed` field system supports template interpolation, sequence formatting is tightly coupled to the counter assignment (same callback, same moment). Keeping `format` inside the `sequence:` config block avoids a dependency between two features and makes the YAML self-contained.

4. **Counter table as regular YAML model via generator.** Following the Configuration Source Principle and the "all tables via YAML" rule, the counter table is a standard platform model created by a generator (`lcp_ruby:gapfree_sequences`). The configurator runs the generator, which produces model YAML with the correct schema and unique constraints. This is consistent with how `lcp_ruby:custom_fields`, `lcp_ruby:roles`, and `lcp_ruby:saved_filters` generators work. The configurator is responsible for permissions and can optionally expose a presenter for administrative access to counter values.

5. **Table name: `gapfree_sequences`.** The default generator model name is `gapfree_sequences`. This is descriptive (gap-free is the key property) and leaves room for a hypothetical future `native_sequences` type (PostgreSQL sequences, which have gaps). The configurator can rename via generator options.

6. **Multiple sequence fields per model.** Supported from the start. A document can have both `reg_number` (per department) and `global_seq` (system-wide). The counter table keys rows by `(model_name, field_name, scope_key)`.

7. **Bulk import.** Supported from the start. When importing N records, the platform locks once and increments by N: `UPDATE ... SET current_value = current_value + N RETURNING current_value`. The importer assigns `end - N + 1` through `end` to the records.

8. **Soft delete behavior.** When a record is soft-deleted, its sequence number is preserved. New records get the next number — soft-deleted numbers are not reused. Restored records keep their original number. This is not configurable.

9. **Editability is the configurator's responsibility.** The counter table is a regular model with standard permissions. The generator creates sensible defaults (e.g., admin-only write access), but the configurator has full control. Sequence fields on business models use `readonly: true` by default; if an admin needs to correct a value, the configurator grants `writable_fields` access for that role.

## Prerequisites

**Compound unique index support.** The model JSON schema already defines `indexes` with `columns` array and `unique` flag (`lib/lcp_ruby/schemas/model.json:86`), but `ModelDefinition` and `SchemaManager` do not yet process them. Implementation is trivial:

1. `ModelDefinition.from_hash` — parse `hash["indexes"]` into an array of hashes (columns, unique, name), expose via `attr_reader :indexes`
2. `SchemaManager#create_table!` — after creating the table, iterate `model_definition.indexes` and call `connection.add_index(table, idx[:columns], unique: idx[:unique], name: idx[:name])`
3. `SchemaManager#update_table!` — same loop, guarded by `connection.index_exists?(table, idx[:columns], unique: idx[:unique])`
4. `ConfigurationValidator` — validate that `indexes[].columns` reference existing fields

This is a general-purpose feature (not sequence-specific) that unblocks the gapfree_sequences generator and benefits any model needing compound indexes.

## Open Questions

None at this time.
