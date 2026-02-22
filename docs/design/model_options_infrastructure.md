# Design: Model Options Infrastructure

**Status:** Proposed
**Date:** 2026-02-22

## Problem

As the platform grows, more model-level features are being added — `positioning`, `custom_fields`, `soft_delete`, `auditing`, and more will follow (workflow, approval processes, etc.). Each feature follows the same integration pattern:

1. A `true`-or-`Hash` option in YAML/DSL
2. A predicate + options method on `ModelDefinition`
3. A new `*Applicator` class in `ModelFactory`
4. A new step in the `Builder#build` pipeline
5. Validation in `ConfigurationValidator`
6. Schema in `model.json`
7. A DSL method in `ModelBuilder`
8. Columns/tables in `SchemaManager`

Today, each feature implements this pattern independently, leading to:

- **Copy-paste boilerplate** — every feature re-implements the same `true`-vs-`Hash` parsing, predicate methods, and validation structure
- **Pipeline ordering conflicts** — the `soft_delete` and `auditing` design documents each propose different `Builder#build` orderings without considering each other
- **`update_columns` blind spot** — features that bypass ActiveRecord callbacks (soft delete uses `update_columns` intentionally) silently break callback-dependent features (auditing relies on `after_save`)
- **No unified event/log strategy** — auditing proposes `lcp_audit_logs`, workflow will propose `workflow_audit_logs`, and future features will add more similar tables

This document defines shared infrastructure that feature-specific designs can reference instead of each reinventing the same patterns.

## Goals

- Define the canonical `Builder#build` pipeline order, accounting for all current and planned features
- Establish a mechanism for `update_columns`-based operations to notify auditing
- Provide reusable helpers for the "boolean-or-hash model option" pattern
- Decide on unified vs. per-feature log tables

## Non-Goals

- Defining the features themselves (soft_delete, auditing — each has its own design document)
- Data retention policy (separate design document)
- Changing existing features (positioning, custom_fields) to use the new infrastructure retroactively — they can be migrated later if valuable

## Design

### 1. Canonical Builder Pipeline Order

The `Builder#build` method defines the order in which features are applied to a dynamic model class. The order matters because later steps may depend on earlier ones (e.g., auditing needs to know about soft delete; custom fields needs associations to exist).

**Current pipeline** (from `builder.rb`):

```
create_model_class
apply_table_name
apply_enums
apply_validations
apply_transforms
apply_associations
apply_attachments
apply_scopes
apply_callbacks
apply_defaults
apply_computed
apply_positioning
apply_external_fields
apply_model_extensions
apply_custom_fields
apply_label_method
validate_external_methods!
```

**Extended pipeline** with soft_delete and auditing:

```
create_model_class
apply_table_name
apply_enums
apply_validations
apply_transforms
apply_associations          # AR associations (has_many, belongs_to, etc.)
apply_attachments           # Active Storage macros
apply_scopes                # User-defined scopes from YAML
apply_soft_delete           # ← NEW: scopes (kept/discarded), instance methods (discard!/undiscard!)
apply_callbacks             # User-defined event callbacks
apply_auditing              # ← NEW: after_save/after_destroy audit callbacks
apply_defaults
apply_computed
apply_positioning
apply_external_fields
apply_model_extensions      # Host app extensions (may add callbacks, methods)
apply_custom_fields
apply_label_method
validate_external_methods!
```

**Rationale for ordering:**

| Step | Must come after | Reason |
|------|----------------|--------|
| `apply_soft_delete` | `apply_scopes` | Adds `kept`/`discarded`/`with_discarded` scopes — same mechanism as user-defined scopes |
| `apply_soft_delete` | `apply_associations` | Reads association definitions to identify `dependent: :discard` targets |
| `apply_auditing` | `apply_soft_delete` | Auditing must be aware of soft delete (to handle `update_columns` bypass) |
| `apply_auditing` | `apply_callbacks` | Audit callbacks should fire after user-defined callbacks (user logic completes first, then audit records the result) |
| `apply_auditing` | `apply_associations` | Reads nested_attributes associations for aggregated child change tracking |

**Future steps** should be inserted according to these dependency rules. For example, a future `apply_workflow` would go after `apply_soft_delete` (workflow may prevent discard) and before `apply_auditing` (workflow transitions should be auditable).

