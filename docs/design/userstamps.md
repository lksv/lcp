# Userstamps (Created By / Updated By) — Design Document

> **Status:** Proposed
> **Date:** 2026-02-26

## Problem

Many information systems need to track **who created** and **who last modified** each record. This is analogous to how Rails automatically manages `created_at` and `updated_at` timestamps — but for user identity instead of time.

Currently, the platform has no built-in support for this. A developer can manually define `created_by_id` / `updated_by_id` fields, set `default: "current_user_id"` on the creator field, and write a custom event handler for the updater — but this is boilerplate that every real-world application needs. The platform should handle it declaratively, just like `timestamps: true`.

## Goals

- Provide a `userstamps` model option that automatically tracks creator and last modifier
- Follow the same pattern as `timestamps` — zero-config with sensible defaults, customizable when needed
- Automatically populate fields via callbacks using `LcpRuby::Current.user`
- Be tolerant of missing user context (seeds, background jobs, bulk operations, console)
- Optionally store a denormalized user name snapshot alongside the ID

## Non-Goals

- User profile renderer (avatar, link to profile page) — this is a separate, general-purpose display feature
- Audit trail of all editors — that is the scope of the [Auditing](auditing.md) design
- Tracking which specific fields a user changed — also Auditing scope
- Association preloading for user display — can be added later as an enhancement

## Design Decisions

### Naming: `userstamps` and `created_by_id` / `updated_by_id`

Several naming conventions were considered:

| Option | Pro | Con |
|--------|-----|-----|
| `userstamps` | Direct analogy to `timestamps`, immediately clear | Slightly long |
| `blameable` | Popular in gems (paper_trail, audited) | Negative connotation, unclear to non-Rails devs |
| `track_author` | Descriptive | Asymmetric — "author" doesn't naturally cover "modifier" |

**Decision:** `userstamps` — the `timestamps` analogy makes the concept instantly understandable.

For column names, `created_by_id` / `updated_by_id` were chosen over alternatives:

| Option | Pro | Con |
|--------|-----|-----|
| `created_by_id` / `updated_by_id` | Symmetric with `created_at` / `updated_at`, reads naturally | Slightly longer |
| `creator_id` / `modifier_id` | Shorter | No symmetry with timestamp columns |
| `author_id` / `editor_id` | Short | `author` / `editor` are semantically different concepts |
| `created_by` / `updated_by` | Clean | Collides with Rails association names |

**Decision:** `created_by_id` / `updated_by_id` — the `_id` suffix follows Rails FK conventions and the `created_by` / `updated_by` prefix is symmetric with existing timestamp columns.

### Foreign key: always `LcpRuby.configuration.user_class`

The question arose whether to use a configurable FK target or a plain integer column. Since the platform already requires `user_class` configuration for authentication, there is no ambiguity about which table users live in.

**Decision:** Always reference `LcpRuby.configuration.user_class` via a `belongs_to` association. However, **no database-level FK constraint** is added — only a bigint column with an index. Reasons:

- If the host app deletes a user, a DB FK constraint would either block the deletion or cascade-nullify/delete records — both surprising side effects
- The association still works for eager loading and queries without a DB constraint
- This matches how many Rails applications handle user references in practice

### Always nullable — no system user required

Userstamp fields must be **nullable in all cases**. Several scenarios naturally produce records without a current user:

- Database seeds and migrations
- Background jobs (Sidekiq, ActiveJob)
- Rake tasks and console operations
- Future platform-internal bulk operations (batch actions, workflow transitions)

An alternative considered was requiring a "system user" record for non-human operations. This was rejected because:

- It adds mandatory setup complexity to every host application
- `nil` clearly communicates "this was not done by a human user"
- Presenters can display nil as "System" or "—" via locale strings
- If a host app wants an explicit system user, they can set `LcpRuby::Current.user` in their jobs themselves

**Decision:** Fields are always `optional: true` (nullable). The callback never raises when `Current.user` is nil — it simply writes nil.

