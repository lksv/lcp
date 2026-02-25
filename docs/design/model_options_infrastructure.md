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
- Design the infrastructure so it can evolve into a formal plugin system where model-level features are self-contained, independently distributable units

## Non-Goals

- Defining the features themselves (soft_delete, auditing — each has its own design document)
- Data retention policy (separate design document)
- Changing existing features (positioning, custom_fields) to use the new infrastructure retroactively — they can be migrated later if valuable
- Implementing the full plugin registry in the first phase — the initial implementation uses shared helpers with hardcoded pipeline; the plugin API is extracted later from real usage patterns

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

## Target Architecture: Model Feature Plugins

### Motivation

The eight integration points identified in the Problem section form a remarkably
regular pattern. Every model-level feature — soft_delete, auditing, workflow,
approval processes, versioning — needs the same set of hooks into the platform:
an option in YAML, a predicate on ModelDefinition, an Applicator, a pipeline
step, validation, schema, DSL method, and database columns.

When a pattern repeats this consistently, it is a strong signal that it can be
formalized into a **plugin contract**. Instead of each feature being hardcoded
into the core platform, features become self-contained units that register
themselves through a well-defined API. The core platform provides the
infrastructure; plugins provide the behavior.

This has concrete benefits:

1. **Leaner core** — the `lcp_ruby` gem ships only the model/presenter/permission
   engine. Features like soft_delete or auditing are opt-in dependencies, not
   mandatory code paths. Deployments that don't need auditing don't carry its
   weight.
2. **Independent release cycles** — a bug fix in auditing doesn't require a new
   core release. A new workflow plugin can be developed and tested in isolation.
3. **Third-party extensibility** — host applications or consulting teams can
   build custom model features (e.g., multi-tenant data isolation, compliance
   watermarking) using the same plugin API that built-in features use. No
   monkey-patching, no forking.
4. **Enforced contracts** — the plugin API makes implicit conventions explicit.
   Today, "every feature must handle `update_columns` bypass" is a prose rule.
   With a plugin API, the base class can provide hooks and warnings for it.

### Scope: Model Features vs. Platform Subsystems

Not everything in LCP Ruby is a model feature plugin. There are two distinct
categories of extensibility:

| Category | Examples | Pattern | Plugin candidate? |
|----------|----------|---------|-------------------|
| **Model features** | soft_delete, auditing, workflow, versioning, approval | `options:` in model YAML, Applicator in Builder pipeline | Yes |
| **Platform subsystems** | groups, roles, permissions, custom_fields, menu | `LcpRuby.configure`, own Registry/Setup/Contract | No |

Platform subsystems like Groups (see `groups_roles_and_org_structure.md`) follow
the **Registry/Setup/Contract** pattern — they have their own configuration
sources (YAML, DB, Host API), their own boot sequence, and they modify
platform-level behavior (e.g., PermissionEvaluator role resolution). They do
not fit the model option plugin pattern because they are not per-model
`true`-or-`Hash` options.

The plugin architecture described here applies specifically to model-level
features that integrate through the Builder pipeline.

### Plugin Contract

A model feature plugin provides implementations for each integration point.
The `ModelFeaturePlugin` base class defines the contract:

