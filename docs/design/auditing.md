# Design: Auditing (Change History)

**Status:** Proposed — pending revision
**Date:** 2026-02-22

> **Note:** This document should be revised after [Model Options Infrastructure](model_options_infrastructure.md) is implemented. That document defines shared infrastructure (Builder pipeline ordering, `update_columns` bypass contract, `boolean_or_hash_option` helper, `create_log_table` helper, `UserSnapshot`) that this design should reference instead of defining inline. Key sections affected: Builder pipeline order (§7), ModelDefinition accessors (§2), ConfigurationValidator (§12), SchemaManager table creation (§3), and user snapshot logic (§5). See also [Multiselect and Batch Actions](multiselect_and_batch_actions.md) for bulk operation audit implications.

## Problem

The platform has no change tracking or audit trail for records. Users need to answer "who changed what, when, and from what value" — a fundamental requirement for business applications. Common use cases:

- **Compliance** — regulators require full change history for sensitive records
- **Debugging** — investigating how a record got into its current state
- **Accountability** — knowing who made each change
- **Undo context** — understanding what changed before deciding whether to revert

In classical Rails, this is solved by gems like `paper_trail` or `audited`. The platform needs a native, metadata-driven equivalent that integrates with the existing model factory pipeline, permission system, and presenter infrastructure.

## Goals

- Add `auditing` as a model-level option in YAML and DSL
- Automatically track create, update, and destroy operations
- Record the user who made each change via `LcpRuby::Current.user`
- Store field-level diffs (old value, new value) — not full record snapshots
- Handle nested data correctly: custom fields (JSONB diff), JSON fields (deep diff), attachments, and nested_attributes children
- Aggregate nested_attributes child changes into the parent's audit log entry (one user action = one audit record)
- Write audit records inside the same database transaction (`after_save`, not `after_commit`)
- Support the three-source principle (YAML config, DB storage, host API override)
- Integrate with `ConfigurationValidator`, `SchemaManager`, and `Builder` pipeline
- Provide a read-only UI for viewing change history on the show page

## Non-Goals

- Record rollback / undo functionality (view-only history)
- Automatic purge of old audit records — see [Data Retention Policy](data_retention.md)
- Diffing binary attachment content (only metadata is tracked: filename, content_type, byte_size)
- Real-time audit streaming to external systems (host API override covers this)
- Workflow transition audit (the workflow design document defines its own `workflow_audit_logs` table — this feature covers general data change auditing, not state machine transitions)

## Design

### YAML Configuration

```yaml
# config/lcp_ruby/models/deal.yml
name: deal
auditing: true
fields:
  - name: name
    type: string
  - name: stage
    type: enum
    values:
      lead: Lead
      qualified: Qualified
      closed: Closed
  - name: amount
    type: decimal
```

```yaml
# config/lcp_ruby/models/order.yml
name: order
auditing:
  only: [name, stage, amount]       # track only these fields
  ignore: [updated_at, lock_version] # exclude these fields (alternative to only)
  track_associations: true           # aggregate nested_attributes changes (default: true)
  track_attachments: true            # log attachment add/remove (default: true)
  expand_custom_fields: true         # diff custom_data per field (default: true)
  expand_json_fields: [config]       # deep-diff these JSON fields
fields:
  - name: name
    type: string
```

### DSL Configuration

```ruby
define_model :deal do
  auditing true

  field :name, :string
  field :stage, :enum, values: { lead: "Lead", qualified: "Qualified" }
end

define_model :order do
  auditing only: [:name, :stage, :amount],
           track_attachments: false

  field :name, :string
end
```

### What `auditing` Enables

When `auditing` is set on a model, the platform automatically:

1. **SchemaManager** — creates the `lcp_audit_logs` table (once, shared across all audited models)
2. **AuditingApplicator** (new) — installs `after_save` and `after_destroy` callbacks that write audit log entries
3. **AuditLog model** — internal AR model (`LcpRuby::AuditLog`) for reading/writing audit entries
4. **AuditWriter** — service that computes diffs, expands nested data, and writes the audit record
5. **Presenter integration** — show page can display a "History" tab/section with change timeline

No changes to permissions, routes, or controller actions are needed for the basic case. Audit logging is passive — it observes changes but does not affect CRUD behavior.

### Audit Log Table

A single shared table for all audited models (polymorphic):

```
lcp_audit_logs
  id              bigint PK
  auditable_type  string NOT NULL    -- lcp model name ("deal", "order")
  auditable_id    bigint NOT NULL    -- record ID
  action          string NOT NULL    -- "create", "update", "destroy"
  changes_data    jsonb  NOT NULL    -- field-level diffs (see format below)
  user_id         bigint             -- who made the change (Current.user.id)
  user_snapshot   jsonb              -- {email, name, role} snapshot at time of change
  metadata        jsonb              -- extra context (request_id, ip, source)
  created_at      datetime NOT NULL
```

