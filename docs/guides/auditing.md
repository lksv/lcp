# Auditing

Auditing tracks field-level changes on records — who changed what, when, and from which value to which. Enable it with `auditing: true` on any model, and the platform automatically logs create, update, destroy, discard, and undiscard operations.

## Prerequisites

The auditing system stores change history in a dedicated audit log model. Generate it first:

```bash
rails generate lcp_ruby:auditing
```

This creates four files:

| File | Purpose |
|------|---------|
| `config/lcp_ruby/models/audit_log.yml` | Audit log model with required fields |
| `config/lcp_ruby/presenters/audit_logs.yml` | Presenter for browsing audit logs |
| `config/lcp_ruby/permissions/audit_log.yml` | Read-only permissions for admin/viewer |
| `config/lcp_ruby/views/audit_logs.yml` | View group with navigation entry |

Start the server to create the database table automatically.

## Basic Setup

Enable auditing on any model:

```yaml
# config/lcp_ruby/models/project.yml
model:
  name: project
  fields:
    - { name: title, type: string }
    - { name: status, type: string }
    - { name: description, type: text }
  options:
    timestamps: true
    auditing: true
```

This tracks all field changes. Every create, update, and destroy action now writes an audit log entry with:
- **action** — `create`, `update`, `destroy` (plus `discard`/`undiscard` if soft delete is enabled)
- **changes_data** — field-level diffs as `{ "field_name": [old_value, new_value] }`
- **user_id** and **user_snapshot** — who made the change (from `LcpRuby::Current.user`)
- **metadata** — request ID for tracing

## Filtering Fields

### Track Only Specific Fields

```yaml
options:
  auditing:
    only:
      - title
      - status
```

Only `title` and `status` changes are recorded. All other field changes are ignored.

### Ignore Specific Fields

```yaml
options:
  auditing:
    ignore:
      - description
      - internal_notes
```

All fields are tracked except `description` and `internal_notes`.

`only` and `ignore` are mutually exclusive — specifying both causes a validation error.

### Automatically Excluded Fields

These fields are always excluded from audit diffs (regardless of `only`/`ignore`):

- `id`, `created_at`, `updated_at` — framework fields
- Userstamp fields (`created_by_id`, `updated_by_id`, etc.) — auto-managed, not user data
- Soft delete columns (`discarded_at`, `discarded_by_type`, `discarded_by_id`) — tracked via action type instead

## Custom Fields and JSON Expansion

### Custom Field Expansion

When a model has custom fields enabled, changes to the `custom_data` JSON column are automatically expanded into individual field diffs with `cf:` prefix:

```yaml
options:
  auditing: true
  custom_fields: true
```

Instead of recording a single `custom_data` change, the audit entry shows:

```json
{
  "cf:risk_level": [30, 80],
  "cf:priority": ["low", "high"]
}
```

This is enabled by default. To disable:

```yaml
options:
  auditing:
    expand_custom_fields: false
```

### JSON Field Expansion

For regular JSON columns, specify which fields to expand:

```yaml
model:
  name: order
  fields:
    - { name: title, type: string }
    - { name: addresses, type: json }
    - { name: config, type: json }
  options:
    auditing:
      expand_json_fields:
        - addresses
```

Changes to the `addresses` JSON column are expanded into dot-path diffs:

```json
{
  "addresses.city": ["Prague", "Bratislava"],
  "addresses.zip": ["11000", "81101"]
}
```

Array-typed JSON values (not hashes) are stored as whole-value diffs rather than expanded.

## Nested Association Tracking

When a model uses `nested_attributes` for its associations, child record changes are included in the parent's audit entry:

```yaml
model:
  name: order
  fields:
    - { name: title, type: string }
  associations:
    - type: has_many
      name: items
      target_model: order_item
      nested_attributes: true
  options:
    auditing: true
```

When items are added, updated, or removed through the parent form, the audit entry includes:

```json
{
  "title": ["Draft Order", "Final Order"],
  "items:created": [{"name": "Widget", "quantity": 5}],
  "items:updated": [{"id": 3, "quantity": [2, 10]}],
  "items:destroyed": [{"id": 7, "name": "Removed Item"}]
}
```