```ruby
# lib/lcp_ruby/model_feature_plugin.rb
module LcpRuby
  class ModelFeaturePlugin
    class << self
      # --- Identity ---

      # Unique feature name, used as YAML option key.
      # @example feature_name :soft_delete
      def feature_name(name = nil)
        name ? @feature_name = name : @feature_name
      end

      # --- Pipeline Integration ---

      # Declares where in the Builder pipeline this feature's Applicator runs.
      # @param after [Symbol, Array<Symbol>] core step(s) or feature(s) to run after
      # @param before [Symbol, Array<Symbol>] core step(s) or feature(s) to run before
      def pipeline(after: nil, before: nil)
        @pipeline_after = Array(after) if after
        @pipeline_before = Array(before) if before
      end

      # Optional soft dependencies on other plugins.
      # The plugin runs after these if they are present, but does not require them.
      # @param name [Symbol] feature name
      # @param optional [Boolean] if true, missing dependency is not an error
      def depends_on(name, optional: false)
        @dependencies ||= []
        @dependencies << { name: name, optional: optional }
      end

      # --- Components ---

      # The Applicator class called during Builder#build.
      # Must respond to .apply!(model_class, model_definition).
      def applicator(klass = nil)
        klass ? @applicator = klass : @applicator
      end

      # The Validator class called during ConfigurationValidator.
      # Must respond to .validate(model, errors).
      def validator(klass = nil)
        klass ? @validator = klass : @validator
      end

      # --- Option Schema ---

      # Allowed keys when the option is a Hash (not just `true`).
      def allowed_option_keys(keys = nil)
        keys ? @allowed_option_keys = keys : (@allowed_option_keys || [])
      end

      # Default values merged into an empty Hash when option is `true`.
      def option_defaults(defaults = nil)
        defaults ? @option_defaults = defaults : (@option_defaults || {})
      end

      # --- Schema ---

      # Block called during SchemaManager table creation.
      # Receives (table, model_definition, parsed_options).
      def schema(&block)
        block ? @schema_block = block : @schema_block
      end

      # --- DSL ---

      # Block that returns the normalized option value for ModelBuilder.
      # Receives the DSL method arguments.
      def dsl_method(&block)
        block ? @dsl_block = block : @dsl_block
      end

      # --- JSON Schema ---

      # Returns the JSON Schema fragment for this option (Hash).
      # Merged into model.json under properties.options.properties.
      def json_schema(schema = nil)
        schema ? @json_schema = schema : @json_schema
      end
    end
  end
end
```

### Plugin Registration and Discovery

Plugins register themselves with a central registry at boot time:

```ruby
# lib/lcp_ruby/model_feature_registry.rb
module LcpRuby
  class ModelFeatureRegistry
    attr_reader :features

    def initialize
      @features = {}
    end

    def register(plugin_class)
      name = plugin_class.feature_name
      raise ArgumentError, "Feature #{name} already registered" if @features.key?(name)

      @features[name] = plugin_class
      inject_model_definition_methods(plugin_class)
      inject_dsl_method(plugin_class)
    end

    # Returns plugins sorted by dependency order for the Builder pipeline.
    # Uses topological sort; raises on circular dependencies.
    def pipeline_order
      tsort_plugins(@features.values)
    end

    # Validates all registered features for a given model.
    # Called by ConfigurationValidator.
    def validate(model, errors)
      @features.each_value do |plugin|
        next unless model_feature_enabled?(model, plugin.feature_name)

        validate_option_shape(model, plugin, errors)
        plugin.validator&.validate(model, errors)
      end
    end

    private

    def model_feature_enabled?(model, feature_name)
      value = model.options[feature_name.to_s]
      value == true || value.is_a?(Hash)
    end

    # Auto-generates predicate and options methods on ModelDefinition.
    # soft_delete plugin → soft_delete? + soft_delete_options
    def inject_model_definition_methods(plugin)
      name = plugin.feature_name
      defaults = plugin.option_defaults

      LcpRuby::Metadata::ModelDefinition.class_eval do
        define_method(:"#{name}?") do
          boolean_or_hash_option(name.to_s).first
        end

        define_method(:"#{name}_options") do
          enabled, opts = boolean_or_hash_option(name.to_s)
          enabled ? defaults.merge(opts) : {}
        end
      end
    end

    # Auto-generates DSL method on ModelBuilder.
    def inject_dsl_method(plugin)
      name = plugin.feature_name
      dsl_block = plugin.dsl_block

      if dsl_block
        LcpRuby::Metadata::ModelBuilder.class_eval do
          define_method(name) do |*args, **kwargs|
            @options[name.to_s] = dsl_block.call(*args, **kwargs)
          end
        end
      else
        # Default: simple boolean-or-hash passthrough
        LcpRuby::Metadata::ModelBuilder.class_eval do
          define_method(name) do |value = true|
            @options[name.to_s] = value
          end
        end
      end
    end

    def validate_option_shape(model, plugin, errors)
      value = model.options[plugin.feature_name.to_s]
      return unless value

      unless value == true || value.is_a?(Hash)
        errors << "Model '#{model.name}': #{plugin.feature_name} must be " \
                  "true or a Hash, got #{value.class}"
        return
      end

      return if value == true

      allowed = plugin.allowed_option_keys.map(&:to_s)
      unknown = value.keys - allowed
      if unknown.any?
        errors << "Model '#{model.name}': #{plugin.feature_name} has unknown " \
                  "keys: #{unknown.join(', ')}. Allowed: #{allowed.join(', ')}"
      end
    end

    def tsort_plugins(plugins)
      # Build adjacency list from pipeline/depends_on declarations
      # and perform topological sort.
      # Implementation uses TSort from Ruby stdlib.
      # Raises TSort::Cyclic on circular dependencies.
      graph = build_dependency_graph(plugins)
      TSort.tsort(
        ->(&b) { graph.each_key(&b) },
        ->(node, &b) { (graph[node] || []).each(&b) }
      )
    end
  end
end
```