**Indexes:**
- `(auditable_type, auditable_id, created_at)` — primary query pattern
- `(user_id, created_at)` — "what did user X change?"
- `(created_at)` — chronological queries

### Changes Data Format

#### Scalar fields

Standard `[old_value, new_value]` pairs from `saved_changes`:

```json
{
  "name": ["Acme Corp", "Acme Corporation"],
  "stage": ["lead", "qualified"],
  "amount": [null, 50000]
}
```

#### Create action

All tracked field values as `[nil, new_value]`:

```json
{
  "name": [null, "Acme Corp"],
  "stage": [null, "lead"],
  "amount": [null, 50000]
}
```

#### Destroy action

All tracked field values as `[old_value, nil]`:

```json
{
  "name": ["Acme Corp", null],
  "stage": ["lead", null],
  "amount": [50000, null]
}
```

#### Custom fields (JSONB expansion)

When `expand_custom_fields: true` (default), the `custom_data` column change is expanded into individual field diffs with a `cf:` prefix:

```json
{
  "cf:risk_score": [30, 80],
  "cf:priority": [null, "high"]
}
```

Without expansion, the entire column appears as one change:

```json
{
  "custom_data": [{"risk_score": 30}, {"risk_score": 80, "priority": "high"}]
}
```

#### JSON fields (deep diff)

When a JSON field is listed in `expand_json_fields`, hash values are diffed per key with a dot-path prefix:

```json
{
  "config.notify_on_close": [false, true],
  "config.max_retries": [3, 5]
}
```

Array values within JSON fields are stored as whole-value diffs (array element diffing is complex and rarely useful):

```json
{
  "tags": [["vip", "urgent"], ["vip", "urgent", "escalated"]]
}
```

#### Attachments

When `track_attachments: true` (default), attachment changes are tracked with an `attachment:` prefix. The controller provides attachment change information after save:

```json
{
  "attachment:contract": [
    null,
    {"filename": "contract_v2.pdf", "content_type": "application/pdf", "byte_size": 245000}
  ]
}
```

For attachment removal:

```json
{
  "attachment:contract": [
    {"filename": "contract_v1.pdf", "content_type": "application/pdf", "byte_size": 180000},
    null
  ]
}
```

#### Nested attributes (aggregated into parent)

When a model has `has_many` associations with `nested_attributes`, child changes are aggregated into the parent's audit log entry. This matches the user's mental model — one form submission, one history entry.

```json
{
  "name": ["Shopping", "Weekend Shopping"],

  "todo_items:created": [
    {"title": "Buy milk", "completed": false, "position": 3}
  ],
  "todo_items:updated": [
    {"id": 12, "completed": [false, true]}
  ],
  "todo_items:destroyed": [
    {"id": 9, "title": "Call dentist", "completed": false, "position": 2}
  ]
}
```

Key design decisions for nested changes:

| Child action | What is stored | Reason |
|---|---|---|
| **created** | All attributes (snapshot) | Record didn't exist before — no "before" state to reference |
| **updated** | Only changed attributes as `[old, new]` | Record still exists — diff is sufficient |
| **destroyed** | All attributes (snapshot) | Record will cease to exist — no "after" state to reference |

Destroyed children include all tracked attributes because once the record is gone from the database, there is no way to look up what was deleted. Created children similarly need all attributes since there was no prior version.

The FK column pointing to the parent (e.g., `todo_list_id`) is excluded from child snapshots — it's redundant (implied by the parent context).

**Which associations are tracked:** Only `has_many`/`has_one` associations that have `nested_attributes` configured. Standalone child models that happen to have their own `auditing: true` are tracked independently on their own records — there is no double-tracking.

### Transaction Safety

Audit records are written inside `after_save` callbacks, which execute **within the same database transaction** as the data change:

```
BEGIN TRANSACTION
  UPDATE deals SET name = '...', stage = '...' WHERE id = 5
  INSERT INTO todo_items (...) VALUES (...)
  UPDATE todo_items SET completed = true WHERE id = 12
  DELETE FROM todo_items WHERE id = 9

  -- after_save callback fires (still inside transaction)
  INSERT INTO lcp_audit_logs (...) VALUES (...)
COMMIT
```

This guarantees:
- **Atomicity** — audit record exists if and only if the data change exists
- **No orphan audit logs** — if the transaction rolls back, the audit log entry is also rolled back
- **No missing audit logs** — if data is committed, the audit log is committed too

`after_commit` (outside transaction) would be appropriate only for sending audit data to an external system — which is handled by the host API override, not the default writer.

### Three-Source Principle

| Source | What it provides |
|---|---|
| **YAML/DSL** | `auditing: true` on model — static declaration of which models and fields to track |
| **DB** | `lcp_audit_logs` table — runtime storage, queryable through generated presenter |
| **Host API** | `config.audit_writer` — host app provides a custom writer class that replaces the default `AuditWriter` |