### `store_name: false` by default

When displaying "Created by" in a table or show page, the application needs a human-readable name. Two approaches:

1. **Denormalized snapshot** (`store_name: true`) — stores the user's name at the time of the operation. Self-contained, no JOIN needed, but stale if user renames.
2. **Association lookup** (`store_name: false`) — only stores the ID. Requires a JOIN or association load to display the name.

**Decision:** `store_name: false` by default. Most applications will display userstamps rarely (show page metadata, not every index column), and a JOIN is acceptable there. Applications that display the author in high-volume index tables can opt into `store_name: true`.

Name derivation for snapshot columns: strip `_id` suffix, append `_name`. Examples:
- `created_by_id` → `created_by_name`
- `updated_by_id` → `updated_by_name`
- `author_id` (custom) → `author_name`
- `last_editor_id` (custom) → `last_editor_name`

The user's display name is read from `LcpRuby::Current.user.name` — the platform's `User` model already validates presence of `name`.

### Callback strategy: `before_save` with `LcpRuby::Current`

The platform already provides `LcpRuby::Current.user` as a thread-safe accessor set by the controller on every request. The userstamps callback reads from this context:

```ruby
before_save :set_userstamps

def set_userstamps
  if new_record?
    self.created_by_id = LcpRuby::Current.user&.id
    self.created_by_name = LcpRuby::Current.user&.name  # only if store_name
  end
  self.updated_by_id = LcpRuby::Current.user&.id
  self.updated_by_name = LcpRuby::Current.user&.name    # only if store_name
end
```

Key properties:
- **Tolerant of nil** — safe navigation (`&.`) writes nil when no user is present
- **`created_by` only on create** — checked via `new_record?`, never overwritten on update
- **`updated_by` on every save** — including create (the creator is also the first updater)
- **Bypass via `update_columns`** — direct SQL updates skip callbacks, which is the expected Rails behavior for bulk/system operations

### Not added to `writable_fields` — same pattern as timestamps

A key question was whether to enforce read-only behavior at the model level (preventing the platform from setting values) or at the permission/presenter level.

Analysis of the existing architecture revealed that `writable_fields` controls **HTTP input** (strong parameters) and **form visibility** (ColumnSet), while `before_save` callbacks operate **directly on the AR instance**, bypassing strong params entirely. This is exactly the same pattern as `created_at` / `updated_at`:

1. Nobody adds `created_at` to their permissions YAML `writable` list
2. Rails timestamps callback sets them internally
3. Strong params never see them

**Decision:** No special `readonly` flag or model-level restriction needed. Userstamp fields simply should not be listed in `writable` fields in the permissions YAML. The callback sets them internally regardless of strong params. If a user accidentally adds `created_by_id` to their writable fields, the callback will overwrite whatever value was submitted — which is correct behavior.

### `update_columns` bypasses userstamps — by design

`update_columns` performs direct SQL and skips all ActiveRecord callbacks, including userstamps. This means `record.update_columns(title: "new")` will not update `updated_by_id`. This is consistent with how Rails timestamps work — `update_columns` also skips `updated_at`. The behavior is well-known, expected, and documented in Rails guides. No special handling is needed.

Similarly, `created_by_id` can technically be overwritten via `update_columns` — but no one does this accidentally, just as no one accidentally overwrites `created_at`.

### No index on name snapshot columns

When `store_name: true` is enabled, the `_name` columns are for **display only** — showing "Created by: John Doe" without a JOIN. They are not intended for searching or filtering. Adding indices would waste space for no benefit. If a user needs to search by author name, they should query through the FK association (which is indexed).

### Independent of Model Options Infrastructure

The [Model Options Infrastructure](model_options_infrastructure.md) design defines a standardized pipeline for model-level features. While userstamps could benefit from that infrastructure, it would mean blocking a simple, high-value feature on a medium-complexity prerequisite.