### Builder Pipeline with Plugins

With the plugin registry, the Builder no longer hardcodes feature-specific
`apply_*` methods. Instead, it iterates over registered plugins at the
appropriate point in the pipeline:

```ruby
# lib/lcp_ruby/model_factory/builder.rb
def build
  create_model_class
  apply_table_name
  apply_enums
  apply_validations
  apply_transforms
  apply_associations
  apply_attachments
  apply_scopes

  # ── Plugin hook ──────────────────────────────────────
  apply_registered_features
  # ─────────────────────────────────────────────────────

  apply_callbacks
  apply_defaults
  apply_computed
  apply_positioning
  apply_external_fields
  apply_model_extensions
  apply_custom_fields
  apply_label_method
  validate_external_methods!
end

private

def apply_registered_features
  LcpRuby.model_feature_registry.pipeline_order.each do |plugin|
    next unless @model_definition.send(:"#{plugin.feature_name}?")

    plugin.applicator.apply!(@model_class, @model_definition)
  end
end
```

Note that the core pipeline steps (`apply_callbacks`, `apply_positioning`, etc.)
remain hardcoded. Only model-option features that follow the `true`-or-`Hash`
pattern are dispatched through the registry. This keeps the boundary clear —
core structural steps are not pluggable, behavioral features are.

### Cross-Plugin Communication

Plugins sometimes need to interact. The primary example: soft_delete uses
`update_columns` which bypasses `after_save`, so auditing never fires for
discard operations. With plugins as independent units, this cross-cutting
concern needs a defined pattern.

**Approach: Optional awareness, not mandatory coupling.**

A plugin declares optional dependencies. When the dependency is present, it
adapts its behavior:

```ruby
# lcp_ruby-soft_delete plugin
class SoftDeletePlugin < LcpRuby::ModelFeaturePlugin
  feature_name :soft_delete
  depends_on :auditing, optional: true   # ← "I know about auditing"

  # In the Applicator's discard! method:
  def discard!(by: nil)
    update_columns(attrs)

    # If auditing plugin is active on this model, notify it explicitly.
    if model_def.respond_to?(:auditing?) && model_def.auditing?
      LcpRuby::Auditing::AuditWriter.log(
        action: :discard, record: self, ...
      )
    end
  end
end
```

This is the same explicit dispatch pattern from section 2, but now framed as
a plugin-to-plugin contract. The rule remains: **any code that uses
`update_columns` or `update_all` on a model where auditing may be active must
check and dispatch explicitly.** The plugin base class can document this
contract and even provide a convenience method:

```ruby
# In ModelFeaturePlugin base:
def self.notify_audit(record, action:, changes: {})
  return unless record.class.model_definition.respond_to?(:auditing?)
  return unless record.class.model_definition.auditing?

  LcpRuby::Auditing::AuditWriter.log(
    action: action,
    record: record,
    options: record.class.model_definition.auditing_options,
    model_definition: record.class.model_definition,
    nested_associations: []
  )
end
```

This is an opt-in convenience — plugins that bypass callbacks can call
`self.class.notify_audit(self, action: :discard)` — but it's not enforced
at the type level. The contract is documented and discoverable, not hidden
in prose.

### Example: Soft Delete as a Plugin Gem

To illustrate the full plugin structure, here is how soft_delete would look
as an independent gem:

```
lcp_ruby-soft_delete/
  ├── lib/
  │   └── lcp_ruby/
  │       └── soft_delete/
  │           ├── plugin.rb           # ModelFeaturePlugin subclass
  │           ├── applicator.rb       # Builder pipeline step
  │           ├── validator.rb        # ConfigurationValidator extension
  │           └── railtie.rb          # Auto-registration on Rails boot
  ├── spec/
  │   └── ...
  ├── lcp_ruby-soft_delete.gemspec
  └── Gemfile
```