```ruby
# Host app override — e.g., write to Elasticsearch instead of DB
LcpRuby.configure do |config|
  config.audit_writer = MyElasticsearchAuditWriter
end

# Contract: must implement .log(action:, record:, changes:, user:, metadata:)
class MyElasticsearchAuditWriter
  def self.log(action:, record:, changes:, user:, metadata:)
    ElasticsearchClient.index(
      index: "audit-#{Date.current.strftime('%Y.%m')}",
      body: {
        model: record.class.lcp_model_name,
        record_id: record.id,
        action: action,
        changes: changes,
        user_id: user&.id,
        timestamp: Time.current
      }
    )
  end
end
```

### Permission Integration

Audit logs are read-only. No special CRUD permissions are needed — the `show` permission on the parent model implicitly grants access to its audit history.

For fine-grained control, a future iteration could add `audit_logs: { readable: true }` to the permissions YAML. For now, if you can view the record, you can view its history.

### Presenter Integration

The show page can display audit history. No special presenter configuration is required — the platform auto-injects a "History" section when the model has `auditing: true`:

```yaml
# Optional: explicitly control the history section
presenter:
  name: deals
  model: deal
  show:
    sections:
      - type: details
        fields: [...]
      - type: audit_history       # auto-injected if omitted and model has auditing
        label: "Change History"
        limit: 50                 # max entries to show (default: 50)
```

The history section renders a timeline view:
- Each entry shows: user name, action (created/updated/deleted), timestamp
- Expandable diff view showing field changes (old → new)
- Nested child changes grouped under the parent entry
- Custom field changes labeled with their display label (not internal field name)

## Implementation

### 1. `LcpRuby::AuditLog` (internal model)

**File:** `app/models/lcp_ruby/audit_log.rb`

```ruby
module LcpRuby
  class AuditLog < ActiveRecord::Base
    self.table_name = "lcp_audit_logs"

    scope :for_record, ->(type, id) {
      where(auditable_type: type, auditable_id: id).order(created_at: :desc)
    }

    scope :by_user, ->(user_id) {
      where(user_id: user_id).order(created_at: :desc)
    }
  end
end
```

### 2. `Metadata::ModelDefinition`

**File:** `lib/lcp_ruby/metadata/model_definition.rb`

Add auditing accessor methods:

```ruby
def auditing?
  !!auditing_config
end

def auditing_options
  case options["auditing"]
  when true then {}
  when Hash then options["auditing"]
  else {}
  end
end

private

def auditing_config
  a = options["auditing"]
  a == true || a.is_a?(Hash) ? a : nil
end
```

### 3. `ModelFactory::SchemaManager`

**File:** `lib/lcp_ruby/model_factory/schema_manager.rb`

Create the shared `lcp_audit_logs` table if any model has `auditing: true`. This is done once during boot, not per-model:

```ruby
def self.ensure_audit_table!
  connection = ActiveRecord::Base.connection
  return if connection.table_exists?("lcp_audit_logs")

  connection.create_table("lcp_audit_logs") do |t|
    t.string  :auditable_type, null: false
    t.bigint  :auditable_id,   null: false
    t.string  :action,         null: false
    t.column  :changes_data, LcpRuby.json_column_type, null: false, default: {}
    t.bigint  :user_id
    t.column  :user_snapshot, LcpRuby.json_column_type
    t.column  :metadata, LcpRuby.json_column_type
    t.datetime :created_at, null: false
  end

  connection.add_index "lcp_audit_logs",
    [:auditable_type, :auditable_id, :created_at],
    name: "idx_audit_logs_on_auditable_and_time"
  connection.add_index "lcp_audit_logs",
    [:user_id, :created_at],
    name: "idx_audit_logs_on_user_and_time"
  connection.add_index "lcp_audit_logs",
    [:created_at],
    name: "idx_audit_logs_on_time"
end
```

Called from `Engine.load_metadata!` after all models are loaded, but only if at least one model has `auditing: true`.

### 4. `ModelFactory::AuditingApplicator` (new)

**File:** `lib/lcp_ruby/model_factory/auditing_applicator.rb`

