# Auditing Reference

Auditing records field-level change history (create, update, destroy, discard, undiscard) for models with `auditing: true`. Changes are stored in a dedicated audit log model.

## Prerequisites

Generate the audit log model:

```bash
rails generate lcp_ruby:auditing
```

This creates:
- `config/lcp_ruby/models/audit_log.yml` — model with required fields
- `config/lcp_ruby/presenters/audit_logs.yml` — presenter for browsing logs
- `config/lcp_ruby/permissions/audit_log.yml` — read-only permissions
- `config/lcp_ruby/views/audit_logs.yml` — view group with navigation

## Model Option

### `auditing`

| | |
|---|---|
| **Default** | `false` (disabled) |
| **Type** | `true` or Hash |

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

`only` and `ignore` are mutually exclusive — specifying both causes a validation error at boot time.

## Audit Log Model Contract

The audit log model must have these required fields:

| Field | Type | Purpose |
|-------|------|---------|
| `auditable_type` | string | Model name of the audited record |
| `auditable_id` | integer | Primary key of the audited record |
| `action` | string | Operation: `create`, `update`, `destroy`, `discard`, `undiscard` |
| `changes_data` | json | Field-level diffs: `{ "field": [old, new] }` |

Recommended fields (warnings if missing):

| Field | Type | Purpose |
|-------|------|---------|
| `user_id` | integer | ID of the user who made the change |
| `user_snapshot` | json | Snapshot: `{ "id", "email", "name", "role" }` |

Additional fields supported:

| Field | Type | Purpose |
|-------|------|---------|
| `metadata` | json | Request ID and other context |
| `created_at` | datetime | Timestamp (or enable `timestamps: true`) |

The contract is validated at boot time. Missing required fields raise `MetadataError`. Missing recommended fields produce warnings.

## Changes Data Format

### Scalar Fields

```json
{
  "title": ["Old Title", "New Title"],
  "amount": [100, 200],
  "active": [true, false]
}
```

Each entry is `[old_value, new_value]`. On create, old is `null`. On destroy, new is `null`.

### Custom Field Expansion

When `expand_custom_fields` is `true` (default), changes to the `custom_data` column are expanded:

```json
{
  "cf:risk_level": [30, 80],
  "cf:priority": ["low", "high"]
}
```

Keys unchanged between old and new values are omitted.

### JSON Field Expansion

Fields listed in `expand_json_fields` are expanded into dot-path keys for Hash values:

```json
{
  "addresses.city": ["Prague", "Bratislava"],
  "addresses.zip": ["11000", "81101"]
}
```

Non-Hash JSON values (arrays, scalars) are stored as whole-value diffs.

### Nested Association Changes

When `track_associations` is `true` (default), nested_attributes child changes use colon-separated keys:

```json
{
  "items:created": [{"name": "Widget", "quantity": 5}],
  "items:updated": [{"id": 3, "quantity": [2, 10]}],
  "items:destroyed": [{"id": 7, "name": "Deleted Item"}]
}
```

Only loaded associations with `nested_attributes: true` are tracked.

### Discard/Undiscard

Discard and undiscard actions record the action type with empty changes:

```json
{"action": "discard", "changes_data": {}}
```

Soft delete columns are excluded from diffs; the action type conveys the operation.

## Excluded Fields

These fields are always excluded from audit diffs:

| Category | Fields |
|----------|--------|
| Framework | `id`, `created_at`, `updated_at` |
| Userstamps | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` (when userstamps enabled) |
| Soft delete | `discarded_at`, `discarded_by_type`, `discarded_by_id` (when soft delete enabled) |

## Instance Methods

Models with `auditing: true` get these methods:

| Method | Returns | Description |
|--------|---------|-------------|
| `audit_logs` | `ActiveRecord::Relation` | All audit entries for this record, ordered by `created_at DESC` |
| `audit_history(limit: 50)` | `ActiveRecord::Relation` | Audit entries with a limit |

These are query methods (not ActiveRecord associations), so `includes(:audit_logs)` is not supported.

## Show Page Section

Audited models automatically get an `audit_history` section appended to their show page. To control placement, add it explicitly:

```yaml
show:
  layout:
    - section: "Details"
      fields: [...]
    - type: audit_history
```

The auto-append is skipped if an `audit_history` section is already present in the layout.

## Engine Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `audit_model` | String | `"audit_log"` | Name of the LCP Ruby model that stores audit entries |
| `audit_model_fields` | Hash | See below | Maps logical field names to actual column names |
| `audit_writer` | Object | `nil` | Custom writer; when set, bypasses built-in audit log model |

### `audit_model_fields` Default

```ruby
{
  auditable_type: "auditable_type",
  auditable_id: "auditable_id",
  action: "action",
  changes_data: "changes_data",
  user_id: "user_id",
  user_snapshot: "user_snapshot",
  metadata: "metadata"
}
```

### Custom Audit Writer

Must implement `#log(action:, record:, changes:, user:, metadata:)`. When configured, the built-in audit log model is not used.

## Generator

```bash
rails generate lcp_ruby:auditing
```

Creates the standard audit log model, presenter, permissions, and view group files. Run once before enabling `auditing: true` on any model.

## DSL

```ruby
LcpRuby.define_model(:project) do
  field :title, :string

  auditing                           # all fields
  auditing only: [:title, :status]   # specific fields
  auditing ignore: [:description]    # exclude fields
end
```

## Validation

The `ConfigurationValidator` checks:
- `only` and `ignore` are mutually exclusive (error)
- `only`/`ignore` reference existing field names (warning)
- `expand_json_fields` references fields of type `json`/`jsonb` (warning)

## Architecture

```
Model YAML (auditing: true)
  → AuditingApplicator installs after_create/update/destroy callbacks
  → Callbacks call AuditWriter.log
  → AuditWriter computes diffs, filters, expands JSON/custom fields
  → Writes to audit log model (or delegates to custom writer)

SoftDeleteApplicator (discard!/undiscard!)
  → Calls AuditWriter.log directly (update_columns bypasses AR callbacks)

LayoutBuilder (show page)
  → Auto-appends audit_history section if model has auditing + registry available

Auditing::Setup (boot time)
  → Checks any model has auditing: true
  → Validates audit model exists and satisfies contract
  → Marks Auditing::Registry as available
```

Source: `lib/lcp_ruby/auditing/`, `lib/lcp_ruby/model_factory/auditing_applicator.rb`, `lib/lcp_ruby/presenter/layout_builder.rb`
