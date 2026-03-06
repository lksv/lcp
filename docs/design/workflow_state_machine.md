# Feature Specification: Workflow State Machine

**Status:** Proposed
**Date:** 2026-03-06

**Continuation:** This document is the first part of the workflow system. The second part, [Workflow Approvals](workflow_approvals.md), extends the state machine with a multi-step approval engine. The architecture described here is explicitly designed to support that extension — see [Extensibility for Approvals](#extensibility-for-approvals) for the key design points.

**Prerequisites:**
- [Advanced Conditions](advanced_conditions.md) — compound conditions (`all`/`any`/`not`), dot-path fields, dynamic value references (`field_ref`, `current_user`, `date`). Workflow guards depend on these.

**Related:**
- [Auditing](auditing.md) — data-level change tracking. Coexists with workflow audit (see [Coexistence with Data Auditing](#coexistence-with-data-auditing)).

---

## Problem / Motivation

The platform has enum fields and presenters that can display state-like values, but there is no behavioral layer that governs how records move between states. Today:

- **No transition enforcement** — any user with `update` permission can set an enum field to any value. There is no way to declare "only move from draft to submitted, never skip to approved."
- **No guard conditions** — there is no declarative way to say "this transition is only allowed when amount > 0 AND title is present."
- **No side effects on transition** — auto-setting fields (submitted_at, approved_by), firing events, and locking fields after a state change all require custom event handlers per model.
- **No transition audit** — the data audit log records that `status` changed from "draft" to "submitted", but not who triggered the transition, why, or whether a comment was provided.
- **No versioning** — changing a workflow definition affects all records immediately, including those mid-process.

These gaps force developers to reimplement state machine logic in custom actions and event handlers for every model, defeating the purpose of a declarative low-code platform.

## User Scenarios

**As a business analyst,** I want to define allowed state transitions in YAML (draft -> submitted -> approved/rejected) with guard conditions, so business rules are declarative and version-controlled.

**As a form designer,** I want transition buttons (Submit, Approve, Reject) to appear automatically on the show page based on the current state and user's role, without configuring each button manually.

**As a compliance officer,** I want every state transition logged with who triggered it, when, from/to states, and any comment provided, in a dedicated audit table separate from field-level data changes.

**As an administrator,** I want certain fields locked after approval (readonly_fields) without writing record_rules for each state manually.

**As a platform developer,** I want workflow definitions loadable from YAML, database, or host application code, following the same three-source pattern as roles and custom fields.

## Configuration & Behavior

### 1. Relationship to Model

The model defines an `enum` field with possible values (states). The workflow adds behavioral rules on top — which transitions are allowed, under what conditions, with what side effects. The model stays clean:

```yaml
# Model — data structure only
fields:
  - name: status
    type: enum
    values: { draft: "Draft", submitted: "Submitted", approved: "Approved" }

# Workflow — behavioral rules (separate file)
workflow:
  field: status  # references the model's enum
  transitions:
    submit:
      from: draft
      to: submitted
```

When a workflow is active on a model, direct enum updates are blocked — the record can only change state through defined transitions.

### 2. YAML Configuration

```yaml
# config/lcp_ruby/workflows/purchase_order.yml
workflow:
  name: purchase_order_workflow
  model: purchase_order
  field: status                   # which enum field is the state machine
  version: 1                      # records store version at creation time
  audit_log: true                 # auto-log every transition (default: true)

  states:
    draft:
      initial: true               # default state for new records
      category: draft              # semantic grouping: draft | in_progress | waiting
      color: gray                  #                    approved | rejected | terminal
      icon: file-text
      description: "New purchase order, not yet submitted"

    pending_approval:
      category: waiting
      color: blue
      icon: clock
      readonly_fields: [title, total_amount, department_id]   # locked while in this state
      on_entry: [notify_approvers]                            # events fired on entering state
      on_exit: [log_approval_exit]                            # events fired on leaving state

    approved:
      category: terminal           # terminal states cannot be left (unless transition explicitly allows)
      color: green
      icon: check-circle
      readonly_fields: all         # fully locked after approval

    rejected:
      category: rejected
      color: red
      icon: x-circle

  transitions:
    submit:
      from: draft
      to: pending_approval
      label: "Submit for Approval"
      icon: send
      style: primary               # default | primary | success | danger
      roles: [author, admin]
      guard:                        # compound condition (requires advanced_conditions)
        all:
          - { field: title, operator: present }
          - { field: total_amount, operator: gt, value: 0 }
      actions:
        set_fields:
          submitted_at: { value: now }
          submitted_by: { value: current_user.id }
      events: [po_submitted]       # fire named events after transition
      confirm: true
      confirm_message: "Submit this PO for approval?"
      require_comment: false

    approve:
      from: pending_approval
      to: approved
      label: "Approve"
      icon: check
      roles: [admin]
      trigger: system              # "user" (default) | "system" | "both"
                                   # system = not shown as UI button, only callable programmatically
      actions:
        set_fields:
          approved_at: { value: now }

    reject:
      from: pending_approval
      to: rejected
      label: "Reject"
      icon: x
      style: danger
      roles: [admin]
      trigger: system
      require_comment: true        # mandatory reason
      actions:
        set_fields:
          rejected_at: { value: now }

    rework:
      from: rejected
      to: draft
      label: "Return to Draft"
      icon: rotate-ccw
      roles: [author, admin]

    force_approve:
      from: pending_approval
      to: approved
      label: "Force Approve"
      icon: shield
      roles: [admin]               # admin bypass
      require_comment: true
```

### 3. DSL Configuration

```ruby
# config/lcp_ruby/workflows/purchase_order.rb
define_workflow :purchase_order_workflow do
  model :purchase_order
  field :status
  version 1
  audit_log true

  state :draft, initial: true, category: :draft, color: "gray", icon: "file-text"
  state :pending_approval, category: :waiting, color: "blue", icon: "clock",
    readonly_fields: [:title, :total_amount, :department_id],
    on_entry: [:notify_approvers]
  state :approved, category: :terminal, color: "green", icon: "check-circle",
    readonly_fields: :all
  state :rejected, category: :rejected, color: "red", icon: "x-circle"

  transition :submit, from: :draft, to: :pending_approval,
    label: "Submit for Approval", icon: "send", style: :primary,
    roles: [:author, :admin], confirm: true do
    guard all: [
      { field: :title, operator: :present },
      { field: :total_amount, operator: :gt, value: 0 }
    ]
    set_fields submitted_at: :now, submitted_by: "current_user.id"
    fire_events :po_submitted
  end

  transition :approve, from: :pending_approval, to: :approved,
    label: "Approve", icon: "check", roles: [:admin],
    trigger: :system do
    set_fields approved_at: :now
  end

  transition :reject, from: :pending_approval, to: :rejected,
    label: "Reject", icon: "x", style: :danger, roles: [:admin],
    trigger: :system, require_comment: true do
    set_fields rejected_at: :now
  end

  transition :rework, from: [:rejected, :pending_approval], to: :draft,
    label: "Return to Draft", icon: "rotate-ccw", roles: [:author, :admin]

  transition :force_approve, from: :pending_approval, to: :approved,
    label: "Force Approve", icon: "shield", roles: [:admin], require_comment: true
end
```

### 4. Transition Reference

| Key | Type | Required | Description |
|---|---|---|---|
| `from` | String or Array | yes | Source state(s) |
| `to` | String | yes | Target state |
| `label` | String | yes | Button label in UI (i18n key: `lcp_ruby.workflows.<name>.transitions.<transition>`) |
| `icon` | String | no | Icon name |
| `style` | String | no | `default` / `primary` / `success` / `danger` |
| `roles` | Array | no | Roles allowed to trigger (intersected with permission system) |
| `guard` | Hash | no | Condition (simple or compound) that must be true. Uses `ConditionEvaluator` — supports all operators and compound syntax from [Advanced Conditions](advanced_conditions.md) |
| `actions.set_fields` | Hash | no | Field values to auto-set on transition |
| `events` | Array | no | Named events to fire after transition |
| `require_comment` | Boolean | no | Mandatory comment input (default: false) |
| `confirm` | Boolean | no | Show confirmation dialog (default: false) |
| `confirm_message` | String | no | Custom confirmation text |
| `trigger` | String | no | `user` (default) = UI button, `system` = only callable programmatically, `both` = UI button and programmatic |

### 5. Set Fields — Value Expressions

| Expression | Resolves to |
|---|---|
| `{ value: now }` | `Time.current` |
| `{ value: today }` | `Date.current` |
| `{ value: null }` | `nil` (clears the field) |
| `{ value: current_user.id }` | Authenticated user's ID |
| `{ value: current_user.email }` | Authenticated user's email |
| `{ value: "literal" }` | Literal string |
| `{ value: 42 }` | Literal number |
| `{ field: "other_field" }` | Copy value from another field on the record |

### 6. State-Level Behavior

States can define behavior that applies regardless of which transition brought the record there.

#### Entry/Exit Hooks

`on_entry` and `on_exit` fire named events when a record enters or leaves a state. Unlike transition-level `events` (which fire for a specific transition), these fire for ANY transition that leads to/from this state. Uses existing `Events::Dispatcher`.

```yaml
states:
  pending_approval:
    on_entry: [notify_approvers, start_sla_timer]    # fired after record enters this state
    on_exit: [log_approval_exit]                      # fired before record leaves this state
```

```ruby
# app/event_handlers/purchase_order/notify_approvers.rb
class NotifyApprovers < LcpRuby::Events::HandlerBase
  def self.handles_event = "notify_approvers"
  def self.async? = true

  def call
    # record is already in the new state
    # current_user is the person who triggered the transition
  end
end
```

Execution order for a transition `draft -> pending_approval`:
1. Guard evaluated
2. `set_fields` applied
3. Record saved (state updated)
4. Audit log written
5. `on_exit` events for `draft` (if any)
6. `on_entry` events for `pending_approval`
7. Transition-level `events`

#### Readonly Fields per State

`readonly_fields` makes fields non-writable while the record is in a given state. Integrates with existing `PermissionEvaluator` — the fields become non-writable for all roles.

```yaml
states:
  pending_approval:
    readonly_fields: [title, total_amount, department_id]

  approved:
    readonly_fields: all            # all fields locked
```

This replaces the need to manually write `record_rules` for each state. The engine generates the equivalent permission restrictions automatically. Admin override remains possible via `force_approve` transition or similar.

In the presenter, readonly fields render with disabled styling (same as existing `disable_when` behavior). On the server side, the controller's `permitted_params` filters them out.

### 7. Versioning and Definition Freeze

Each record stores the workflow version it was created with (in a `workflow_version` integer field, auto-added by the engine). When the workflow definition changes:

- New records use the new version.
- Existing records continue using their stored version.
- The engine loads all active versions and applies the correct one per record.
- Old versions can be marked `deprecated: true` to prevent new records from using them.

**Definition freeze per instance**: The workflow engine always resolves the definition matching the record's `workflow_version`. This means:

- A running process uses the definitions from the version the record started with — even if the current version has different rules.
- The audit log stores `workflow_version` on every entry, so the audit trail is fully reproducible.
- When `workflow_source == :model` (DB-stored definitions), the `Registry` must be able to load specific versions, not just the latest. The DB model should store all versions (not overwrite in place).

### 8. Presenter Integration

Transitions auto-generate action buttons in the presenter. The presenter can customize appearance or suppress individual transitions:

```yaml
# In presenter YAML — transitions auto-appear alongside other actions
actions:
  single:
    # Override transition appearance:
    - name: submit             # matches transition name
      style: primary

    # Suppress a transition from this presenter:
    - name: force_approve
      visible: false

    # Non-workflow actions work as before:
    - { name: show, type: built_in, icon: eye }
    - { name: edit, type: built_in, icon: pencil }
```

A transition is visible to a user when ALL of these are true:

```
permission.can?(:update, record)
  AND user.role IN transition.roles
  AND record.state IN transition.from
  AND guard condition passes (if defined)
  AND presenter has not suppressed it (visible: false)
```

### 9. Permission Integration

Transition `roles` work alongside the existing permission system. A user must have BOTH the transition role AND `update` CRUD permission. Existing `record_rules` also apply — if a record rule denies `update`, no transitions are possible.

No duplication needed between permissions YAML and workflow YAML. Permissions control field-level and CRUD access; workflows control state transitions.

### 10. Direct Enum Update Blocking

When a workflow is active on a model's enum field, the engine installs a `before_save` validation that prevents direct changes to the workflow field. The field can only be changed through `TransitionExecutor`.

```ruby
# Blocked:
record.update!(status: "approved")  # => validation error

# Allowed:
TransitionExecutor.execute(record, :approve, user: current_user)
```

The blocking uses an internal flag (`@_workflow_transition_active`) that `TransitionExecutor` sets before saving. This prevents accidental state changes through forms, API calls, or bulk updates that bypass the transition guard logic.

## Data Model

### Workflow Audit Log Table

A dedicated table for transition history, separate from the data audit log (`lcp_audit_logs`). Created via `SchemaManager` using the `create_log_table` helper (same pattern as [Auditing](auditing.md)).

```
workflow_audit_logs
  id                bigint PK
  record_type       string NOT NULL    -- lcp model name ("purchase_order")
  record_id         bigint NOT NULL    -- record ID
  workflow_name     string NOT NULL
  workflow_version  integer NOT NULL
  transition_name   string NOT NULL
  from_state        string NOT NULL
  to_state          string NOT NULL
  user_id           bigint             -- who triggered the transition
  user_snapshot     jsonb              -- {id, email, name, role} snapshot at time of transition
  comment           text               -- user-provided comment (nullable)
  metadata          jsonb              -- extra context (guard result, triggered_by, etc.)
  created_at        datetime NOT NULL
```

**Indexes:**
- `(record_type, record_id, created_at)` — primary query pattern
- `(user_id, created_at)` — "what did user X transition?"
- `(workflow_name, transition_name, created_at)` — transition analytics

### Coexistence with Data Auditing

When a model has both `auditing: true` and a workflow, both audit systems run independently:

| | Data Auditing (`lcp_audit_logs`) | Workflow Auditing (`workflow_audit_logs`) |
|---|---|---|
| **Trigger** | `after_save` callback | `TransitionExecutor` after save |
| **Records** | Field-level diffs: `{"status": ["draft", "submitted"]}` | Transition metadata: who, from/to, comment, guard result |
| **Purpose** | "What changed on this record?" | "What state transitions occurred and why?" |
| **Table** | Shared `lcp_audit_logs` (polymorphic) | Dedicated `workflow_audit_logs` |

No conflict. Both tables are written during the same transaction. The data audit captures the field change; the workflow audit captures the transition context.

### Key Queries

```sql
-- Transition history for a record
SELECT transition_name, from_state, to_state, user_id, comment, created_at
FROM workflow_audit_logs
WHERE record_type = 'purchase_order' AND record_id = :id
ORDER BY created_at

-- All transitions by a user
SELECT record_type, record_id, transition_name, from_state, to_state, created_at
FROM workflow_audit_logs
WHERE user_id = :user_id
ORDER BY created_at DESC

-- Transition frequency analytics
SELECT transition_name, COUNT(*) AS count, AVG(EXTRACT(EPOCH FROM created_at)) AS avg_time
FROM workflow_audit_logs
WHERE workflow_name = 'purchase_order_workflow'
GROUP BY transition_name
```

## Three Definition Sources

Both the state machine definitions support three interchangeable sources. All three satisfy the same contract — the engine does not care where definitions come from.

```
+--------------------------------------------+
|           Workflow::Resolver               |
|  (merges definitions from active sources)  |
|  priority: static > model > host           |
+------+---------+-------------+-------------+
       |         |             |
  +----v---+ +--v-----+ +----v----+
  | Static | | Model  | |  Host   |
  | (YAML/ | | (DB    | | (Ruby   |
  |  DSL)  | | table) | |  class) |
  +--------+ +--------+ +---------+
```

### Contract

```ruby
# lib/lcp_ruby/workflow/state_machine_contract.rb
module LcpRuby
  module Workflow
    module StateMachineContract
      # @param model_name [String]
      # @return [Array<Hash>] workflow definition hashes
      def workflows_for(model_name)
        raise NotImplementedError
      end

      # @param workflow_name [String]
      # @return [Hash, nil]
      def workflow_by_name(workflow_name)
        raise NotImplementedError
      end
    end
  end
end
```

### Source: Static (YAML / DSL)

Definitions in `config/lcp_ruby/workflows/*.yml` or `.rb`, loaded at boot. Always active if workflow files exist.

### Source: Model (DB Table)

Same pattern as Custom Fields and Roles: a DB model stores workflow definitions as records. Validated at boot via `ContractValidator`.

**Configuration:**

```ruby
LcpRuby.configure do |c|
  c.workflow_source = :model
  c.workflow_model = "workflow_definition"
  c.workflow_model_fields = {
    name: "name", model_name: "model_name", field_name: "field_name",
    states: "states", transitions: "transitions",
    version: "version", active: "active"
  }
end
```

**Generator:**

```bash
rails generate lcp_ruby:workflow              # creates model, presenter, permissions, view group
rails generate lcp_ruby:workflow --format=yaml
```

**Contract Validator** — validates the DB model has required fields:

```ruby
WORKFLOW_MODEL_REQUIRED_FIELDS = {
  "name"        => "string",
  "model_name"  => "string",
  "field_name"  => "string",
  "states"      => "json",
  "transitions" => "json",
  "version"     => "integer",
  "active"      => "boolean"
}.freeze
```

**Registry** — thread-safe cache with `Monitor`, same pattern as `Roles::Registry`.

**ChangeHandler** — installed on the DB model, invalidates cache on `after_commit`.

### Source: Host (Application Contract)

The host application provides a Ruby class implementing the contract methods. For complex routing logic that cannot be expressed in YAML or DB records.

**Configuration:**

```ruby
LcpRuby.configure do |c|
  c.workflow_source = :host
  c.workflow_provider = "WorkflowProvider"
end
```

**Host implementation:**

```ruby
# app/workflow_providers/workflow_provider.rb
class WorkflowProvider
  include LcpRuby::Workflow::StateMachineContract

  def workflows_for(model_name)
    case model_name
    when "purchase_order"
      [purchase_order_workflow]
    else
      []
    end
  end

  def workflow_by_name(name)
    send(name) if respond_to?(name, true)
  end

  private

  def purchase_order_workflow
    {
      name: "purchase_order_workflow",
      model: "purchase_order",
      field: "status",
      version: 1,
      audit_log: true,
      states: { "draft" => { initial: true, category: "draft" }, ... },
      transitions: { "submit" => { from: "draft", to: "pending", ... }, ... }
    }
  end
end
```

### Resolver (Merges Sources)

The Resolver aggregates definitions from all active sources. Priority on name conflicts: static > model > host.

### Configuration Reference

```ruby
LcpRuby.configure do |c|
  c.workflow_source = :static     # :static | :model | :host (default: :static)

  # DB model source settings
  c.workflow_model = "workflow_definition"
  c.workflow_model_fields = {
    name: "name", model_name: "model_name", field_name: "field_name",
    states: "states", transitions: "transitions",
    version: "version", active: "active"
  }

  # Host source settings
  c.workflow_provider = nil       # class name string, e.g. "WorkflowProvider"
end
```

### Boot Sequence

```ruby
# In Engine.load_metadata!, after existing setup:
CustomFields::Setup.apply!(loader)
Roles::Setup.apply!(loader)
Workflow::Setup.apply!(loader)     # new, runs after roles
```

`Workflow::Setup.apply!` does:

1. Collect static source (if workflow YAML/DSL files exist).
2. If `workflow_source == :model`: find model definition -> validate contract -> mark registry available -> install ChangeHandler.
3. If `workflow_source == :host`: constantize provider class -> validate contract methods.
4. Configure `Resolver` with all active sources.

## Extensibility for Approvals

The state machine is designed to be extended by an approval engine ([Workflow Approvals](workflow_approvals.md)) without modifying the core. The key extension points:

### 1. System Triggers

Transitions with `trigger: system` are not shown as UI buttons but are callable programmatically. The approval engine uses this to fire `approve`/`reject`/`rework` transitions when an approval process completes:

```ruby
# Called by the approval engine, not by a user clicking a button:
TransitionExecutor.execute(record, :approve, user: system_user, triggered_by: "approval_engine")
```

The `triggered_by` value is stored in the workflow audit log's `metadata` field, providing full traceability.

### 2. State Categories

The `category: waiting` on states signals that the record is waiting for an external process (like approval). The approval engine uses this to identify which states have approval definitions attached.

### 3. On-Entry Hooks

The `on_entry` event mechanism provides a clean integration point. When a record enters an approval state, the approval engine listens for the entry event and activates the approval process.

### 4. Workflow Definition Extensibility

The workflow YAML format accepts additional top-level sections that the state machine core ignores. The approval engine adds an `approvals:` section to the workflow definition:

```yaml
workflow:
  name: purchase_order_workflow
  # ... states, transitions (handled by state machine) ...

  approvals:                        # ignored by state machine, consumed by approval engine
    pending_approval:
      strategy: sequential
      steps: [...]
```

This keeps the workflow definition cohesive (state machine + approvals in one file) while maintaining separation of concerns in the engine code.

## General Implementation Approach

### Implementation Structure

```
lib/lcp_ruby/workflow/
  state_machine.rb              # Core: validates transition against definition
  transition_executor.rb        # Orchestrates: guard -> role -> set fields ->
                                #   update record -> audit log -> events
  resolver.rb                   # Merges definitions from all active sources
  registry.rb                   # Thread-safe cache for DB-sourced definitions
  contract_validator.rb         # Validates DB model fields & host provider methods
  setup.rb                      # Boot orchestration (same pattern as Roles::Setup)
  change_handler.rb             # after_commit cache invalidation
  audit_log.rb                  # Auto-creates table, writes entries, queries history
  definition.rb                 # Normalized workflow definition value object
  sources/
    static_source.rb            # Reads from Loader (parsed YAML/DSL)
    model_source.rb             # Reads from DB table via Registry
    host_source.rb              # Delegates to host-provided class
```

### Reused Existing Modules

| Workflow need | Existing module |
|---|---|
| Guard evaluation | `ConditionEvaluator` (with compound conditions from [Advanced Conditions](advanced_conditions.md)) |
| Role checks | `PermissionEvaluator.can?` |
| Side effects | `Events::Dispatcher` + event handlers |
| Auto-set fields | Inspired by `TransformApplicator` |
| Dynamic table creation | `SchemaManager` (with `create_log_table` helper from [Auditing](auditing.md)) |
| Cache pattern | `Roles::Registry` / `CustomFields::Registry` |
| Contract validation | `ContractValidator` / `ContractResult` |
| UI action buttons | `ActionSet` + `ActionExecutor` |
| User snapshot | `LcpRuby::UserSnapshot` (from [Auditing](auditing.md)) |

## Usage Examples

### Complete Purchase Order Example

#### Model

```ruby
define_model :purchase_order do
  label "Purchase Order"
  label_plural "Purchase Orders"

  field :title, :string, null: false do
    validates :presence
  end

  field :status, :enum, default: "draft",
    values: {
      draft: "Draft",
      pending_approval: "Pending Approval",
      approved: "Approved",
      rejected: "Rejected"
    }

  field :total_amount, :decimal, precision: 12, scale: 2 do
    validates :numericality, greater_than: 0
  end

  field :submitted_at, :datetime
  field :submitted_by, :integer
  field :approved_at, :datetime
  field :rejected_at, :datetime

  belongs_to :department, model: :department, required: true

  scope :pending, where: { status: "pending_approval" }
  scope :approved, where: { status: "approved" }

  timestamps true
  auditing true
  label_method :title
end
```

#### Workflow

```ruby
define_workflow :purchase_order_workflow do
  model :purchase_order
  field :status
  version 1

  state :draft, initial: true, category: :draft, color: "gray"
  state :pending_approval, category: :waiting, color: "blue", icon: "clock",
    readonly_fields: [:title, :total_amount, :department_id],
    on_entry: [:notify_approvers]
  state :approved, category: :terminal, color: "green", icon: "check-circle",
    readonly_fields: :all
  state :rejected, category: :rejected, color: "red", icon: "x-circle"

  transition :submit, from: :draft, to: :pending_approval,
    label: "Submit", icon: "send", style: :primary,
    roles: [:author, :admin], confirm: true do
    guard all: [
      { field: :title, operator: :present },
      { field: :total_amount, operator: :gt, value: 0 }
    ]
    set_fields submitted_at: :now, submitted_by: "current_user.id"
    fire_events :po_submitted
  end

  transition :approve, from: :pending_approval, to: :approved,
    roles: [:admin], trigger: :system do
    set_fields approved_at: :now
  end

  transition :reject, from: :pending_approval, to: :rejected,
    roles: [:admin], trigger: :system, require_comment: true do
    set_fields rejected_at: :now
  end

  transition :rework, from: [:rejected, :pending_approval], to: :draft,
    label: "Return to Draft", icon: "rotate-ccw", roles: [:author, :admin]

  transition :force_approve, from: :pending_approval, to: :approved,
    label: "Force Approve", icon: "shield", roles: [:admin], require_comment: true
end
```

#### Permissions

```yaml
permissions:
  model: purchase_order

  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all

    author:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [title, total_amount, department_id]
      scope: all

    manager:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      scope: all

  default_role: author

  record_rules:
    - name: submitted_readonly
      condition: { field: status, operator: in, value: [pending_approval, approved] }
      effect:
        deny_crud: [update, destroy]
        except_roles: [admin]
```

#### What Happens at Runtime

1. User creates PO (status: `draft`, workflow_version: `1`).
2. User clicks "Submit" -> engine checks guard (title present, amount > 0), checks role (author), executes transition -> status becomes `pending_approval`, `submitted_at` set, `po_submitted` event fired, `on_entry: notify_approvers` event fired.
3. Admin clicks "Force Approve" (user-triggered) -> transition executes -> status becomes `approved`, `readonly_fields: all` locks the record.
4. Alternative: system triggers `approve` transition programmatically (e.g., from an approval engine) -> same result but `metadata: { triggered_by: "approval_engine" }` in audit log.
5. Audit log records all transitions with `workflow_version: 1`.
6. Data audit log (if `auditing: true`) independently records field-level changes.

## Decisions

1. **`trigger: system` instead of approval-specific trigger values.** The state machine does not know about the approval engine. It only knows that some transitions are programmatic. This keeps the state machine generic and extensible.

2. **Separate `workflow_audit_logs` table.** Not merged with `lcp_audit_logs`. Different structure (transition metadata vs. field diffs), different query patterns, different retention policies. Both can coexist on the same model.

3. **Guard conditions delegate to `ConditionEvaluator`.** No custom guard evaluation logic. Compound conditions (`all`/`any`/`not`), dot-paths, and dynamic references are all handled by [Advanced Conditions](advanced_conditions.md).

4. **Workflow definition format is extensible.** Additional top-level sections (like `approvals:`) are accepted and ignored by the state machine core. This allows the approval engine to add its configuration to the same file.

5. **Direct enum update blocking via `before_save`.** When a workflow is active, the enum field can only change through `TransitionExecutor`. This prevents bypassing guards and audit logging.

6. **`on_entry`/`on_exit` use existing `Events::Dispatcher`.** No new event system. Handlers are standard event handler classes in `app/event_handlers/`.

7. **Three definition sources follow established patterns.** Registry, ContractValidator, ChangeHandler, Setup — all follow the same conventions as Roles and CustomFields subsystems.

## Open Questions

1. **Should `from` accept wildcards?** E.g., `from: "*"` meaning "from any state". Useful for admin-only "reset to draft" transitions. Alternative: explicit array of all states.

2. **Should the workflow field be immutable after record creation?** Currently `workflow_version` is set on create and never changes. But what if a record needs to be migrated to a new workflow version? A manual admin action could allow this.

3. **How to handle model enum values not covered by workflow states?** If the enum has a value that is not in the workflow's `states`, should the engine raise an error at boot or ignore it? Recommendation: warning at boot, since legacy data may have old values.