```ruby
module LcpRuby
  module ModelFactory
    class AuditingApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.auditing?

        install_audit_callbacks!
        install_audit_association!
      end

      private

      def install_audit_callbacks!
        model_def = @model_definition
        opts = model_def.auditing_options

        # Nested associations with nested_attributes (for aggregated tracking)
        nested_assoc_names = model_def.associations
          .select { |a| a.nested_attributes && %w[has_many has_one].include?(a.type) }
          .map { |a| a.name }

        @model_class.after_create do |record|
          AuditWriter.log(
            action: :create,
            record: record,
            options: opts,
            model_definition: model_def,
            nested_associations: nested_assoc_names
          )
        end

        @model_class.after_save do |record|
          # after_save fires on both create and update; skip creates (handled above)
          next if record.previously_new_record?

          AuditWriter.log(
            action: :update,
            record: record,
            options: opts,
            model_definition: model_def,
            nested_associations: nested_assoc_names
          )
        end

        @model_class.after_destroy do |record|
          AuditWriter.log(
            action: :destroy,
            record: record,
            options: opts,
            model_definition: model_def,
            nested_associations: nested_assoc_names
          )
        end
      end

      def install_audit_association!
        @model_class.has_many :audit_logs,
          -> { order(created_at: :desc) },
          as: :auditable,
          class_name: "LcpRuby::AuditLog",
          foreign_key: :auditable_id,
          foreign_type: :auditable_type,
          # Use model name (not class name) for polymorphic type
          # so audit logs are readable without Dynamic:: prefix
          inverse_of: false

        model_name = @model_definition.name

        # Override the default polymorphic type to use lcp model name
        @model_class.before_create do
          # No-op: type is set by AuditWriter, not by the association
        end

        # Provide a convenience method
        @model_class.define_method(:audit_history) do |limit: 50|
          AuditLog.for_record(model_name, id).limit(limit)
        end
      end
    end
  end
end
```

### 5. `AuditWriter` (new)

**File:** `lib/lcp_ruby/auditing/audit_writer.rb`

```ruby
module LcpRuby
  module Auditing
    class AuditWriter
      EXCLUDED_FIELDS = %w[created_at updated_at lock_version].freeze

      def self.log(action:, record:, options:, model_definition:, nested_associations: [])
        # Allow host app to override the writer entirely
        custom_writer = LcpRuby.configuration.audit_writer
        if custom_writer
          changes = compute_all_changes(action, record, options, model_definition, nested_associations)
          return if action == :update && changes.empty?

          return custom_writer.log(
            action: action,
            record: record,
            changes: changes,
            user: Current.user,
            metadata: build_metadata
          )
        end

        changes = compute_all_changes(action, record, options, model_definition, nested_associations)
        return if action == :update && changes.empty?

        AuditLog.create!(
          auditable_type: model_definition.name,
          auditable_id: record.id,
          action: action.to_s,
          changes_data: changes,
          user_id: Current.user&.id,
          user_snapshot: snapshot_user(Current.user),
          metadata: build_metadata,
          created_at: Time.current
        )
      end

      def self.compute_all_changes(action, record, options, model_definition, nested_associations)
        changes = compute_scalar_changes(action, record, options)

        # Expand custom fields
        if model_definition.custom_fields_enabled? && options.fetch("expand_custom_fields", true)
          changes = expand_custom_data(changes)
        end

        # Expand JSON fields
        json_fields = Array(options["expand_json_fields"])
        json_fields.each { |f| changes = expand_json_field(changes, f) }

        # Aggregate nested_attributes child changes
        if options.fetch("track_associations", true)
          nested_associations.each do |assoc_name|
            assoc_def = model_definition.associations.find { |a| a.name == assoc_name }
            next unless assoc_def

            nested = compute_nested_changes(record, assoc_name, assoc_def)
            changes.merge!(nested)
          end
        end

        changes
      end

      # -- Scalar field changes --

      def self.compute_scalar_changes(action, record, options)
        case action
        when :create
          attrs = filter_fields(record.attributes, options)
          attrs.transform_values { |v| [nil, v] }
        when :update
          filter_fields(record.saved_changes, options)
        when :destroy
          attrs = filter_fields(record.attributes, options)
          attrs.transform_values { |v| [v, nil] }
        end
      end

      def self.filter_fields(changes, options)
        only = options["only"]&.map(&:to_s)
        ignore = (options["ignore"]&.map(&:to_s) || []) + EXCLUDED_FIELDS

        changes = changes.except(*ignore)
        changes = changes.slice(*only) if only
        changes.except("id")
      end

      # -- Custom fields JSONB expansion --

      def self.expand_custom_data(changes)
        return changes unless changes.key?("custom_data")

        old_data, new_data = changes.delete("custom_data")
        old_data = parse_json_value(old_data)
        new_data = parse_json_value(new_data)

        all_keys = ((old_data&.keys || []) + (new_data&.keys || [])).uniq
        all_keys.each do |key|
          old_val = old_data&.dig(key)
          new_val = new_data&.dig(key)
          next if old_val == new_val
          changes["cf:#{key}"] = [old_val, new_val]
        end

        changes
      end

      # -- JSON field deep diff --

      def self.expand_json_field(changes, field_name)
        return changes unless changes.key?(field_name)

        old_val = parse_json_value(changes[field_name][0])
        new_val = parse_json_value(changes[field_name][1])

        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          changes.delete(field_name)
          all_keys = (old_val.keys + new_val.keys).uniq
          all_keys.each do |key|
            o = old_val[key]
            n = new_val[key]
            next if o == n
            changes["#{field_name}.#{key}"] = [o, n]
          end
        end
        # Arrays and non-hash values stay as whole-value diffs

        changes
      end

      # -- Nested attributes aggregation --

      def self.compute_nested_changes(record, assoc_name, assoc_def)
        children = record.association(assoc_name).target
        return {} if children.blank?

        fk = assoc_def.foreign_key
        nested = {}

        children.each do |child|
          if child.destroyed?
            # Snapshot all attributes — record will no longer exist
            attrs = child.attributes.except("created_at", "updated_at", fk)
            (nested["#{assoc_name}:destroyed"] ||= []) << attrs
          elsif child.previously_new_record?
            # Snapshot all attributes — record didn't exist before
            attrs = child.attributes.except("created_at", "updated_at", fk)
            (nested["#{assoc_name}:created"] ||= []) << attrs
          else
            child_changes = child.saved_changes.except("updated_at")
            if child_changes.any?
              (nested["#{assoc_name}:updated"] ||= []) << { "id" => child.id }.merge(child_changes)
            end
          end
        end

        nested
      end

      # -- Helpers --

      def self.snapshot_user(user)
        return nil unless user

        snapshot = { "id" => user.id }
        snapshot["email"] = user.email if user.respond_to?(:email)
        snapshot["name"] = user.name if user.respond_to?(:name)
        if user.respond_to?(LcpRuby.configuration.role_method)
          snapshot["role"] = user.send(LcpRuby.configuration.role_method)
        end
        snapshot
      end

      def self.build_metadata
        {}
      end

      def self.parse_json_value(value)
        case value
        when Hash then value
        when String
          JSON.parse(value) rescue value
        else
          value
        end
      end

      private_class_method :compute_scalar_changes, :filter_fields,
                           :expand_custom_data, :expand_json_field,
                           :compute_nested_changes, :snapshot_user,
                           :build_metadata, :parse_json_value
    end
  end
end
```