### 2. Tracked Change Notifications (`update_columns` Bypass)

#### The Problem

ActiveRecord's `update_columns` skips all callbacks, including `after_save`. This is intentional — features like soft delete use it because discard should always succeed regardless of validation state.

But auditing relies on `after_save` callbacks to detect changes. When soft delete calls `update_columns(discarded_at: Time.current)`, auditing never fires.

This affects any current or future feature that uses `update_columns`:
- **Soft delete** — `discard!`, `undiscard!`
- **Positioning** — the `positioning` gem uses `update_all` for batch position updates
- **Future bulk operations** — batch updates, counter caches, etc.

#### Solution: Explicit `AuditWriter.log` Dispatch

Rather than building a complex instrumentation layer, the simplest correct approach is: **features that bypass callbacks are responsible for calling `AuditWriter.log` directly**.

This keeps the contract explicit and auditable in code:

```ruby
# In SoftDeleteApplicator — discard! method
def discard!(by: nil)
  raise ActiveRecord::ActiveRecordError, "Record is already discarded" if discarded?

  old_value = send(col)
  attrs = { col => Time.current }
  # ...tracking columns...
  update_columns(attrs)

  # Explicit audit notification (bypasses after_save)
  if model_def.auditing?
    LcpRuby::Auditing::AuditWriter.log(
      action: :discard,
      record: self,
      options: model_def.auditing_options,
      model_definition: model_def,
      nested_associations: []
    )
  end

  # ...cascade discard, event dispatch...
end
```

**Contract for future features:**

Any code that uses `update_columns` or `update_all` on an auditable model **must** check `model_definition.auditing?` and call `AuditWriter.log` explicitly. This is documented here as a platform-wide rule, not buried in individual feature designs.

The `AuditWriter.log` method already handles the case where `action` is not a standard CRUD action — it accepts any symbol (`:discard`, `:undiscard`, `:reposition`, etc.) and records it in the `action` column.

**Why not a wrapper method?**

A `tracked_update_columns` wrapper was considered:

```ruby
# Considered but rejected:
def tracked_update_columns(attrs)
  update_columns(attrs)
  AuditWriter.log(...) if auditing?
end
```

This doesn't work well because:
- The caller knows the semantic action (`:discard`, `:undiscard`) but the wrapper doesn't
- The caller may need to compute changes differently (soft delete tracks `discarded_at`, positioning tracks `position`)
- Cascade operations (discard children) need to happen between `update_columns` and audit logging

Explicit dispatch is clearer and more flexible.

### 3. Model Option Accessor Pattern

Every model-level feature that uses a `true`-or-`Hash` configuration follows the same pattern on `ModelDefinition`. Instead of each feature adding its own bespoke methods, a shared helper standardizes access.

#### Current State (positioning)

Positioning is stored as a separate `@positioning_config` attribute on `ModelDefinition`, parsed in `from_hash` via `normalize_positioning`. This is the odd one out — all other options live in `@options`.

#### Current State (custom_fields, timestamps)

```ruby
def custom_fields_enabled?
  options.fetch("custom_fields", false) == true
end

def timestamps?
  options.fetch("timestamps", true)
end
```

These are boolean-only — no Hash variant.

#### Pattern for `true`-or-`Hash` Options

Soft delete and auditing both support `true` (use defaults) or `Hash` (custom configuration). The pattern:

```ruby
# On ModelDefinition:

def soft_delete?
  value = options["soft_delete"]
  value == true || value.is_a?(Hash)
end

def soft_delete_options
  value = options["soft_delete"]
  case value
  when true then {}
  when Hash then value
  else {}
  end
end

def soft_delete_column
  soft_delete_options.fetch("column", "discarded_at")
end
```

This repeats identically for `auditing?` / `auditing_options`, and will repeat for every future feature.

#### Shared Helper

Add a private helper to `ModelDefinition` that encapsulates the pattern:

```ruby
# lib/lcp_ruby/metadata/model_definition.rb

private

# Returns [enabled?, options_hash] for a true-or-Hash model option.
# Used by feature predicate/accessor methods.
def boolean_or_hash_option(key, default: false)
  value = options[key]
  case value
  when true then [true, {}]
  when Hash then [true, value]
  else [default, {}]
  end
end
```