```ruby
# lib/lcp_ruby/soft_delete/plugin.rb
module LcpRuby
  module SoftDelete
    class Plugin < LcpRuby::ModelFeaturePlugin
      feature_name :soft_delete

      pipeline after: :apply_scopes
      depends_on :auditing, optional: true

      applicator LcpRuby::SoftDelete::Applicator
      validator  LcpRuby::SoftDelete::Validator

      allowed_option_keys %w[column]
      option_defaults "column" => "discarded_at"

      json_schema({
        "oneOf" => [
          { "type" => "boolean", "const" => true },
          {
            "type" => "object",
            "properties" => {
              "column" => { "type" => "string" }
            },
            "additionalProperties" => false
          }
        ]
      })

      schema do |table, _model_def, opts|
        col = opts.fetch("column", "discarded_at")
        table.datetime col unless table.column_exists?(col)
      end

      dsl_method do |value = true, column: nil|
        if column
          { "column" => column.to_s }
        else
          value
        end
      end
    end
  end
end
```

```ruby
# lib/lcp_ruby/soft_delete/railtie.rb
module LcpRuby
  module SoftDelete
    class Railtie < Rails::Railtie
      initializer "lcp_ruby.soft_delete" do
        LcpRuby.model_feature_registry.register(LcpRuby::SoftDelete::Plugin)
      end
    end
  end
end
```

The host application's Gemfile:

```ruby
gem "lcp_ruby"
gem "lcp_ruby-soft_delete"   # opt-in
gem "lcp_ruby-auditing"      # opt-in
```

### Phased Implementation Plan

Extracting a plugin system from zero usage data leads to over-engineered
abstractions. The implementation follows three phases, where each phase is
justified by concrete needs from the previous one:

**Phase 1: Shared helpers, hardcoded pipeline (implement now)**

Implement soft_delete and auditing as internal code in `lib/lcp_ruby/`,
using the shared helpers defined in this document (`boolean_or_hash_option`,
`validate_boolean_or_hash_option`, `create_log_table`). The Builder pipeline
has hardcoded `apply_soft_delete` and `apply_auditing` calls. This is the
design described in sections 1–8 above.

Why not plugins yet: with only two features, the plugin registry would be
pure overhead. The shared helpers already eliminate the boilerplate.

**Phase 2: Extract ModelFeaturePlugin + Registry (after 2–3 features)**

Once there are 2–3 implemented features following the same pattern, extract
the `ModelFeaturePlugin` base class and `ModelFeatureRegistry`. This is a
refactoring — the features already follow the pattern from phase 1, so
extracting the registry is mechanical:

- Move each feature's Applicator + Validator into a Plugin subclass
- Replace hardcoded `apply_*` calls in Builder with `apply_registered_features`
- Replace hardcoded `validate_*` calls in ConfigurationValidator with
  registry-delegated validation
- Auto-generate ModelDefinition predicate/options methods via registry

At this point, the plugin API is derived from real code, not speculative
design. The contract reflects what features actually need.

**Phase 3: Separate gems (when needed)**

Move features into independent gems (`lcp_ruby-soft_delete`,
`lcp_ruby-auditing`, etc.) when any of these conditions arise:

- A host application needs a feature subset (lean deployment)
- A feature needs an independent release cycle (e.g., frequent auditing
  updates without core churn)
- A third party wants to build a custom model feature
- Testing benefits from gem-level isolation

Phase 2→3 is mostly moving files into gem structures and adding Railtie
auto-registration. The plugin API doesn't change.

**Phase transitions are cheap** because each phase builds on the previous one:

| Transition | Effort | Risk |
|------------|--------|------|
| 1 → 2 | Mechanical refactoring — code already follows the pattern | Low — no behavior change, just structural extraction |
| 2 → 3 | File relocation + gemspec + Railtie | Low — plugin API is stable from phase 2 |
| Skip to 3 | Design plugin API speculatively, implement features against it | High — API will likely need breaking changes once real features reveal actual needs |

## Implementation

### File Changes Summary

**Phase 1 (implement now):**

| File | Change |
|------|--------|
| `lib/lcp_ruby/model_factory/builder.rb` | Extend pipeline with `apply_soft_delete` and `apply_auditing` in correct order |
| `lib/lcp_ruby/metadata/model_definition.rb` | Add `boolean_or_hash_option` helper; add `soft_delete?`/`soft_delete_options`/`auditing?`/`auditing_options` |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Add `validate_boolean_or_hash_option` helper; add `validate_soft_delete`, `validate_auditing`, `validate_dependent_discard` |
| `lib/lcp_ruby/model_factory/schema_manager.rb` | Add `create_log_table` class method for shared log table creation |
| `lib/lcp_ruby/auditing/user_snapshot.rb` | **New** — shared user snapshot capture |
| `lib/lcp_ruby/configuration.rb` | Add `audit_writer` accessor |

