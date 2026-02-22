# Design: Data Retention Policy

**Status:** Proposed
**Date:** 2026-02-22

## Problem

The platform generates several categories of data that grow indefinitely. Without retention policies, tables accumulate records without bound, degrading query performance, inflating storage costs, and creating compliance risk.

### Data categories that accumulate

| Category | Source | Growth rate | Current cleanup |
|----------|--------|-------------|-----------------|
| **Audit logs** | `lcp_audit_logs` table (auditing feature) | Every create/update/destroy on audited models | None — grows forever |
| **Soft-deleted records** | Main model tables (soft delete feature) | Every discard operation | None — discarded records stay in table forever |
| **Orphaned attachments** | Active Storage blobs | Attachment replacement, record deletion without purge | None — blobs remain after parent deletion |
| **Workflow audit logs** | `lcp_workflow_audit_logs` (future workflow feature) | Every state transition | None (future) |
| **Session / temporary data** | Host application concern | Per user session | Host-managed |

Without retention policies, a system with 100 audited models, 50 changes/day each, accumulates ~1.8M audit log rows per year. Soft-deleted records in large tables (e.g., 10K deals discarded/year) pollute indexes and slow queries even with the `kept` scope, because the database still scans `discarded_at IS NULL` on every query.

### Compliance dimension

Data retention is not just about cleanup — it is also about **mandatory retention**:

- **Audit compliance** — some regulations require audit logs to be kept for a minimum period (e.g., 7 years for financial records)
- **GDPR / right to be forgotten** — personal data must be deletable on request, but this conflicts with audit trail requirements
- **Industry-specific** — healthcare (HIPAA), finance (SOX), government (NARA) have different retention mandates

The platform should support both **minimum retention** (data must be kept at least N days) and **maximum retention** (data must be purged after N days).

## Use Cases

### 1. Purge old audit logs

A company tracks changes to all models but only needs the last 2 years of history. Older audit log entries should be automatically deleted to keep the table manageable.

```yaml
retention:
  audit_logs:
    max_age: 730d
    action: purge
```

### 2. Hard-delete old soft-deleted records

Discarded deals are kept for 90 days for recovery, then permanently removed. This prevents the `deals` table from growing with invisible records.

```yaml
# models/deal.yml
soft_delete: true
retention:
  discarded: { max_age: 90d }
```

### 3. Anonymize instead of delete

A CRM must keep record structure for reporting but must remove personally identifiable information (PII) after account closure. Instead of deleting the contact record, the platform clears specific fields.

```yaml
# models/contact.yml
retention:
  records:
    max_age: 365d
    action: anonymize
    scope: closed
    fields: [name, email, phone, address]
```

### 4. Model-specific audit retention

Financial records (invoices) need 7-year audit retention for SOX compliance, while general entities (tasks) only need 1 year.

```yaml
# models/invoice.yml
auditing: true
retention:
  audit_logs: { min_age: 2555d }   # ~7 years minimum

# models/task.yml
auditing: true
retention:
  audit_logs: { max_age: 365d }
```

### 5. Orphaned attachment cleanup

When a record is hard-deleted (or a soft-deleted record is purged), its Active Storage blobs may remain. A retention job should detect and remove blobs with no remaining attachment references.

```yaml
retention:
  orphaned_attachments:
    max_age: 30d
    action: purge
```

### 6. Bulk discard cleanup with cascade

When a parent record is purged after retention expiry, its cascade-discarded children should also be permanently removed — not left as orphaned soft-deleted records with dangling `discarded_by` references.

### 7. Dry-run / reporting

Before enabling automatic purge, administrators need to preview what would be affected: how many records, which models, what date range. A dry-run mode shows counts without deleting anything.

```bash
bundle exec rake lcp_ruby:retention:preview
```

## Goals

- Define retention policies per data category in a global YAML config file
- Support per-model overrides for audit logs and soft-deleted records
- Support three retention actions: `purge` (hard delete), `anonymize` (clear fields), `archive` (future — move to archive table)
- Support `max_age` (auto-delete after N days) and `min_age` (prevent deletion before N days)
- Provide a rake task for execution (`lcp_ruby:retention:apply`) and preview (`lcp_ruby:retention:preview`)
- Provide an optional ActiveJob adapter for scheduled execution
- Process records in batches to avoid memory issues and long-running transactions
- Log every retention action (what was deleted/anonymized, how many records, timestamp)
- Support the three-source principle (YAML config, DB storage, host API override)
- Integrate with `ConfigurationValidator` for boot-time validation
- Respect `min_age` constraints — never purge data that must be retained

## Non-Goals