**Decision:** Implement userstamps as a standalone applicator now (like `PositioningApplicator`). The implementation is simple — one `before_save` callback, no pipeline ordering concerns, no `update_columns` bypass contract needed. When Model Options Infrastructure is implemented later, userstamps can be migrated into the unified pipeline with minimal changes.

## Design

### YAML Configuration

**Minimal (boolean):**

```yaml
# config/lcp_ruby/models/deal.yml
name: deal
timestamps: true
userstamps: true
fields:
  - name: title
    type: string
```

This adds `created_by_id` (bigint, nullable, indexed) and `updated_by_id` (bigint, nullable, indexed) columns automatically.

**Full (hash):**

```yaml
name: deal
userstamps:
  created_by: author_id
  updated_by: last_editor_id
  store_name: true
```

This adds `author_id`, `last_editor_id`, `author_name`, and `last_editor_name` columns.

**Configuration options:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `created_by` | string | `created_by_id` | Column name for creator FK |
| `updated_by` | string | `updated_by_id` | Column name for last modifier FK |
| `store_name` | boolean | `false` | Add denormalized `_name` snapshot columns |

### DSL Configuration

```ruby
LcpRuby.define_model :deal do
  timestamps
  userstamps                                    # boolean form
  userstamps store_name: true                   # with name snapshots
  userstamps created_by: :author_id,            # fully customized
             updated_by: :last_editor_id,
             store_name: true

  field :title, :string
end
```

### Schema Changes

`SchemaManager` adds columns conditionally:

```ruby
# Always added when userstamps enabled:
t.bigint  :created_by_id, null: true
t.bigint  :updated_by_id, null: true
t.index   :created_by_id
t.index   :updated_by_id

# Only when store_name: true:
t.string  :created_by_name, null: true
t.string  :updated_by_name, null: true
```

No database-level foreign key constraints. The `update_table!` path adds missing columns to existing tables (same as timestamps migration logic).

### Model Associations

The applicator adds optional `belongs_to` associations:

```ruby
belongs_to :created_by, class_name: "User", foreign_key: :created_by_id, optional: true
belongs_to :updated_by, class_name: "User", foreign_key: :updated_by_id, optional: true
```

Where `"User"` is resolved from `LcpRuby.configuration.user_class`. Association names are derived from the column name by stripping the `_id` suffix (e.g., `author_id` → `belongs_to :author`).

### Callback

A single `before_save` callback:

```ruby
# lib/lcp_ruby/model_factory/userstamps_applicator.rb
class UserstampsApplicator
  def initialize(model_class, model_definition)
    @model_class = model_class
    @model_definition = model_definition
  end

  def apply!
    return unless @model_definition.userstamps?

    creator_field = @model_definition.userstamps_creator_field    # e.g. "created_by_id"
    updater_field = @model_definition.userstamps_updater_field    # e.g. "updated_by_id"
    creator_name_field = @model_definition.userstamps_creator_name_field  # e.g. "created_by_name" or nil
    updater_name_field = @model_definition.userstamps_updater_name_field  # e.g. "updated_by_name" or nil

    @model_class.before_save do |record|
      user = LcpRuby::Current.user

      if record.new_record?
        record[creator_field] = user&.id
        record[creator_name_field] = user&.name if creator_name_field
      end

      record[updater_field] = user&.id
      record[updater_name_field] = user&.name if updater_name_field
    end
  end
end
```

### ModelDefinition Accessors

```ruby
# lib/lcp_ruby/metadata/model_definition.rb
def userstamps?
  @userstamps_config.present?
end

def userstamps_config
  @userstamps_config
end

def userstamps_creator_field
  userstamps_config&.fetch("created_by", "created_by_id") || "created_by_id"
end

def userstamps_updater_field
  userstamps_config&.fetch("updated_by", "updated_by_id") || "updated_by_id"
end

def userstamps_store_name?
  userstamps_config&.fetch("store_name", false) == true
end

def userstamps_creator_name_field
  return nil unless userstamps_store_name?
  userstamps_creator_field.sub(/_id$/, "_name")
end

def userstamps_updater_name_field
  return nil unless userstamps_store_name?
  userstamps_updater_field.sub(/_id$/, "_name")
end
```