Feature methods become one-liners:

```ruby
def soft_delete?
  boolean_or_hash_option("soft_delete").first
end

def soft_delete_options
  boolean_or_hash_option("soft_delete").last
end

def auditing?
  boolean_or_hash_option("auditing").first
end

def auditing_options
  boolean_or_hash_option("auditing").last
end
```

This is a minor DRY improvement — the real value is establishing the pattern so future features don't invent their own parsing.

### 4. ConfigurationValidator Pattern

Each feature needs validation in `ConfigurationValidator`. The validation follows a repeatable structure:

1. Check if feature is enabled on the model
2. Validate the option value type (`true` or valid `Hash`)
3. Reject unknown keys in the Hash
4. Validate field references (do referenced fields exist on the model?)
5. Cross-reference with other models (e.g., `dependent: :discard` target must have `soft_delete`)
6. Emit warnings for non-fatal inconsistencies

#### Shared Validation Helper

A helper for the common "validate `true`-or-`Hash` option with allowed keys" pattern:

```ruby
# In ConfigurationValidator:

private

# Validates a model option that accepts true or a Hash with known keys.
# Returns the parsed Hash (or empty hash for true) if valid, nil if invalid.
def validate_boolean_or_hash_option(model, option_name, allowed_keys: [])
  value = model.options[option_name]
  return nil unless value

  unless value == true || value.is_a?(Hash)
    @errors << "Model '#{model.name}': #{option_name} must be true or a Hash, got #{value.class}"
    return nil
  end

  return {} if value == true

  unknown = value.keys - allowed_keys.map(&:to_s)
  if unknown.any?
    @errors << "Model '#{model.name}': #{option_name} has unknown keys: #{unknown.join(', ')}. " \
               "Allowed keys: #{allowed_keys.join(', ')}"
  end

  value
end
```

Feature-specific validation methods use it:

```ruby
def validate_soft_delete(model)
  opts = validate_boolean_or_hash_option(model, "soft_delete", allowed_keys: %w[column])
  return unless opts

  # Feature-specific validation...
  if opts["column"].present? && !opts["column"].is_a?(String)
    @errors << "Model '#{model.name}': soft_delete.column must be a string"
  end
end

def validate_auditing(model)
  opts = validate_boolean_or_hash_option(model, "auditing",
    allowed_keys: %w[only ignore track_associations track_attachments expand_custom_fields expand_json_fields])
  return unless opts

  # Feature-specific validation...
  if opts["only"] && opts["ignore"]
    @errors << "Model '#{model.name}': auditing cannot have both 'only' and 'ignore'"
  end
end
```

The validator's `validate_models` method gains new calls:

```ruby
def validate_models
  loader.model_definitions.each_value do |model|
    validate_model_fields(model)
    validate_model_scopes(model)
    validate_model_events(model)
    validate_display_templates(model)
    validate_positioning(model)
    validate_soft_delete(model)          # ← new
    validate_auditing(model)             # ← new
    validate_dependent_discard(model)    # ← new (cross-model)
  end
end
```

### 5. DSL Model Builder Pattern

Every `true`-or-`Hash` model option needs a DSL method in `ModelBuilder`. The pattern:

```ruby
# Simple boolean
def feature_name(value = true)
  @options["feature_name"] = value
end

# Boolean or keyword options
def feature_name(value = true, **options)
  if options.any?
    @options["feature_name"] = options.transform_keys(&:to_s)
  else
    @options["feature_name"] = value
  end
end
```

For soft_delete and auditing:

```ruby
def soft_delete(value = true, column: nil)
  if column
    @options["soft_delete"] = { "column" => column.to_s }
  else
    @options["soft_delete"] = value
  end
end

def auditing(value = true, **options)
  if options.any?
    opts = {}
    opts["only"] = options[:only].map(&:to_s) if options[:only]
    opts["ignore"] = options[:ignore].map(&:to_s) if options[:ignore]
    opts["track_associations"] = options[:track_associations] if options.key?(:track_associations)
    opts["track_attachments"] = options[:track_attachments] if options.key?(:track_attachments)
    opts["expand_custom_fields"] = options[:expand_custom_fields] if options.key?(:expand_custom_fields)
    opts["expand_json_fields"] = options[:expand_json_fields]&.map(&:to_s) if options[:expand_json_fields]
    @options["auditing"] = opts
  else
    @options["auditing"] = value
  end
end
```