- Real-time deletion (retention runs as a batch job, not inline with CRUD operations)
- Archive to external storage (S3, cold storage) — future extension
- Per-record retention overrides (e.g., "keep this specific record forever") — future extension via `retention_exempt` flag
- GDPR subject access requests (SAR) — related but separate feature
- Automatic scheduling (cron configuration is the host app's responsibility)

## Design

### Global Retention Configuration

A single YAML file defines default retention policies for all data categories:

```yaml
# config/lcp_ruby/retention.yml
retention:
  audit_logs:
    max_age: 730d          # purge audit log entries older than 2 years
    action: purge          # purge (default) | anonymize
    batch_size: 1000       # records per batch (default: 1000)

  discarded:
    max_age: 90d           # purge soft-deleted records older than 90 days
    action: purge
    batch_size: 500

  orphaned_attachments:
    max_age: 30d           # purge unattached blobs older than 30 days
    action: purge
    batch_size: 100

  workflow_audit_logs:     # future — when workflow feature exists
    max_age: 1095d         # 3 years
    action: purge
```

### Duration Format

Durations use a simple suffix format: `30d` (days), `12m` (months), `2y` (years). Internally parsed to days.

| Input | Days |
|-------|------|
| `30d` | 30 |
| `6m` | 180 |
| `1y` | 365 |
| `730d` | 730 |

No hours/minutes — retention operates at day granularity.

### Per-Model Overrides

Models can override global defaults for their own data:

```yaml
# models/invoice.yml
name: invoice
auditing: true
soft_delete: true
retention:
  audit_logs:
    min_age: 2555d         # override: keep at least 7 years (compliance)
  discarded:
    max_age: 365d          # override: keep discarded invoices 1 year (vs global 90d)
```

```yaml
# models/task.yml
name: task
auditing: true
soft_delete: true
retention:
  audit_logs:
    max_age: 90d           # override: tasks only need 3 months of audit history
  discarded:
    max_age: 7d            # override: purge discarded tasks after 1 week
```

### Resolution Order

Per-model settings override global defaults. When both `min_age` and `max_age` are present, `min_age` takes precedence (data is never purged before the minimum retention period).

```
Effective policy = model retention || global retention || no retention (skip)
```

If a model has `retention: { audit_logs: { min_age: 2555d } }` and the global config has `audit_logs: { max_age: 730d }`, the effective policy for that model's audit logs is: purge after max(730, 2555) = 2555 days. The `min_age` raises the floor.

### DSL Configuration

```ruby
# Global retention (in initializer)
LcpRuby.configure do |config|
  config.retention = {
    audit_logs: { max_age: "730d", action: "purge" },
    discarded: { max_age: "90d" },
    orphaned_attachments: { max_age: "30d" }
  }
end

# Per-model retention
define_model :invoice do
  auditing true
  soft_delete true

  retention audit_logs: { min_age: "2555d" },
            discarded: { max_age: "365d" }

  field :number, :string
  field :total, :decimal
end
```

### Retention Actions

| Action | Behavior | Use case |
|--------|----------|----------|
| `purge` | Hard delete records from database. For soft-deleted records, calls `destroy!` (bypassing soft delete). For audit logs, deletes rows. For attachments, purges blob + file. | Default. Storage reclamation, general cleanup. |
| `anonymize` | Clears specified fields to `nil` or a placeholder value, keeps the record structure. Sets a `anonymized_at` timestamp. | GDPR compliance, historical reporting where structure matters but PII must be removed. |
| `archive` | (Future) Move records to a separate archive table with the same schema. Keeps data queryable but out of the hot table. | Large-scale systems where data must be retained but not in the active table. |

### Anonymize Action Detail

When `action: anonymize` is specified, the `fields` key lists which fields to clear:

```yaml
retention:
  records:
    max_age: 365d
    action: anonymize
    scope: closed                    # only anonymize records matching this scope
    fields: [name, email, phone]     # clear these fields
    placeholder: "[removed]"         # replacement value (default: nil)
```

The anonymize action:
1. Sets each listed field to `placeholder` (or `nil`)
2. Sets `anonymized_at` column to `Time.current` (column auto-created if anonymize is configured)
3. Writes an audit log entry with action `anonymize` if auditing is enabled
4. Does NOT delete the record — it remains queryable with cleared fields

### What Gets Purged

#### Audit logs (`audit_logs` category)

```sql
DELETE FROM lcp_audit_logs
WHERE auditable_type = 'deal'
  AND created_at < '2024-02-22'   -- now - max_age
LIMIT 1000                         -- batch_size
```

For models with `min_age`, the cutoff date is `now - max(max_age, min_age)`.

#### Soft-deleted records (`discarded` category)

```sql
-- For each soft-deletable model:
DELETE FROM lcp_deals
WHERE discarded_at IS NOT NULL
  AND discarded_at < '2025-11-24'  -- now - max_age
LIMIT 500
```

Before purging a soft-deleted record:
1. Check for `dependent: :discard` children — purge cascade-discarded children first (bottom-up)
2. Purge Active Storage attachments via `record.attachments.each(&:purge)`
3. Hard-delete the record with `record.destroy!` (bypassing soft delete)

#### Orphaned attachments (`orphaned_attachments` category)

```sql
-- Find blobs with no attachment references
DELETE FROM active_storage_blobs
WHERE id NOT IN (SELECT blob_id FROM active_storage_attachments)
  AND created_at < '2026-01-23'   -- now - max_age
```

### Three-Source Principle

| Source | What it provides |
|--------|-----------------|
| **YAML/DSL** | `retention.yml` global config + per-model `retention:` key — static policy declaration |
| **DB** | Execution state: last run timestamp, run history, error log (stored in `lcp_retention_runs` table) |
| **Host API** | `config.retention_executor` — host app provides a custom executor class that replaces or wraps the default |

```ruby
# Host app override — e.g., archive to S3 instead of deleting
LcpRuby.configure do |config|
  config.retention_executor = MyCustomRetentionExecutor
end

# Contract: must implement .execute(policy:, model_definition:, dry_run:)
class MyCustomRetentionExecutor
  def self.execute(policy:, model_definition:, dry_run:)
    # Custom logic — e.g., archive to S3, then delete
  end
end
```

## Implementation

### 1. `Metadata::RetentionDefinition` (new)

**File:** `lib/lcp_ruby/retention/retention_definition.rb`

```ruby
module LcpRuby
  module Retention
    class RetentionDefinition
      VALID_CATEGORIES = %w[audit_logs discarded orphaned_attachments workflow_audit_logs records].freeze
      VALID_ACTIONS = %w[purge anonymize].freeze
      DURATION_PATTERN = /\A(\d+)(d|m|y)\z/

      attr_reader :category, :max_age_days, :min_age_days, :action, :batch_size,
                  :scope, :fields, :placeholder

      def initialize(category:, config:)
        @category = category
        @max_age_days = parse_duration(config["max_age"])
        @min_age_days = parse_duration(config["min_age"])
        @action = config["action"] || "purge"
        @batch_size = config["batch_size"] || 1000
        @scope = config["scope"]
        @fields = config["fields"]
        @placeholder = config["placeholder"]
      end

      def effective_max_age_days
        return nil unless @max_age_days

        if @min_age_days && @min_age_days > @max_age_days
          @min_age_days
        else
          @max_age_days
        end
      end

      def cutoff_time
        days = effective_max_age_days
        return nil unless days

        Time.current - days.days
      end

      def anonymize?
        @action == "anonymize"
      end

      def purge?
        @action == "purge"
      end

      private

      def parse_duration(value)
        return nil unless value

        match = value.to_s.match(DURATION_PATTERN)
        raise ArgumentError, "Invalid duration format: #{value}. Use Nd, Nm, or Ny." unless match

        number = match[1].to_i
        unit = match[2]

        case unit
        when "d" then number
        when "m" then number * 30
        when "y" then number * 365
        end
      end
    end
  end
end
```

### 2. `Retention::PolicyResolver` (new)

**File:** `lib/lcp_ruby/retention/policy_resolver.rb`

Merges global config with per-model overrides:

```ruby
module LcpRuby
  module Retention
    class PolicyResolver
      def initialize(global_config, loader)
        @global_config = global_config || {}
        @loader = loader
      end

      # Returns effective RetentionDefinition for a category + model combination
      def resolve(category, model_definition = nil)
        global = @global_config[category]
        model_override = model_definition&.options&.dig("retention", category)

        return nil unless global || model_override

        merged = (global || {}).merge(model_override || {})

        # min_age from model can raise the floor of global max_age
        if model_override&.key?("min_age") && !model_override.key?("max_age") && global&.key?("max_age")
          merged["max_age"] = global["max_age"]
          merged["min_age"] = model_override["min_age"]
        end

        RetentionDefinition.new(category: category, config: merged)
      end

      # Returns all models that have retention policies for a given category
      def models_with_policy(category)
        @loader.model_definitions.select do |model_def|
          resolve(category, model_def)&.effective_max_age_days
        end
      end
    end
  end
end
```

### 3. `Retention::Executor` (new)

**File:** `lib/lcp_ruby/retention/executor.rb`

```ruby
module LcpRuby
  module Retention
    class Executor
      attr_reader :results

      def initialize(loader, dry_run: false)
        @loader = loader
        @dry_run = dry_run
        @results = []
        @resolver = PolicyResolver.new(
          LcpRuby.configuration.retention,
          loader
        )
      end

      def execute_all!
        purge_audit_logs!
        purge_discarded_records!
        purge_orphaned_attachments!
        log_run!
        @results
      end

      private

      # --- Audit logs ---

      def purge_audit_logs!
        @loader.model_definitions.select(&:auditing?).each do |model_def|
          policy = @resolver.resolve("audit_logs", model_def)
          next unless policy&.effective_max_age_days

          cutoff = policy.cutoff_time
          scope = AuditLog.where(auditable_type: model_def.name)
                          .where("created_at < ?", cutoff)

          count = scope.count

          unless @dry_run
            scope.in_batches(of: policy.batch_size).delete_all
          end

          @results << {
            category: "audit_logs",
            model: model_def.name,
            action: "purge",
            count: count,
            cutoff: cutoff,
            dry_run: @dry_run
          }
        end
      end

      # --- Soft-deleted records ---

      def purge_discarded_records!
        @loader.model_definitions.select(&:soft_delete?).each do |model_def|
          policy = @resolver.resolve("discarded", model_def)
          next unless policy&.effective_max_age_days

          cutoff = policy.cutoff_time
          col = model_def.soft_delete_column
          model_class = LcpRuby.registry.model_for(model_def.name)

          scope = model_class.discarded.where("#{col} < ?", cutoff)

          count = scope.count

          unless @dry_run
            # Purge in batches — destroy! to trigger attachment cleanup and callbacks
            scope.find_each(batch_size: policy.batch_size) do |record|
              record.destroy!
            end
          end

          @results << {
            category: "discarded",
            model: model_def.name,
            action: "purge",
            count: count,
            cutoff: cutoff,
            dry_run: @dry_run
          }
        end
      end

      # --- Orphaned attachments ---

      def purge_orphaned_attachments!
        policy = @resolver.resolve("orphaned_attachments")
        return unless policy&.effective_max_age_days

        cutoff = policy.cutoff_time

        orphaned = ActiveStorage::Blob.left_joins(:attachments)
                                      .where(active_storage_attachments: { id: nil })
                                      .where("active_storage_blobs.created_at < ?", cutoff)

        count = orphaned.count

        unless @dry_run
          orphaned.find_each(batch_size: policy.batch_size) do |blob|
            blob.purge
          end
        end

        @results << {
          category: "orphaned_attachments",
          model: nil,
          action: "purge",
          count: count,
          cutoff: cutoff,
          dry_run: @dry_run
        }
      end

      # --- Anonymize ---

      def anonymize_records!(model_def, policy)
        model_class = LcpRuby.registry.model_for(model_def.name)
        cutoff = policy.cutoff_time
        fields = policy.fields&.map(&:to_s)

        return unless fields&.any?

        scope = model_class.all
        scope = scope.send(policy.scope) if policy.scope
        scope = scope.where("updated_at < ?", cutoff)
        scope = scope.where(anonymized_at: nil) # skip already anonymized

        count = scope.count

        unless @dry_run
          scope.find_each(batch_size: policy.batch_size) do |record|
            attrs = {}
            fields.each { |f| attrs[f] = policy.placeholder }
            attrs[:anonymized_at] = Time.current
            record.update_columns(attrs)
          end
        end

        @results << {
          category: "records",
          model: model_def.name,
          action: "anonymize",
          count: count,
          cutoff: cutoff,
          dry_run: @dry_run
        }
      end

      # --- Run log ---

      def log_run!
        return if @dry_run

        RetentionRun.create!(
          executed_at: Time.current,
          results: @results,
          dry_run: false
        )
      end
    end
  end
end
```

### 4. `Retention::RetentionRun` (internal model)

**File:** `app/models/lcp_ruby/retention_run.rb`

```ruby
module LcpRuby
  class RetentionRun < ActiveRecord::Base
    self.table_name = "lcp_retention_runs"
  end
end
```

Table schema:

```
lcp_retention_runs
  id              bigint PK
  executed_at     datetime NOT NULL
  results         jsonb NOT NULL       -- array of per-category results
  dry_run         boolean NOT NULL DEFAULT false
  created_at      datetime NOT NULL
```

### 5. `SchemaManager` additions

**File:** `lib/lcp_ruby/model_factory/schema_manager.rb`

Create the `lcp_retention_runs` table (once, similar to `ensure_audit_table!`):

```ruby
def self.ensure_retention_table!
  connection = ActiveRecord::Base.connection
  return if connection.table_exists?("lcp_retention_runs")

  connection.create_table("lcp_retention_runs") do |t|
    t.datetime :executed_at, null: false
    t.column :results, LcpRuby.json_column_type, null: false, default: []
    t.boolean :dry_run, null: false, default: false
    t.datetime :created_at, null: false
  end

  connection.add_index "lcp_retention_runs", [:executed_at],
    name: "idx_retention_runs_on_executed_at"
end
```

For models with `anonymize` action, add `anonymized_at` column:

```ruby
# In create_table! — after soft_delete columns:
if model_definition.retention_anonymize?
  t.datetime :anonymized_at, null: true
  t.index :anonymized_at
end

# In update_table! — equivalent add_column logic
```

### 6. `Metadata::ModelDefinition`

**File:** `lib/lcp_ruby/metadata/model_definition.rb`

```ruby
def retention_config
  options["retention"]
end

def retention_anonymize?
  rc = retention_config
  return false unless rc

  rc.values.any? { |v| v.is_a?(Hash) && v["action"] == "anonymize" }
end
```

### 7. `Configuration`

**File:** `lib/lcp_ruby/configuration.rb`

```ruby
attr_accessor :retention, :retention_executor

def initialize
  # ... existing defaults ...
  @retention = nil            # nil = no global retention policy
  @retention_executor = nil   # nil = use built-in Executor
end
```

### 8. Rake Tasks

**File:** `lib/tasks/lcp_ruby_retention.rake`

```ruby
namespace :lcp_ruby do
  namespace :retention do
    desc "Preview retention policy effects (dry run)"
    task preview: :environment do
      loader = LcpRuby.loader
      executor = LcpRuby::Retention::Executor.new(loader, dry_run: true)
      results = executor.execute_all!

      puts "=== Data Retention Preview (Dry Run) ==="
      puts ""

      results.each do |r|
        model_label = r[:model] ? " (#{r[:model]})" : ""
        puts "  #{r[:category]}#{model_label}: #{r[:count]} records would be #{r[:action]}d"
        puts "    Cutoff: #{r[:cutoff]&.strftime('%Y-%m-%d %H:%M:%S')}"
      end

      total = results.sum { |r| r[:count] }
      puts ""
      puts "  Total: #{total} records would be affected"
    end

    desc "Apply retention policies (delete/anonymize expired data)"
    task apply: :environment do
      loader = LcpRuby.loader
      custom_executor = LcpRuby.configuration.retention_executor

      if custom_executor
        results = custom_executor.execute(loader: loader, dry_run: false)
      else
        executor = LcpRuby::Retention::Executor.new(loader, dry_run: false)
        results = executor.execute_all!
      end

      puts "=== Data Retention Applied ==="
      puts ""

      results.each do |r|
        model_label = r[:model] ? " (#{r[:model]})" : ""
        puts "  #{r[:category]}#{model_label}: #{r[:count]} records #{r[:action]}d"
      end

      total = results.sum { |r| r[:count] }
      puts ""
      puts "  Total: #{total} records affected"
    end
  end
end
```

### 9. ActiveJob Adapter (optional)

**File:** `app/jobs/lcp_ruby/retention_job.rb`

```ruby
module LcpRuby
  class RetentionJob < ApplicationJob
    queue_as :maintenance

    def perform
      loader = LcpRuby.loader
      executor = Retention::Executor.new(loader, dry_run: false)
      executor.execute_all!
    end
  end
end
```

Host apps can schedule this via `solid_queue`, `sidekiq-cron`, `whenever`, or any other scheduler:

```ruby
# config/recurring.yml (Solid Queue)
retention_cleanup:
  class: LcpRuby::RetentionJob
  schedule: every day at 3am
```

### 10. `Dsl::ModelBuilder`

**File:** `lib/lcp_ruby/dsl/model_builder.rb`

```ruby
def retention(**categories)
  @options["retention"] ||= {}
  categories.each do |category, config|
    @options["retention"][category.to_s] = config.transform_keys(&:to_s)
  end
end
```

### 11. `Metadata::ConfigurationValidator`

**File:** `lib/lcp_ruby/metadata/configuration_validator.rb`

```ruby
def validate_retention(model)
  rc = model.options["retention"]
  return unless rc

  unless rc.is_a?(Hash)
    @errors << "Model '#{model.name}': retention must be a Hash, got #{rc.class}"
    return
  end

  valid_categories = %w[audit_logs discarded records]

  rc.each do |category, config|
    unless valid_categories.include?(category)
      @errors << "Model '#{model.name}': retention has unknown category '#{category}'. " \
                 "Allowed: #{valid_categories.join(', ')}"
      next
    end

    validate_retention_category(model, category, config)
  end

  # Warn if discarded retention is set but model has no soft_delete
  if rc["discarded"] && !model.soft_delete?
    @warnings << "Model '#{model.name}': retention.discarded has no effect because " \
                 "model does not have soft_delete enabled"
  end

  # Warn if audit_logs retention is set but model has no auditing
  if rc["audit_logs"] && !model.auditing?
    @warnings << "Model '#{model.name}': retention.audit_logs has no effect because " \
                 "model does not have auditing enabled"
  end

  # Validate anonymize fields exist
  if rc.dig("records", "action") == "anonymize"
    fields = rc.dig("records", "fields")
    if fields.nil? || fields.empty?
      @errors << "Model '#{model.name}': retention.records with action 'anonymize' " \
                 "requires a 'fields' list"
    else
      field_names = model.fields.map(&:name)
      unknown = fields.map(&:to_s) - field_names
      if unknown.any?
        @errors << "Model '#{model.name}': retention.records.fields references " \
                   "unknown fields: #{unknown.join(', ')}"
      end
    end
  end
end

def validate_retention_category(model, category, config)
  unless config.is_a?(Hash)
    @errors << "Model '#{model.name}': retention.#{category} must be a Hash"
    return
  end

  allowed_keys = %w[max_age min_age action batch_size scope fields placeholder]
  unknown = config.keys - allowed_keys
  if unknown.any?
    @errors << "Model '#{model.name}': retention.#{category} has unknown keys: " \
               "#{unknown.join(', ')}"
  end

  # Validate duration formats
  %w[max_age min_age].each do |key|
    next unless config[key]
    unless config[key].to_s.match?(/\A\d+(d|m|y)\z/)
      @errors << "Model '#{model.name}': retention.#{category}.#{key} " \
                 "must be a duration (e.g., '90d', '6m', '2y'), got '#{config[key]}'"
    end
  end

  # Must have at least max_age or min_age
  unless config["max_age"] || config["min_age"]
    @errors << "Model '#{model.name}': retention.#{category} must have " \
               "at least 'max_age' or 'min_age'"
  end

  # Validate action
  if config["action"] && !%w[purge anonymize].include?(config["action"])
    @errors << "Model '#{model.name}': retention.#{category}.action " \
               "must be 'purge' or 'anonymize', got '#{config["action"]}'"
  end

  # Validate batch_size
  if config["batch_size"] && (!config["batch_size"].is_a?(Integer) || config["batch_size"] < 1)
    @errors << "Model '#{model.name}': retention.#{category}.batch_size " \
               "must be a positive integer"
  end
end
```

### 12. JSON Schema

**File:** `lib/lcp_ruby/schemas/model.json`

Add `retention` to the model options schema:

```json
"retention": {
  "type": "object",
  "properties": {
    "audit_logs": { "$ref": "#/definitions/retention_policy" },
    "discarded": { "$ref": "#/definitions/retention_policy" },
    "records": { "$ref": "#/definitions/retention_policy_with_anonymize" }
  },
  "additionalProperties": false
}
```

With shared definitions:

```json
"definitions": {
  "retention_policy": {
    "type": "object",
    "properties": {
      "max_age": {
        "type": "string",
        "pattern": "^\\d+(d|m|y)$",
        "description": "Maximum age before purge (e.g., '90d', '6m', '2y')"
      },
      "min_age": {
        "type": "string",
        "pattern": "^\\d+(d|m|y)$",
        "description": "Minimum retention period — data cannot be purged before this age"
      },
      "action": {
        "type": "string",
        "enum": ["purge"],
        "default": "purge"
      },
      "batch_size": {
        "type": "integer",
        "minimum": 1,
        "default": 1000
      }
    },
    "additionalProperties": false
  },
  "retention_policy_with_anonymize": {
    "type": "object",
    "properties": {
      "max_age": {
        "type": "string",
        "pattern": "^\\d+(d|m|y)$"
      },
      "min_age": {
        "type": "string",
        "pattern": "^\\d+(d|m|y)$"
      },
      "action": {
        "type": "string",
        "enum": ["purge", "anonymize"],
        "default": "purge"
      },
      "batch_size": {
        "type": "integer",
        "minimum": 1,
        "default": 1000
      },
      "scope": {
        "type": "string",
        "description": "Named scope to filter which records are eligible"
      },
      "fields": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Fields to clear when action is 'anonymize'"
      },
      "placeholder": {
        "type": "string",
        "description": "Replacement value for anonymized fields (default: null)"
      }
    },
    "additionalProperties": false
  }
}
```

## Interaction with Other Features

### Auditing

Retention is the complement of auditing — auditing creates data, retention removes it.

- The auditing design document lists "automatic purge of old audit records" as a non-goal and defers to this feature
- Retention respects per-model `min_age` constraints to prevent premature deletion of compliance-critical audit data
- When retention purges audit logs, it does NOT write a new audit log entry for the deletion (this would create an infinite loop)
- The `lcp_retention_runs` table serves as the audit trail for retention operations themselves

### Soft Delete

Retention is the lifecycle completion for soft delete — soft delete hides records, retention removes them permanently.

- The soft delete design document lists "automatic purge of old discarded records" as a non-goal and defers to this feature
- Retention uses `destroy!` (hard delete) on soft-deleted records, which triggers AR's `dependent: :destroy` cascades
- Cascade-discarded children (tracked by `discarded_by_type`/`discarded_by_id`) are purged when their parent is purged, because `destroy!` triggers `dependent: :destroy` on AR associations
- Records that were manually discarded (no `discarded_by`) are purged independently based on their own `discarded_at` timestamp

### Custom Fields

When a record is purged, its `custom_data` JSONB column is deleted with it — no special handling needed. When anonymized, `custom_data` is not automatically cleared (it may contain non-PII data). If custom fields contain PII, the configurator should list `custom_data` in the `fields` array.

### Attachments

When a record is purged via `destroy!`, Active Storage attachments are purged via AR's `dependent: :purge` on `has_one_attached` / `has_many_attached`. The orphaned attachments cleanup catches any that slip through (e.g., records deleted via `delete` instead of `destroy`).

### Positioning

No interaction — retention does not affect positioned records' ordering. When a record is purged, the `positioning` gem automatically closes the gap.

## Components Requiring No Changes

| Component | Why it works |
|-----------|-------------|
| **PermissionEvaluator** | Retention runs as a system task, not a user action — no permission checks needed |
| **PolicyFactory** | No new policy methods needed |
| **ResourcesController** | Retention runs outside the request cycle |
| **LayoutBuilder** | No UI for retention management (rake tasks only) |
| **FieldValueResolver** | Does not interact with retention |
| **Events::Dispatcher** | Retention purge does not fire model events (intentional — avoid side effects during cleanup) |

## File Changes Summary

| File | Change |
|------|--------|
| `lib/lcp_ruby/retention/retention_definition.rb` | **New** — policy value object with duration parsing |
| `lib/lcp_ruby/retention/policy_resolver.rb` | **New** — merges global + per-model config |
| `lib/lcp_ruby/retention/executor.rb` | **New** — batch purge/anonymize logic |
| `app/models/lcp_ruby/retention_run.rb` | **New** — AR model for run history |
| `app/jobs/lcp_ruby/retention_job.rb` | **New** — optional ActiveJob adapter |
| `lib/tasks/lcp_ruby_retention.rake` | **New** — `retention:preview` and `retention:apply` rake tasks |
| `lib/lcp_ruby/configuration.rb` | Add `retention`, `retention_executor` accessors |
| `lib/lcp_ruby/metadata/model_definition.rb` | Add `retention_config`, `retention_anonymize?` methods |
| `lib/lcp_ruby/model_factory/schema_manager.rb` | Add `ensure_retention_table!`, `anonymized_at` column support |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Validate `retention` model option |
| `lib/lcp_ruby/schemas/model.json` | Add `retention` to model options schema |
| `lib/lcp_ruby/dsl/model_builder.rb` | Add `retention` DSL method |

## Examples

### Minimal Setup — Global Defaults Only

```yaml
# config/lcp_ruby/retention.yml
retention:
  audit_logs:
    max_age: 2y
  discarded:
    max_age: 90d
  orphaned_attachments:
    max_age: 30d
```

```bash
# Preview what would be cleaned up
bundle exec rake lcp_ruby:retention:preview

# Apply retention policies
bundle exec rake lcp_ruby:retention:apply
```

### Per-Model Overrides

```yaml
# models/invoice.yml — compliance-critical, long retention
name: invoice
auditing: true
soft_delete: true
retention:
  audit_logs:
    min_age: 7y            # must keep at least 7 years for SOX
  discarded:
    max_age: 3y            # keep discarded invoices 3 years

# models/task.yml — short-lived data, aggressive cleanup
name: task
auditing: true
soft_delete: true
retention:
  audit_logs:
    max_age: 90d           # only 3 months of history
  discarded:
    max_age: 7d            # purge discarded tasks after 1 week
```

### Anonymization for GDPR

```yaml
# models/contact.yml
name: contact
auditing: true
fields:
  - name: name
    type: string
  - name: email
    type: email
  - name: phone
    type: phone
  - name: status
    type: enum
    values: { active: Active, closed: Closed }
scopes:
  - name: closed
    where: { status: closed }
retention:
  records:
    max_age: 1y
    action: anonymize
    scope: closed
    fields: [name, email, phone]
    placeholder: "[removed]"
```

After retention runs on a contact closed more than 1 year ago:

| Field | Before | After |
|-------|--------|-------|
| name | "John Doe" | "[removed]" |
| email | "john@example.com" | "[removed]" |
| phone | "+420 123 456 789" | "[removed]" |
| status | "closed" | "closed" (unchanged) |
| anonymized_at | null | "2026-02-22T03:00:00Z" |

### DSL with Host API Override

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.retention = {
    "audit_logs" => { "max_age" => "2y" },
    "discarded" => { "max_age" => "90d" },
    "orphaned_attachments" => { "max_age" => "30d" }
  }

  # Custom executor: archive to S3 before purging
  config.retention_executor = ArchiveAndPurgeExecutor
end

# app/services/archive_and_purge_executor.rb
class ArchiveAndPurgeExecutor
  def self.execute(loader:, dry_run:)
    # 1. Export old records to S3 as JSON
    # 2. Run default purge
    default = LcpRuby::Retention::Executor.new(loader, dry_run: dry_run)
    default.execute_all!
  end
end
```

### Scheduled Execution

```ruby
# Using Solid Queue (Rails 8+)
# config/recurring.yml
retention_cleanup:
  class: LcpRuby::RetentionJob
  schedule: every day at 3am

# Using whenever gem
# config/schedule.rb
every 1.day, at: "3:00 am" do
  rake "lcp_ruby:retention:apply"
end

# Using sidekiq-cron
# config/initializers/sidekiq.rb
Sidekiq::Cron::Job.create(
  name: "Data Retention Cleanup",
  cron: "0 3 * * *",
  class: "LcpRuby::RetentionJob"
)
```

## Test Plan

### Unit Tests

1. **RetentionDefinition — duration parsing** — `"30d"` → 30, `"6m"` → 180, `"2y"` → 730, invalid format raises `ArgumentError`
2. **RetentionDefinition — effective_max_age_days** — returns `max_age` when no `min_age`; returns `min_age` when `min_age > max_age`; returns `max_age` when `max_age > min_age`; returns `nil` when neither set
3. **RetentionDefinition — cutoff_time** — returns `Time.current - max_age.days`; respects `min_age` floor
4. **PolicyResolver — global only** — returns global config when no model override
5. **PolicyResolver — model override** — model config overrides global for the same category
6. **PolicyResolver — min_age merge** — model `min_age` raises floor of global `max_age`
7. **PolicyResolver — no policy** — returns `nil` when neither global nor model config exists
8. **Executor — audit log purge** — deletes audit logs older than cutoff for audited models; respects per-model overrides; respects `min_age`; processes in batches; skips non-audited models
9. **Executor — discarded record purge** — hard-deletes soft-deleted records older than cutoff; respects per-model overrides; uses `destroy!` (not `delete`); processes in batches; skips non-soft-deletable models
10. **Executor — orphaned attachment purge** — deletes blobs with no attachment references older than cutoff
11. **Executor — anonymize** — clears specified fields to placeholder; sets `anonymized_at` timestamp; skips already anonymized records; respects scope filter
12. **Executor — dry run** — counts affected records but does not delete/modify anything; returns results with `dry_run: true`
13. **Executor — run logging** — creates `RetentionRun` entry with results; does not create entry on dry run
14. **ConfigurationValidator — retention** — accepts valid retention config; rejects unknown categories; rejects invalid duration formats; requires at least `max_age` or `min_age`; warns on `discarded` without `soft_delete`; warns on `audit_logs` without `auditing`; requires `fields` for `anonymize` action; validates field references exist
15. **ModelDefinition** — `retention_config` returns hash or nil; `retention_anonymize?` detects anonymize action
16. **DSL ModelBuilder** — `retention` method sets options correctly

### Integration Tests

17. **Rake preview** — `retention:preview` outputs counts without modifying data
18. **Rake apply — audit logs** — creates audit logs, runs retention, verifies old logs deleted and recent logs kept
19. **Rake apply — discarded records** — soft-deletes records, runs retention, verifies old discarded records hard-deleted and recent ones kept; verifies attachments purged with record
20. **Rake apply — orphaned attachments** — creates orphaned blobs, runs retention, verifies old orphans purged and recent ones kept
21. **Rake apply — anonymize** — creates records, runs retention, verifies fields cleared and `anonymized_at` set; verifies audit log records anonymization
22. **Per-model override** — model with longer retention keeps records that global policy would delete
23. **Min-age enforcement** — model with `min_age` keeps records even when global `max_age` would delete them
24. **No retention config** — models without retention config are not affected by retention run
25. **Run history** — `lcp_retention_runs` table records each non-dry-run execution

### Fixture Requirements

- Add `retention:` config to at least one model in integration fixtures
- Add `config/lcp_ruby/retention.yml` to integration fixture directories
- Add audited + soft-deletable model with retention for combined testing
- Add model with `anonymize` action and `fields` list

## Open Questions

1. **Should retention policies be editable at runtime (DB-backed)?** The current design only supports YAML/DSL and host API. A future iteration could add a `lcp_retention_policies` table for runtime management via a generated presenter. Recommendation: defer — retention policies are typically set by administrators at deploy time, not changed by end users.

2. **Should the retention job send notifications?** Email or webhook notification after each run (summary of what was deleted). Recommendation: defer — host apps can wrap the rake task or job with their own notification logic.

3. **Should `min_age` prevent manual hard-delete too?** Currently `min_age` only affects the retention job. A user with `permanently_destroy` permission can hard-delete a record at any time, even within the `min_age` window. Recommendation: yes, this should be enforced — add a check in `permanently_destroy` controller action that rejects deletion of records younger than `min_age`. But defer to a future iteration.

4. **Should retention support different policies per role?** E.g., "admin can see records up to 5 years old, but regular users only see last 2 years." This is scope filtering, not retention (data still exists). Recommendation: out of scope — this is a presenter/permission concern, not retention.

5. **How to handle the global `retention.yml` file?** Should it be loaded by `Metadata::Loader` alongside models/presenters, or by `Configuration` as an engine config? Recommendation: load via `Metadata::Loader` — it follows the same YAML-in-`config/lcp_ruby/` pattern, and the loader already handles file-not-found gracefully.

6. **Should anonymization clear custom_data JSONB fields individually?** Currently, listing `custom_data` in `fields` clears the entire JSON blob. A more granular approach would support `cf:field_name` syntax (matching the auditing prefix convention) to clear individual custom fields. Recommendation: defer — full `custom_data` clearing is sufficient for the initial implementation.