**Phase 2 (after 2–3 features are implemented):**

| File | Change |
|------|--------|
| `lib/lcp_ruby/model_feature_plugin.rb` | **New** — base class for model feature plugins |
| `lib/lcp_ruby/model_feature_registry.rb` | **New** — plugin registration, pipeline ordering, validation dispatch |
| `lib/lcp_ruby/model_factory/builder.rb` | Replace hardcoded `apply_soft_delete`/`apply_auditing` with `apply_registered_features` |
| `lib/lcp_ruby/metadata/model_definition.rb` | Remove manual predicate/options methods (auto-generated by registry) |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Replace manual `validate_soft_delete`/`validate_auditing` with registry-delegated validation |

### Implementation Order

**Phase 1 order** (features within the hardcoded infrastructure):

1. **This infrastructure** — shared helpers, pipeline order, `create_log_table`, `UserSnapshot`
2. **Soft delete** — uses infrastructure, adds `SoftDeleteApplicator`, controller changes
3. **Auditing** — uses infrastructure, adds `AuditingApplicator`, `AuditWriter` (with explicit dispatch from soft delete)

Soft delete should be implemented before auditing because:
- Auditing depends on soft delete awareness (the `update_columns` bypass notification)
- Soft delete has no dependency on auditing
- The auditing `AuditingApplicator` needs to check `model_definition.soft_delete?` to know whether to expect `:discard`/`:undiscard` actions

**Phase 2** is triggered after the third model feature is implemented (likely
workflow or versioning). At that point, extract `ModelFeaturePlugin` and
`ModelFeatureRegistry` from the patterns that have proven stable across three
real implementations.

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

1. **Should `positioning` be migrated to the `options` hash?** Currently, `positioning` is a top-level YAML key with its own `@positioning_config` attribute on `ModelDefinition`. Moving it under `options` (like `soft_delete` and `auditing`) would make the pattern consistent, but it's a breaking change to YAML format. Recommendation: defer — positioning works fine, and this is a pre-production project so it can be migrated later if the inconsistency bothers. If the plugin system is extracted in phase 2, positioning could become the first migrated legacy feature.

2. **Should the `create_log_table` helper live on `SchemaManager` or a separate `LogTableBuilder`?** `SchemaManager` already handles table creation, so adding a class method there is natural. But if log tables grow more complex (partitioning, archival), a separate class might be warranted. Recommendation: start on `SchemaManager`, extract later if needed.

3. **Should `UserSnapshot` be in the `Auditing` namespace or a top-level `LcpRuby::UserSnapshot`?** It's used by auditing first, but workflow and other features will use it too. Recommendation: keep in `Auditing` namespace for now — it can be moved when a second consumer appears. Premature extraction adds no value.

4. **Should plugins be able to add core pipeline steps, or only feature steps?** The current design restricts plugins to the feature hook point between `apply_scopes` and `apply_callbacks`. A plugin that needs to run after `apply_model_extensions` (e.g., a feature that wraps host-defined methods) would not fit this model. Recommendation: start with the single hook point. If a real need arises, consider multiple named hook points (`:after_scopes`, `:after_callbacks`, `:after_extensions`) rather than making the entire pipeline pluggable.

5. **Should the plugin registry support plugin priorities within the same dependency level?** Topological sort produces a valid order but the exact sequence among independent plugins is undefined. If two unrelated plugins both run after `apply_scopes` with no mutual dependency, their relative order is arbitrary. Recommendation: accept arbitrary order for independent plugins. If order matters, plugins should declare `depends_on` — that's what it's for. Artificial priority numbers create hidden coupling.

6. **Should plugins be able to expose configuration in `LcpRuby.configure`?** For example, `lcp_ruby-auditing` might want `config.audit_max_changes_size`. Currently, `Configuration` is a core class. Options: (a) plugins add accessors via `class_eval`, (b) plugins use a namespaced `config.plugin_options[:auditing]` hash, (c) plugins define their own configuration object. Recommendation: defer until phase 2 — the first features can use simple constants or `option_defaults`.