No shared abstraction is needed here — each DSL method has feature-specific keyword arguments that don't generalize well.

### 6. JSON Schema Pattern

Each `true`-or-`Hash` option uses the same `oneOf` pattern in `model.json`:

```json
"feature_name": {
  "oneOf": [
    { "type": "boolean", "const": true },
    {
      "type": "object",
      "properties": { ... },
      "additionalProperties": false
    }
  ]
}
```

Both `soft_delete` and `auditing` add their schemas under `properties.options.properties` in `model.json`. No shared infrastructure needed — just the documented pattern.

### 7. Unified vs. Per-Feature Log Tables

#### Options Considered

**Option A: Per-feature tables**
- `lcp_audit_logs` — data change audit (auditing feature)
- `workflow_audit_logs` — state machine transitions (workflow feature, future)
- `approval_logs` — approval process records (approval feature, future)

**Option B: Single unified `lcp_event_logs` table**
- One table with `event_type` discriminator column
- All features write to the same table
- Shared indexes, shared query patterns

**Option C: Shared schema, separate tables**
- Each feature owns its table, but tables follow a common column convention
- `SchemaManager` provides a helper for creating "log-style" tables

#### Decision: Option A (per-feature tables) with shared schema conventions

Per-feature tables are preferred because:

1. **Query performance** — audit logs are queried by `(auditable_type, auditable_id)` while workflow logs are queried by `(workflow_name, record_id, transition)`. Different query patterns benefit from different indexes.
2. **Schema evolution** — each feature's log table has feature-specific columns (`changes_data` for audit, `from_state`/`to_state` for workflow). A unified table would accumulate nullable columns.
3. **Retention** — different log types may have different retention policies. Separate tables make selective purge simpler.
4. **Simplicity** — no discriminator column, no "which columns apply to which event_type" confusion.

However, all log tables should follow **shared conventions**:

| Column | Type | Purpose |
|--------|------|---------|
| `id` | `bigint PK` | Standard primary key |
| `*_type` | `string NOT NULL` | Polymorphic model type (lcp model name, not Ruby class name) |
| `*_id` | `bigint NOT NULL` | Record ID |
| `user_id` | `bigint` | Who performed the action |
| `user_snapshot` | `jsonb` | User details at time of action (denormalized) |
| `metadata` | `jsonb` | Extra context (request_id, IP, source) |
| `created_at` | `datetime NOT NULL` | When the action occurred |

Feature-specific columns are added alongside these shared ones.

`SchemaManager` can provide a helper for creating log tables:

```ruby
def self.create_log_table(table_name, record_prefix:)
  connection = ActiveRecord::Base.connection
  return if connection.table_exists?(table_name)

  connection.create_table(table_name) do |t|
    t.string   :"#{record_prefix}_type", null: false
    t.bigint   :"#{record_prefix}_id",   null: false
    t.bigint   :user_id
    t.column   :user_snapshot, LcpRuby.json_column_type
    t.column   :metadata, LcpRuby.json_column_type
    t.datetime :created_at, null: false
    yield t if block_given?
  end

  connection.add_index table_name,
    [:"#{record_prefix}_type", :"#{record_prefix}_id", :created_at],
    name: "idx_#{table_name}_on_record_and_time"
  connection.add_index table_name,
    [:user_id, :created_at],
    name: "idx_#{table_name}_on_user_and_time"
  connection.add_index table_name,
    [:created_at],
    name: "idx_#{table_name}_on_time"
end
```

Usage from auditing:

```ruby
SchemaManager.create_log_table("lcp_audit_logs", record_prefix: "auditable") do |t|
  t.string :action, null: false
  t.column :changes_data, LcpRuby.json_column_type, null: false, default: {}
end
```

Usage from a future workflow feature:

```ruby
SchemaManager.create_log_table("lcp_workflow_logs", record_prefix: "record") do |t|
  t.string :workflow_name, null: false
  t.string :transition_name, null: false
  t.string :from_state, null: false
  t.string :to_state, null: false
  t.text   :comment
end
```

### 8. User Snapshot Helper

Both auditing and workflow logs need to capture a snapshot of the acting user. This should be a shared utility, not reimplemented per feature:

```ruby
# lib/lcp_ruby/auditing/user_snapshot.rb
module LcpRuby
  module Auditing
    module UserSnapshot
      def self.capture(user)
        return nil unless user

        snapshot = { "id" => user.id }
        snapshot["email"] = user.email if user.respond_to?(:email)
        snapshot["name"] = user.name if user.respond_to?(:name)
        if user.respond_to?(LcpRuby.configuration.role_method)
          snapshot["role"] = user.send(LcpRuby.configuration.role_method)
        end
        snapshot
      end
    end
  end
end
```

The auditing `AuditWriter` and future workflow log writer both call `UserSnapshot.capture(Current.user)`.

## Implementation

### File Changes Summary

| File | Change |
|------|--------|
| `lib/lcp_ruby/model_factory/builder.rb` | Extend pipeline with `apply_soft_delete` and `apply_auditing` in correct order |
| `lib/lcp_ruby/metadata/model_definition.rb` | Add `boolean_or_hash_option` helper; add `soft_delete?`/`soft_delete_options`/`auditing?`/`auditing_options` |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Add `validate_boolean_or_hash_option` helper; add `validate_soft_delete`, `validate_auditing`, `validate_dependent_discard` |
| `lib/lcp_ruby/model_factory/schema_manager.rb` | Add `create_log_table` class method for shared log table creation |
| `lib/lcp_ruby/auditing/user_snapshot.rb` | **New** — shared user snapshot capture |
| `lib/lcp_ruby/configuration.rb` | Add `audit_writer` accessor |

### Implementation Order

1. **This infrastructure** — shared helpers, pipeline order, `create_log_table`, `UserSnapshot`
2. **Soft delete** — uses infrastructure, adds `SoftDeleteApplicator`, controller changes
3. **Auditing** — uses infrastructure, adds `AuditingApplicator`, `AuditWriter` (with explicit dispatch from soft delete)

Soft delete should be implemented before auditing because:
- Auditing depends on soft delete awareness (the `update_columns` bypass notification)
- Soft delete has no dependency on auditing
- The auditing `AuditingApplicator` needs to check `model_definition.soft_delete?` to know whether to expect `:discard`/`:undiscard` actions

## Updates to Feature Design Documents

After this infrastructure document is accepted, the following sections in feature design documents should be updated to reference it:

### `soft_delete.md`

- **Builder pipeline**: Reference this document for canonical ordering instead of proposing its own
- **ModelDefinition**: Use `boolean_or_hash_option` helper
- **ConfigurationValidator**: Use `validate_boolean_or_hash_option` helper
- **Add**: Explicit `AuditWriter.log` calls in `discard!` and `undiscard!` (guarded by `model_definition.auditing?`)

### `auditing.md`

- **Builder pipeline**: Reference this document for canonical ordering instead of proposing its own
- **ModelDefinition**: Use `boolean_or_hash_option` helper
- **ConfigurationValidator**: Use `validate_boolean_or_hash_option` helper
- **SchemaManager**: Use `create_log_table` helper instead of inline table creation
- **UserSnapshot**: Use shared `UserSnapshot.capture` instead of inline implementation
- **Interaction with Soft Delete**: Reference this document's "Tracked Change Notifications" section instead of describing the bypass problem independently

## Open Questions

1. **Should `positioning` be migrated to the `options` hash?** Currently, `positioning` is a top-level YAML key with its own `@positioning_config` attribute on `ModelDefinition`. Moving it under `options` (like `soft_delete` and `auditing`) would make the pattern consistent, but it's a breaking change to YAML format. Recommendation: defer — positioning works fine, and this is a pre-production project so it can be migrated later if the inconsistency bothers.

2. **Should the `create_log_table` helper live on `SchemaManager` or a separate `LogTableBuilder`?** `SchemaManager` already handles table creation, so adding a class method there is natural. But if log tables grow more complex (partitioning, archival), a separate class might be warranted. Recommendation: start on `SchemaManager`, extract later if needed.

3. **Should `UserSnapshot` be in the `Auditing` namespace or a top-level `LcpRuby::UserSnapshot`?** It's used by auditing first, but workflow and other features will use it too. Recommendation: keep in `Auditing` namespace for now — it can be moved when a second consumer appears. Premature extraction adds no value.