This is enabled by default. To disable:

```yaml
options:
  auditing:
    track_associations: false
```

## Show Page Integration

Audited models automatically get a "Change History" section appended to their show page. This section displays the most recent 20 audit entries with expandable field-level diffs.

To place the section explicitly (e.g., in a specific position), add it to the presenter layout:

```yaml
# config/lcp_ruby/presenters/projects.yml
presenter:
  name: projects
  model: project

  show:
    layout:
      - section: "Details"
        fields:
          - { field: title }
          - { field: status }
      - type: audit_history
```

If you add `type: audit_history` to the layout, the auto-append is skipped. If you omit it, the section is appended automatically after all other sections.

## Soft Delete Integration

When a model has both `auditing: true` and `soft_delete: true`, discard and undiscard operations are tracked automatically:

```yaml
options:
  auditing: true
  soft_delete: true
```

| Action | Audit Entry |
|--------|-------------|
| `discard!` | action: `"discard"`, changes: `{}` |
| `undiscard!` | action: `"undiscard"`, changes: `{}` |

Discard/undiscard entries have empty changes because the action type itself conveys what happened. The soft delete columns are excluded from diffs to avoid redundancy.

## Querying Audit Logs

### Instance Methods

Audited models get two convenience methods:

```ruby
record = Project.find(1)

record.audit_logs           # All audit entries, newest first
record.audit_history(limit: 10)  # Last 10 entries
```

### Direct Queries

The audit log model supports standard ActiveRecord queries:

```ruby
AuditLog = LcpRuby.registry.model_for("audit_log")

# All changes to projects
AuditLog.where(auditable_type: "project")

# Changes by a specific user
AuditLog.where(user_id: 42)

# Recent creates
AuditLog.where(action: "create").order(created_at: :desc).limit(20)
```

## Custom Audit Writer

For advanced use cases (external audit service, different storage backend), configure a custom writer:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.audit_writer = MyAuditService.new
end
```

The custom writer must implement `#log` with these keyword arguments:

```ruby
class MyAuditService
  def log(action:, record:, changes:, user:, metadata:)
    # action   — :create, :update, :destroy, :discard, :undiscard
    # record   — the ActiveRecord instance
    # changes  — Hash of { "field" => [old, new] }
    # user     — current user object (or nil)
    # metadata — Hash with request_id (or nil)
  end
end
```

When a custom writer is configured, it receives all audit events and the built-in audit log model is not written to.

## Field Mapping

If your audit log model uses different column names, configure the mapping:

```ruby
LcpRuby.configure do |config|
  config.audit_model = "change_log"  # model name (default: "audit_log")
  config.audit_model_fields = {
    auditable_type: "entity_type",
    auditable_id: "entity_id",
    action: "operation",
    changes_data: "diff",
    user_id: "actor_id",
    user_snapshot: "actor_snapshot",
    metadata: "meta"
  }
end
```

## DSL Usage

```ruby
LcpRuby.define_model(:project) do
  field :title, :string
  field :status, :string

  auditing                             # tracks all fields
  # auditing only: [:title, :status]   # track specific fields
  # auditing ignore: [:description]    # exclude fields
end
```

## Transaction Safety

Audit log entries are created inside the same database transaction as the record change. If the transaction rolls back (e.g., a validation fails, a callback raises), the audit entry is also rolled back. This guarantees consistency — no orphan audit entries for changes that never committed.

## Permissions

The generated permissions file gives `admin` and `viewer` roles read-only access (`index` and `show`). No role can create, update, or destroy audit log entries through the UI:

```yaml
permissions:
  model: audit_log
  roles:
    admin:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      scope: all
      presenters: all
    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      scope: all
      presenters: all
  default_role: viewer
```

Customize roles and scopes as needed. For example, restrict viewers to only their own audit entries with a `scope` condition.

Source: `lib/lcp_ruby/auditing/`, `lib/lcp_ruby/model_factory/auditing_applicator.rb`, `app/views/lcp_ruby/resources/_audit_history.html.erb`