### 6. `LcpRuby::Current`

**File:** `lib/lcp_ruby/current.rb`

Add `request_id` attribute for audit metadata (optional enhancement):

```ruby
module LcpRuby
  class Current < ActiveSupport::CurrentAttributes
    attribute :user, :request_id
  end
end
```

Set in `ApplicationController`:

```ruby
before_action :set_audit_context

def set_audit_context
  LcpRuby::Current.request_id = request.request_id
end
```

### 7. `ModelFactory::Builder`

**File:** `lib/lcp_ruby/model_factory/builder.rb`

Add `apply_auditing` to the pipeline after `apply_callbacks`:

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
  apply_auditing(model_class)              # <-- new, after callbacks
  apply_defaults(model_class)
  apply_computed(model_class)
  apply_positioning(model_class)
  apply_external_fields(model_class)
  apply_model_extensions(model_class)
  apply_custom_fields(model_class)
  apply_label_method(model_class)
  validate_external_methods!(model_class)
  model_class
end

def apply_auditing(model_class)
  AuditingApplicator.new(model_class, model_definition).apply!
end
```

### 8. `Configuration`

**File:** `lib/lcp_ruby/configuration.rb`

Add `audit_writer` accessor:

```ruby
attr_accessor :audit_writer

def initialize
  # ... existing defaults ...
  @audit_writer = nil  # nil = use built-in AuditWriter
end
```

### 9. Attachment Tracking in Controller

**File:** `app/controllers/lcp_ruby/resources_controller.rb`

Attachments are not visible in `saved_changes` — they need controller-level tracking. After a successful save, the controller appends attachment change data to the latest audit log:

```ruby
def update
  authorize @record

  # Capture attachment state before save
  attachment_state_before = capture_attachment_state(@record) if current_model_definition.auditing?

  @record.assign_attributes(permitted_params)
  purge_removed_attachments!(@record)

  validate_association_values!(@record)

  if @record.errors.none? && @record.save
    # Append attachment changes to audit log
    if current_model_definition.auditing? && current_model_definition.auditing_options.fetch("track_attachments", true)
      append_attachment_audit(@record, attachment_state_before)
    end

    redirect_to resource_path(@record), notice: "..."
  else
    # ...
  end
end

private

def capture_attachment_state(record)
  state = {}
  current_model_definition.fields.select(&:attachment?).each do |field|
    attachment = record.send(field.name)
    if attachment.attached?
      blob = field.attachment_multiple? ? attachment.blobs.map { |b| blob_snapshot(b) } : blob_snapshot(attachment.blob)
      state[field.name] = blob
    end
  end
  state
end

def blob_snapshot(blob)
  { "filename" => blob.filename.to_s, "content_type" => blob.content_type, "byte_size" => blob.byte_size }
end