Normalization in `ModelDefinition#initialize`:

```ruby
@userstamps_config = case raw_options["userstamps"]
  when true then {}                  # boolean → empty hash (all defaults)
  when Hash then raw_options["userstamps"]
  when false, nil then nil           # disabled
end
```

### ConfigurationValidator Rules

```ruby
def validate_userstamps(model)
  return unless model.userstamps?

  config = model.userstamps_config

  # Validate allowed keys
  allowed_keys = %w[created_by updated_by store_name]
  unknown = config.keys - allowed_keys
  if unknown.any?
    @errors << "Model '#{model.name}': userstamps has unknown keys: #{unknown.join(', ')}"
  end

  # Validate column names don't clash with defined fields
  [model.userstamps_creator_field, model.userstamps_updater_field].each do |col|
    if model.field(col)
      @errors << "Model '#{model.name}': userstamps column '#{col}' conflicts with an explicitly defined field"
    end
  end

  if model.userstamps_store_name?
    [model.userstamps_creator_name_field, model.userstamps_updater_name_field].each do |col|
      if model.field(col)
        @errors << "Model '#{model.name}': userstamps name column '#{col}' conflicts with an explicitly defined field"
      end
    end
  end

  # Warn if timestamps not enabled (unusual but not an error)
  unless model.timestamps?
    @warnings << "Model '#{model.name}': userstamps enabled without timestamps — consider enabling timestamps too"
  end
end
```

### Presenter Integration

Userstamp fields are **not automatically added** to presenters. Users add them explicitly like any other field:

```yaml
# In presenter YAML
form:
  sections:
    - title: Details
      fields:
        - { field: title }
        - { field: description }

show:
  sections:
    - title: Metadata
      fields:
        - { field: created_by_name, label: "Created by" }
        - { field: updated_by_name, label: "Last modified by" }
        - { field: created_at, label: "Created at" }
        - { field: updated_at, label: "Last modified at" }
```

With `store_name: false`, the user can reference the association in a template field or use the FK field directly:

```yaml
- { field: created_by_id, label: "Created by", display: { renderer: association } }
```

No special "user renderer" is needed — existing renderers (string for name snapshot, association for FK lookup) cover both cases.

**On forms:** If a user adds a userstamp field to a form section, it will only appear if listed in `writable` fields in permissions. Since userstamp fields should never be writable, they will be automatically hidden from forms — no extra logic needed.

### Nil Display

When `created_by_id` is nil (record created by a seed, job, or system operation), the display renders as empty or a locale-configurable fallback:

```yaml
# config/locales/en.yml
lcp_ruby:
  userstamps:
    unknown_user: "System"
```

This is handled by the existing renderer pipeline — nil values already render as "—" by default.

## Usage Examples

### Basic — Track creator and modifier

```yaml
# config/lcp_ruby/models/ticket.yml
name: ticket
timestamps: true
userstamps: true
fields:
  - { name: title, type: string }
  - { name: status, type: enum, values: [open, in_progress, resolved, closed] }
```

Result: `created_by_id`, `updated_by_id` columns added automatically.

### With name snapshots

```yaml
# config/lcp_ruby/models/document.yml
name: document
timestamps: true
userstamps:
  store_name: true
fields:
  - { name: title, type: string }
  - { name: content, type: rich_text }
```

Result: `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` columns.

### Custom column names

```yaml
# config/lcp_ruby/models/article.yml
name: article
timestamps: true
userstamps:
  created_by: author_id
  updated_by: last_editor_id
  store_name: true
fields:
  - { name: title, type: string }
  - { name: body, type: text }
```