def append_attachment_audit(record, state_before)
  attachment_changes = {}

  current_model_definition.fields.select(&:attachment?).each do |field|
    name = field.name
    remove_key = "remove_#{name}"

    if params.dig(:record, remove_key) == "1"
      # Attachment was removed
      attachment_changes["attachment:#{name}"] = [state_before[name], nil]
    elsif params.dig(:record, name).present?
      # Attachment was added/replaced
      attachment = record.send(name)
      new_state = if field.attachment_multiple?
        attachment.blobs.map { |b| blob_snapshot(b) }
      else
        blob_snapshot(attachment.blob)
      end
      attachment_changes["attachment:#{name}"] = [state_before[name], new_state]
    end
  end

  return if attachment_changes.empty?

  # Merge into the audit log entry that was just created by after_save
  latest_log = AuditLog.where(
    auditable_type: current_model_definition.name,
    auditable_id: record.id,
    action: "update"
  ).order(created_at: :desc).first

  if latest_log
    latest_log.update_columns(
      changes_data: latest_log.changes_data.merge(attachment_changes)
    )
  end
end
```

### 10. `Dsl::ModelBuilder`

**File:** `lib/lcp_ruby/dsl/model_builder.rb`

Add `auditing` DSL method:

```ruby
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

### 11. JSON Schema

**File:** `lib/lcp_ruby/schemas/model.json`

Add `auditing` to the model options schema:

```json
"auditing": {
  "oneOf": [
    { "type": "boolean", "const": true },
    {
      "type": "object",
      "properties": {
        "only": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Track only these fields"
        },
        "ignore": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Exclude these fields from tracking"
        },
        "track_associations": {
          "type": "boolean",
          "description": "Aggregate nested_attributes child changes (default: true)"
        },
        "track_attachments": {
          "type": "boolean",
          "description": "Track attachment add/remove (default: true)"
        },
        "expand_custom_fields": {
          "type": "boolean",
          "description": "Diff custom_data per field instead of whole column (default: true)"
        },
        "expand_json_fields": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Deep-diff these JSON fields instead of whole-value"
        }
      },
      "additionalProperties": false
    }
  ]
}
```

### 12. `Metadata::ConfigurationValidator`

**File:** `lib/lcp_ruby/metadata/configuration_validator.rb`

Add validation for `auditing` options:

```ruby
def validate_auditing(model)
  a = model.options["auditing"]
  return unless a

  unless a == true || a.is_a?(Hash)
    @errors << "Model '#{model.name}': auditing must be true or a Hash, got #{a.class}"
    return
  end

  return unless a.is_a?(Hash)

  allowed_keys = %w[only ignore track_associations track_attachments expand_custom_fields expand_json_fields]
  unknown = a.keys - allowed_keys
  if unknown.any?
    @errors << "Model '#{model.name}': auditing has unknown keys: #{unknown.join(', ')}. " \
               "Allowed keys: #{allowed_keys.join(', ')}"
  end

  # Mutual exclusivity of only/ignore
  if a["only"] && a["ignore"]
    @errors << "Model '#{model.name}': auditing cannot have both 'only' and 'ignore'"
  end

  # Validate field references
  field_names = model.fields.map(&:name)
  %w[only ignore].each do |key|
    next unless a[key]
    unknown_fields = a[key].map(&:to_s) - field_names
    if unknown_fields.any?
      @warnings << "Model '#{model.name}': auditing.#{key} references unknown fields: #{unknown_fields.join(', ')}"
    end
  end

  # Validate expand_json_fields reference actual JSON fields
  if a["expand_json_fields"]
    json_fields = model.fields.select { |f| f.type == "json" }.map(&:name)
    invalid = a["expand_json_fields"].map(&:to_s) - json_fields
    if invalid.any?
      @warnings << "Model '#{model.name}': auditing.expand_json_fields references non-JSON fields: #{invalid.join(', ')}"
    end
  end

  # Warning if auditing without timestamps
  unless model.timestamps?
    @warnings << "Model '#{model.name}': auditing is enabled but timestamps are disabled. " \
                 "Audit logs will have timestamps but the model itself won't."
  end
end
```

## Interaction with Other Features

### Soft Delete

When a soft-deletable model has `auditing: true`:
- `discard!` uses `update_columns` which **bypasses** `after_save` callbacks
- Audit log for discard/undiscard operations should be written by `SoftDeleteApplicator` directly, dispatching to `AuditWriter.log` with action `:discard` / `:undiscard`
- The `changes_data` contains `{"discarded_at": [null, "2026-02-22T..."]}` or the reverse

### Workflow Transitions

The workflow design document defines its own `workflow_audit_logs` table for transition history. Data auditing (this feature) and workflow auditing are complementary:
- **Data audit** answers "what fields changed on this record?"
- **Workflow audit** answers "what state transitions occurred and who approved them?"

Both can coexist on the same model. The data audit log would show `{"status": ["draft", "submitted"]}` while the workflow audit log would show the transition name, approver, and comment.

### Events

Audit logging does **not** replace the event system. They serve different purposes:

| Events | Audit Log |
|---|---|
| React to changes (send email, update related records) | Passive recording for later review |
| Handler executes custom logic | Pure data write, no side effects |
| Can be async (via ActiveJob) | Always synchronous (same transaction) |
| Configurable per event | Automatic for all tracked fields |

### Custom Fields

When a model has both `custom_fields: true` and `auditing: true`:
- Custom field changes are automatically tracked (the `custom_data` column appears in `saved_changes`)
- With `expand_custom_fields: true` (default), individual field changes are shown instead of the raw JSON blob
- Custom field labels (from `CustomFields::Registry`) can be used in the UI to display human-readable names

## Components Requiring No Changes

| Component | Why it works |
|---|---|
| **PermissionEvaluator** | Audit is read-only, no new CRUD operations needed |
| **PolicyFactory** | No new policy methods needed |
| **ScopeBuilder** | Audit logs are not scoped by user permissions |
| **ActionSet** | No new actions needed |
| **AssociationApplicator** | `has_many :audit_logs` is installed by AuditingApplicator directly |
| **ValidationApplicator** | No validations on audit log fields |
| **TransformApplicator** | No transforms on audit data |
| **IncludesResolver** | Audit logs are loaded on-demand (show page), not eager-loaded |

## File Changes Summary

| File | Change |
|------|--------|
| `app/models/lcp_ruby/audit_log.rb` | **New** — AR model for audit log table |
| `lib/lcp_ruby/auditing/audit_writer.rb` | **New** — computes diffs, expands nested data, writes audit records |
| `lib/lcp_ruby/model_factory/auditing_applicator.rb` | **New** — installs after_save/after_destroy callbacks |
| `lib/lcp_ruby/metadata/model_definition.rb` | Add `auditing?`, `auditing_options` methods |
| `lib/lcp_ruby/model_factory/builder.rb` | Add `apply_auditing` to pipeline |
| `lib/lcp_ruby/model_factory/schema_manager.rb` | Add `ensure_audit_table!` class method |
| `lib/lcp_ruby/configuration.rb` | Add `audit_writer` accessor |
| `lib/lcp_ruby/current.rb` | Add `request_id` attribute |
| `app/controllers/lcp_ruby/application_controller.rb` | Set `Current.request_id` |
| `app/controllers/lcp_ruby/resources_controller.rb` | Attachment state capture + audit append |
| `lib/lcp_ruby/dsl/model_builder.rb` | Add `auditing` DSL method |
| `lib/lcp_ruby/schemas/model.json` | Add `auditing` to model options schema |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Validate `auditing` options and field references |

## Examples

### Basic Auditing

```yaml
# models/deal.yml
name: deal
fields:
  - name: name
    type: string
  - name: stage
    type: enum
    values: { lead: Lead, qualified: Qualified, closed: Closed }
  - name: amount
    type: decimal
options:
  timestamps: true
  auditing: true
```

After updating the deal:

```json
{
  "auditable_type": "deal",
  "auditable_id": 42,
  "action": "update",
  "changes_data": {
    "name": ["Acme Corp", "Acme Corporation"],
    "stage": ["lead", "qualified"],
    "amount": [null, 50000.0]
  },
  "user_id": 7,
  "user_snapshot": {"id": 7, "email": "john@example.com", "name": "John", "role": "sales_rep"},
  "created_at": "2026-02-22T14:32:05Z"
}
```

### Selective Field Tracking

```yaml
# models/order.yml
name: order
fields:
  - name: number
    type: string
  - name: status
    type: enum
    values: { draft: Draft, submitted: Submitted, approved: Approved }
  - name: internal_notes
    type: text
  - name: total
    type: decimal
options:
  auditing:
    only: [number, status, total]   # don't track internal_notes
```

### With Custom Fields and Nested Children

```yaml
# models/todo_list.yml
name: todo_list
fields:
  - name: name
    type: string
associations:
  - type: has_many
    name: todo_items
    target_model: todo_item
    foreign_key: todo_list_id
    dependent: destroy
    inverse_of: todo_list
    order: { position: asc }
    nested_attributes:
      allow_destroy: true
options:
  timestamps: true
  auditing: true
  custom_fields: true
```

After updating the list (rename + add item + complete item + delete item):

```json
{
  "auditable_type": "todo_list",
  "auditable_id": 5,
  "action": "update",
  "changes_data": {
    "name": ["Shopping", "Weekend Shopping"],
    "cf:priority": [null, "high"],
    "todo_items:created": [
      {"id": 18, "title": "Buy milk", "completed": false, "position": 3}
    ],
    "todo_items:updated": [
      {"id": 12, "completed": [false, true]}
    ],
    "todo_items:destroyed": [
      {"id": 9, "title": "Call dentist", "completed": false, "position": 2}
    ]
  },
  "user_id": 3,
  "user_snapshot": {"id": 3, "email": "alice@example.com", "name": "Alice"},
  "created_at": "2026-02-22T15:10:00Z"
}
```

### DSL with Host API Override

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.audit_writer = AuditToElasticsearch
end