Result: `author_id`, `last_editor_id`, `author_name`, `last_editor_name` columns. Associations: `belongs_to :author`, `belongs_to :last_editor`.

### DSL equivalent

```ruby
LcpRuby.define_model :article do
  timestamps
  userstamps created_by: :author_id,
             updated_by: :last_editor_id,
             store_name: true

  field :title, :string
  field :body, :text
end
```

## Implementation Plan

### Phase 1: Core userstamps

1. `ModelDefinition` — add `userstamps?`, `userstamps_config`, and accessor methods; normalize boolean/hash input
2. `SchemaManager` — add bigint columns (+ string columns for `store_name`) in `create_table!` and `update_table!`
3. `UserstampsApplicator` — new applicator with `before_save` callback
4. `Builder` — call `apply_userstamps` in the pipeline (after `apply_positioning`, before `apply_external_fields`)
5. `UserstampsApplicator` — add `belongs_to` associations
6. `ConfigurationValidator` — validate userstamps config (allowed keys, column conflicts, timestamps warning)
7. DSL — add `userstamps` method to `PresenterBuilder` / `ModelBuilder`

**Value:** Automatic creator/modifier tracking with zero boilerplate.

### Phase 2: Tests

1. Unit tests for `ModelDefinition` userstamps accessors (boolean, hash, defaults, name derivation)
2. Unit tests for `UserstampsApplicator` (callback behavior, nil user, new vs existing record)
3. Unit tests for `ConfigurationValidator` userstamps rules
4. Unit tests for `SchemaManager` column creation (with and without `store_name`)
5. Integration test — full CRUD cycle verifying userstamp values are set correctly
6. Integration test — verify userstamp fields are excluded from forms when not in writable fields

**Value:** Confidence that userstamps work correctly across all scenarios.

## Files to Modify

| File | Phase | Change |
|------|-------|--------|
| `lib/lcp_ruby/metadata/model_definition.rb` | 1 | Add `userstamps?`, config accessors, normalization |
| `lib/lcp_ruby/model_factory/schema_manager.rb` | 1 | Add userstamp columns in `create_table!` and `update_table!` |
| `lib/lcp_ruby/model_factory/userstamps_applicator.rb` | 1 | **New file** — `before_save` callback + `belongs_to` associations |
| `lib/lcp_ruby/model_factory/builder.rb` | 1 | Call `apply_userstamps` in pipeline |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | 1 | Add `validate_userstamps` method |
| `lib/lcp_ruby/dsl/model_builder.rb` | 1 | Add `userstamps` DSL method |
| `config/locales/en.yml` | 1 | Add `userstamps.unknown_user` locale key |
| `spec/lib/lcp_ruby/metadata/model_definition_spec.rb` | 2 | Test userstamps accessors |
| `spec/lib/lcp_ruby/model_factory/userstamps_applicator_spec.rb` | 2 | **New file** — callback tests |
| `spec/lib/lcp_ruby/metadata/configuration_validator_spec.rb` | 2 | Test userstamps validation |
| `spec/integration/userstamps_spec.rb` | 2 | **New file** — full CRUD integration test |
| `spec/fixtures/integration/userstamps_test/` | 2 | **New directory** — test fixtures (model + presenter YAML) |

## Related Documents

- **[Auditing](auditing.md):** Auditing tracks the full history of changes with user snapshots. Userstamps are a lightweight alternative that only tracks current creator and last modifier. Both features are complementary — userstamps provide quick "who created/modified this" without querying an audit log.
- **[Model Options Infrastructure](model_options_infrastructure.md):** Defines the unified pipeline for model-level features. Userstamps will be migrated into this pipeline when it is implemented. Current standalone applicator approach is intentional to avoid blocking on that prerequisite.
- **[Soft Delete](soft_delete.md):** When soft delete is implemented, `updated_by` will naturally track who discarded/restored a record (since discard is a regular `save` operation).

## Open Questions

None — all questions resolved during design.