# app/services/audit_to_elasticsearch.rb
class AuditToElasticsearch
  def self.log(action:, record:, changes:, user:, metadata:)
    # Write to both DB and Elasticsearch
    LcpRuby::AuditLog.create!(
      auditable_type: record.class.table_name.singularize,
      auditable_id: record.id,
      action: action.to_s,
      changes_data: changes,
      user_id: user&.id,
      user_snapshot: snapshot(user),
      metadata: metadata,
      created_at: Time.current
    )

    ElasticsearchClient.index(
      index: "audit-#{Date.current.strftime('%Y.%m')}",
      body: { model: record.class.table_name, record_id: record.id, action: action, changes: changes }
    )
  end
end
```

## Test Plan

### Unit Tests

1. **ModelDefinition** — `auditing?` returns true for `true` and Hash; `auditing_options` returns empty hash for `true`, parsed hash for Hash; returns false for absent/false
2. **AuditWriter — scalar changes** — create logs all fields as `[nil, val]`; update logs only changed fields as `[old, new]`; destroy logs all fields as `[val, nil]`; empty update (no changes) does not create a log
3. **AuditWriter — field filtering** — `only` option limits tracked fields; `ignore` option excludes fields; `EXCLUDED_FIELDS` (updated_at, created_at, lock_version) always excluded; `id` always excluded
4. **AuditWriter — custom field expansion** — `expand_custom_fields: true` expands `custom_data` into `cf:field_name` keys; `expand_custom_fields: false` keeps raw `custom_data` change; handles nil old/new values
5. **AuditWriter — JSON field expansion** — hash values are diffed per key with dot-path; array values stay as whole-value diff; non-hash values stay as whole-value diff
6. **AuditWriter — nested attributes** — created children include all attributes; updated children include only changed attributes with `[old, new]`; destroyed children include all attributes (snapshot); parent FK excluded from child snapshots; unchanged children are not included
7. **AuditWriter — user snapshot** — captures id, email, name, role; handles nil user gracefully; handles user without email/name methods
8. **AuditingApplicator** — installs after_create, after_save, after_destroy callbacks; after_save skips for newly created records (no double-logging); installs `has_many :audit_logs` association; installs `audit_history` convenience method
9. **SchemaManager** — `ensure_audit_table!` creates table with correct columns and indexes; no-ops if table already exists
10. **ConfigurationValidator — auditing** — accepts `true`; accepts valid Hash; rejects non-boolean/non-hash; rejects unknown keys; errors on `only` + `ignore` together; warns on unknown field references; warns on non-JSON expand_json_fields; warns on missing timestamps
11. **DSL ModelBuilder** — `auditing true` sets options correctly; `auditing only: [...]` sets hash options; generates correct `to_hash`

### Integration Tests

12. **Create audited record** — `POST /deals` creates record + audit log entry with action "create" and all field values
13. **Update audited record** — `PATCH /deals/:id` creates audit log entry with action "update" and only changed fields
14. **Destroy audited record** — `DELETE /deals/:id` creates audit log entry with action "destroy" and all field values as snapshot
15. **No-op update** — `PATCH /deals/:id` with no actual changes does not create an audit log entry
16. **Nested attributes audit** — update parent with child create/update/destroy creates single audit log entry with aggregated child changes
17. **Custom fields audit** — changing custom field values creates audit log with expanded `cf:` prefixed fields
18. **User tracking** — audit log records correct user_id and user_snapshot from `Current.user`
19. **Non-audited model** — CRUD operations on models without `auditing: true` create no audit log entries
20. **Transaction safety** — audit log entry is rolled back if the parent save fails (validation error after partial save)

### Fixture Requirements

- Add `auditing: true` to at least one model in integration fixtures
- Add `auditing: { only: [...] }` to another model for selective tracking tests
- Ensure one audited model has `nested_attributes` associations for aggregation tests
- Ensure one audited model has `custom_fields: true` for JSONB expansion tests

## Open Questions

1. **Should audit logs be paginatable in the UI?** For records with hundreds of changes, loading all history at once is impractical. Recommendation: yes, use Kaminari pagination with a default of 20 entries per page, with "Load more" button.

2. **Should the history section show nested child changes inline?** Collapsed by default with an expand toggle, showing "2 items created, 1 updated, 1 deleted" as summary. Recommendation: yes, with expandable detail view.

3. **Should audit log entries be deletable?** For compliance reasons, audit logs should generally be immutable. Recommendation: no delete capability in the initial implementation. A future `retention_policy` option could support automatic cleanup of old entries.

4. **How to handle bulk operations?** If a future bulk update feature changes 100 records at once, should each get its own audit entry? Recommendation: yes, one entry per record — this matches the per-record callback model and keeps the audit trail unambiguous.

5. **Should `auditing` be a top-level key (like `positioning`) or nested under `options`?** Currently proposed under `options` for consistency with `custom_fields` and `timestamps`. However, `positioning` is top-level. Recommendation: keep under `options` — auditing is a behavioral option, not a structural declaration like positioning.
