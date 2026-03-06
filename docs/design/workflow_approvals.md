# Feature Specification: Workflow Approvals

**Status:** Proposed
**Date:** 2026-03-06

**Prerequisites:**
- [Workflow State Machine](workflow_state_machine.md) — states, transitions, guards, system triggers, audit log, three definition sources. This document extends the state machine with a multi-step approval engine.
- [Advanced Conditions](advanced_conditions.md) — compound conditions, dot-path fields, dynamic value references. Used in step conditions and bypass rules.

**Related:**
- [Auditing](auditing.md) — data-level change tracking. Complementary to workflow audit and approval audit.

---

## Problem / Motivation

The [Workflow State Machine](workflow_state_machine.md) provides declarative state transitions with guards, roles, and audit logging. However, many business processes require more than simple role-guarded transitions:

- **Multi-step approval chains** — a purchase order over 50,000 needs manager approval, then finance approval, then director sign-off. Each step has different approvers.
- **Dynamic approver resolution** — the approver is not a fixed role but depends on record data (department head, project manager, N levels up in the org hierarchy).
- **Approval strategies** — some processes require sequential approval (step by step), others require parallel approval (all reviewers at once, majority vote).
- **Delegation** — an approver goes on vacation and needs to delegate their pending tasks to a colleague.
- **Rework cycles** — an approver sends the record back for corrections. After rework, the approval process restarts (fully or partially).
- **Auto-approval bypass** — trivial cases (amount below threshold) should skip the approval process entirely.

Without a dedicated approval engine, these patterns require complex custom action code per model, with no reuse, no standard UI, and no audit trail.

## User Scenarios

**As a finance controller,** I want purchase orders above 50,000 to require sequential approval by manager then finance team, so spending is properly authorized before commitment.

**As a team lead,** I want to claim an approval task from a pool (so my colleagues do not duplicate work), review the record, and approve or reject with a comment.

**As a manager on vacation,** I want to delegate my pending approval tasks to my deputy, so the process is not blocked during my absence.

**As a process owner,** I want rejected records returned to the author for rework, and when resubmitted, I want the approval process to restart from step 1 (or resume from where it left off, depending on configuration).

**As a business analyst,** I want to configure auto-approval for orders under 1,000, so trivial cases do not waste approvers' time.

**As an auditor,** I want to see the complete approval history: who was assigned, who claimed, who approved/rejected, when, and with what comment.

## Configuration & Behavior

### 1. Approval Definition in Workflow YAML

Approvals are defined inside the workflow file, in a separate `approvals` section keyed by the state where the approval process runs. The state machine core ignores this section (see [Workflow State Machine — Extensibility](workflow_state_machine.md#extensibility-for-approvals)).

```yaml
# Inside config/lcp_ruby/workflows/purchase_order.yml, after transitions:
  approvals:
    pending_approval:                    # approval runs while record is in this state
      strategy: sequential               # sequential | parallel

      bypass_when:                       # auto-approval for trivial cases
        field: total_amount
        operator: lte
        value: 1000

      resolution:
        approved: approve                # all steps pass -> trigger "approve" transition
        rejected: reject                 # any step rejects -> trigger "reject" transition
        returned: rework                 # approver returns for rework -> trigger "rework" transition

      # Global resolution rules for parallel strategy:
      on_reject: any                     # any | all — reject on first rejection vs. wait for all
      short_circuit: true                # when outcome is determined, cancel remaining pending tasks

      rework_policy:
        reset: all                       # all | pending_only | none

      steps:
        - name: manager_review
          label: "Manager Review"
          approvers:
            type: role                   # role | field | group | hierarchy | service
            role: manager
          required: 1                    # how many must approve (default: 1)
          assignment: all                # all | claim | single
          fallback:                      # used when primary approvers resolve to empty
            type: role
            role: hr_manager

        - name: finance_review
          label: "Finance Review"
          approvers:
            type: group
            group: finance_team
          required: 1
          assignment: claim              # approver must claim before deciding
          condition:                     # step only applies when condition is true
            field: total_amount
            operator: gt
            value: 50000

        - name: director_review
          label: "Director Approval"
          approvers:
            type: hierarchy
            levels_up: 2                 # 2 levels above the record author
          required: 1
          condition:
            field: total_amount
            operator: gt
            value: 200000
          fallback:
            type: role
            role: ceo

      allow_delegation: true
      delegation_roles: [manager, director]
      max_delegation_depth: 2
      require_reject_comment: true
      allow_approve_with_comment: true
```

### 2. DSL Configuration

```ruby
# Inside define_workflow block:
  approval :pending_approval do
    strategy :sequential
    resolution approved: :approve, rejected: :reject, returned: :rework
    bypass_when field: :total_amount, operator: :lte, value: 1000
    on_reject :any
    short_circuit true
    rework_policy reset: :all

    step :manager_review, label: "Manager Review" do
      approvers type: :role, role: :manager
      required 1
      assignment :all
      fallback type: :role, role: :hr_manager
    end

    step :finance_review, label: "Finance Review" do
      approvers type: :group, group: :finance_team
      required 1
      assignment :claim
      condition field: :total_amount, operator: :gt, value: 50000
    end

    step :director_review, label: "Director Approval" do
      approvers type: :hierarchy, levels_up: 2
      required 1
      condition field: :total_amount, operator: :gt, value: 200000
      fallback type: :role, role: :ceo
    end

    allow_delegation true
    require_reject_comment true
  end
```

### 3. Approver Resolution Types

| Type | Config | Resolves to |
|---|---|---|
| `role` | `role: manager` | All users with this role |
| `field` | `field: "department.manager_id"` | User ID from record field (dot-path supported) |
| `group` | `group: finance_team` | Members of a named approval group |
| `hierarchy` | `levels_up: 2` | N levels above the record author in org hierarchy |
| `service` | `service: resolve_approver` | Custom Ruby service determines approvers |

Service example:

```ruby
# app/lcp_services/approval_resolvers/resolve_approver.rb
module LcpRuby::HostServices::ApprovalResolvers
  class ResolveApprover
    def self.call(record:, step:, current_user:)
      # Return array of user IDs
      if record.total_amount > 500_000
        User.where(role: "cfo").pluck(:id)
      else
        User.where(role: "finance_manager").pluck(:id)
      end
    end
  end
end
```

### 4. Approval Strategies

**Sequential** — steps execute one after another. Step 2 does not start until step 1 resolves.

```
submit -> [step 1: manager] -> [step 2: finance] -> [step 3: director] -> approved
                                    | (reject at any step)
                                 rejected
```

Conditional steps are evaluated when their turn comes. If the condition is false, the step is marked `skipped` and the next step activates.

**Parallel** — all steps start simultaneously. Each step has its own `required` count.

```
submit -> [step 1: manager (1/1)]   -+
          [step 2: finance (1/3)]   -+-> all resolved -> approved
          [step 3: director (1/1)]  -+
```

Parallel with voting:

```yaml
steps:
  - name: committee_vote
    approvers:
      type: group
      group: review_committee        # 5 members
    required: 3                      # majority (3 of 5) must approve
```

### 5. Approval Groups

Defined in a separate metadata file:

```yaml
# config/lcp_ruby/approval_groups.yml
approval_groups:
  finance_team:
    label: "Finance Team"
    members:
      type: role
      role: finance_reviewer

  review_committee:
    label: "Review Committee"
    members:
      type: scope                    # dynamic query
      model: user
      scope: review_committee_members
```

DSL:

```ruby
define_approval_group :finance_team do
  label "Finance Team"
  members type: :role, role: :finance_reviewer
end

define_approval_group :review_committee do
  label "Review Committee"
  members type: :scope, model: :user, scope: :review_committee_members
end
```

### 6. Task Assignment Modes

When a step has multiple potential approvers, the `assignment` mode controls how tasks are distributed:

| Mode | Behavior |
|---|---|
| `all` (default) | All resolved approvers receive a task. Any `required` of them can approve. Tasks stay open until `required` count is met. |
| `claim` | All resolved approvers see the task in their inbox, but one must **claim** it before deciding. After claim, others can no longer act on it. Prevents duplicate work in large pools. |
| `single` | The resolver returns exactly one person (or the engine picks the first). Only that person gets a task. Useful with `type: field` or `type: hierarchy`. |

In the `claim` model, the `workflow_approval_tasks` table tracks:
- `status: pending` — visible in inbox, not yet claimed.
- `status: claimed` — claimed by this approver, others' tasks move to `cancelled`.
- `status: approved` / `rejected` — decision made.

### 7. Delegation

When `allow_delegation: true`, an approver can delegate their task to another user. Delegation creates a new task for the delegate and marks the original as `delegated`.

| Config key | Type | Description |
|---|---|---|
| `allow_delegation` | Boolean | Enable delegation (default: false) |
| `delegation_roles` | Array | Restrict who can be delegated to (optional) |
| `max_delegation_depth` | Integer | Prevent infinite chains (default: 1) |

### 8. Fallback Approvers

When the primary approver resolver returns an empty list (e.g., no user has the `manager` role, or the `department.manager_id` field is null), the step would be stuck forever. The `fallback` key provides an alternative:

```yaml
steps:
  - name: manager_review
    approvers:
      type: hierarchy
      levels_up: 1
    fallback:
      type: role
      role: hr_manager
```

Resolution order: primary approvers -> fallback -> error (if both empty, the step is marked `error` and the approval request moves to a `stuck` status, visible in admin monitoring).

### 9. Auto-Approval Bypass

When `bypass_when` is defined on an approval and the condition evaluates to true at the moment the record enters the approval state, the entire approval process is skipped. The engine immediately triggers the `resolution.approved` transition via the state machine's system trigger.

```yaml
approvals:
  pending_approval:
    bypass_when: { field: total_amount, operator: lte, value: 1000 }
    resolution:
      approved: approve
```

The audit log records the bypass: `transition_name: "approve"`, `metadata: { triggered_by: "approval_engine", bypassed: true, reason: "bypass_when condition met" }`.

### 10. Return for Rework

In addition to `approved` and `rejected`, the `resolution` mapping supports `returned` — a third outcome where the approver sends the record back for modifications without terminating the process.

```yaml
resolution:
  approved: approve        # all steps pass -> final approval
  rejected: reject         # hard rejection -> process terminated
  returned: rework         # return to author for changes -> process paused
```

The `returned` action appears as a third button alongside Approve and Reject in the approval panel UI.

### 11. Rework Policy

When a record goes through rework (returned to draft, then resubmitted), the `rework_policy` controls what happens to previous approval progress:

| `reset` value | Behavior |
|---|---|
| `all` (default) | All previous approvals are discarded. A new `ApprovalRequest` is created. Process starts from step 1. |
| `pending_only` | Completed steps keep their approval. Only pending/active steps reset. Useful for minor corrections. |
| `none` | Resume exactly where the process left off. No steps reset. The record re-enters the approval state and the next pending step activates. |

The old `ApprovalRequest` is marked `cancelled`. A new one is created with a reference to the previous (`previous_request_id`).

### 12. Global Resolution Rules (Parallel Strategy)

For parallel approval, additional rules control how the overall outcome is determined:

| Key | Values | Description |
|---|---|---|
| `on_reject` | `any` (default) / `all` | `any`: first rejection -> immediately rejected. `all`: wait for all steps, reject only if all reject. |
| `short_circuit` | `true` / `false` | When the outcome is already determined (e.g., quorum reached or rejection in `any` mode), cancel remaining pending tasks instead of waiting. |

Example: 3 parallel steps, `on_reject: any`, `short_circuit: true`. Step 2 rejects -> remaining pending tasks in steps 1 and 3 are cancelled -> request is rejected immediately.

### 13. Approval Lifecycle

```
Record enters approval state (on_entry event from state machine)
  |
  +- Evaluate bypass_when condition
  |    +- TRUE -> skip all steps -> trigger resolution.approved transition (system trigger)
  |
  +- Engine creates ApprovalRequest (status: pending)
  +- Engine evaluates step conditions (skips steps where condition is false)
  +- Engine creates ApprovalStep records (pending, active, or skipped)
  +- Engine resolves approvers for first active step(s)
  |    +- Empty? -> try fallback approvers -> still empty? -> step.status = error
  +- Engine creates ApprovalTask records (status: pending)
  |    +- assignment: claim? -> tasks visible but must be claimed first
  |
  |  +- Approver approves task -> task.status = approved
  |  |    +- Check: step.required met?
  |  |         +- YES -> step.status = completed
  |  |         |    +- Check: all steps completed?
  |  |         |         +- YES -> request.status = approved
  |  |         |         |    +- Trigger resolution.approved transition (system trigger)
  |  |         |         +- NO -> activate next step (sequential)
  |  |         |              or wait (parallel, check short_circuit)
  |  |         +- NO -> wait for more approvals
  |  |
  |  +- Approver rejects task -> task.status = rejected
  |  |    +- Check on_reject policy:
  |  |         +- on_reject: any -> request.status = rejected immediately
  |  |         +- on_reject: all -> wait for all steps, then evaluate
  |  |    +- short_circuit? -> cancel remaining pending tasks
  |  |    +- Trigger resolution.rejected transition (system trigger)
  |  |
  |  +- Approver returns task -> task.status = returned
  |  |    +- request.status = returned
  |  |         +- Trigger resolution.returned transition (system trigger)
  |  |              +- On resubmit: apply rework_policy.reset
  |  |
  |  +- Approver delegates -> task.status = delegated
  |  |    +- New task created for delegate
  |  |
  |  +- Approver claims task (assignment: claim)
  |       +- task.status = claimed, other tasks for same step -> cancelled
```

### 14. Integration with State Machine

The approval engine connects to the state machine exclusively through two mechanisms:

1. **Activation via `on_entry` event** — when a record enters a state that has an `approvals` definition, the approval engine activates. This uses the standard `Events::Dispatcher` from the state machine.

2. **Resolution via system triggers** — when an approval process completes, the engine triggers the mapped transition (`resolution.approved` -> `approve` transition, etc.) using `TransitionExecutor.execute` with `trigger: system`. The state machine handles the rest (set_fields, audit log, on_entry/on_exit of the new state).

This means the state machine does not import or depend on any approval code. The approval engine is a consumer of the state machine's public API.

### 15. Presenter Integration — Approval UI

When a record is in a state with an active approval process, the show page auto-renders an approval panel:

```
+- Approval Status ------------------------------------------------+
|                                                                    |
|  Step 1: Manager Review          [check] Completed                 |
|    Jan Novak - approved (Jan 15, 14:32)                            |
|                                                                    |
|  Step 2: Finance Review          [dot] Active                      |
|    Eva Svobodova - pending                                         |
|    Petr Malek - pending                                            |
|    [Approve]  [Return]  [Reject]  [Delegate]                       |
|                                                                    |
|  Step 3: Director Approval       [circle] Pending                  |
|    (will activate after step 2)                                    |
|                                                                    |
+--------------------------------------------------------------------+
```

The panel is auto-added to the show layout. It shows:

- Progress indicator (step 2 of 3).
- Each step with its approvers and their status.
- Action buttons for the current user (if they are an approver on the active step).
- Comment field (required for reject, optional for approve).
- Delegate button (if allowed).
- History of completed steps.

## Data Model

### Tables

Three tables for the approval engine, all polymorphic (work with any model that has a workflow with approvals). Auto-created by the engine via `SchemaManager` — no manual migrations. The workflow audit log table (`workflow_audit_logs`) is defined in [Workflow State Machine](workflow_state_machine.md#workflow-audit-log-table).

```
+--------------------------------------------------------------+
| <any model with workflow + approval>                          |
|  status: enum           <- current state (fast reads)         |
|  workflow_version: int  <- locked at record creation          |
+-------+------------------------------------------------------+
        | 1:N
+-------v------------------------------------------------------+
| workflow_approval_requests                                     |
+--------------------------------------------------------------+
|  record_type       string    (polymorphic)                    |
|  record_id         integer   (polymorphic)                    |
|  workflow_name     string                                     |
|  state_name        string    (the state with approval)        |
|  strategy          string    (sequential | parallel)          |
|  status            enum      (pending | approved |            |
|                               rejected | returned |           |
|                               cancelled)                      |
|  initiated_by_id   integer                                    |
|  previous_request_id integer (nullable, for rework chain)     |
|  created_at        datetime                                   |
|  resolved_at       datetime  (nullable)                       |
+--------------------------------------------------------------+
| PURPOSE: Tracks one approval process instance.                |
| One record can have multiple historical requests               |
| (submit -> return -> rework -> resubmit -> approve).          |
+-------+------------------------------------------------------+
        | 1:N
+-------v------------------------------------------------------+
| workflow_approval_steps                                        |
+--------------------------------------------------------------+
|  approval_request_id  integer  (FK)                           |
|  step_name            string                                  |
|  label                string                                  |
|  position             integer  (order in sequence)            |
|  status               enum     (pending | active |            |
|                                  completed | skipped |        |
|                                  error)                       |
|  required_approvals   integer  (how many must approve)        |
|  assignment           string   (all | claim | single)         |
|  activated_at         datetime (nullable)                     |
|  completed_at         datetime (nullable)                     |
+--------------------------------------------------------------+
| PURPOSE: Runtime instance of a step from the workflow          |
| definition. Tracks sequential progress ("step 2 of 3"),       |
| conditional skipping, and per-step timing for reporting.       |
+-------+------------------------------------------------------+
        | 1:N
+-------v------------------------------------------------------+
| workflow_approval_tasks                                        |
+--------------------------------------------------------------+
|  approval_step_id     integer  (FK)                           |
|  approver_id          integer                                 |
|  status               enum     (pending | claimed |           |
|                                  approved | rejected |        |
|                                  returned | delegated |       |
|                                  cancelled)                   |
|  delegated_from_id    integer  (nullable)                     |
|  comment              text     (nullable)                     |
|  created_at           datetime                                |
|  decided_at           datetime (nullable)                     |
+--------------------------------------------------------------+
| PURPOSE: One row per individual approver assignment.           |
| This is what the approver sees in their task list.             |
| Tracks individual decisions, delegation chains, and            |
| timing for bottleneck analysis.                                |
+--------------------------------------------------------------+
```

### Why Three Tables (Not JSON or Merged)

**Could `approval_steps` be a JSON column on `approval_requests`?**

A separate table enables efficient queries for reporting and monitoring:

```sql
-- Bottleneck: average time per step
SELECT step_name, AVG(completed_at - activated_at) AS avg_duration
FROM workflow_approval_steps
WHERE status = 'completed'
GROUP BY step_name ORDER BY avg_duration DESC

-- All requests stuck on a specific step
SELECT r.record_type, r.record_id
FROM workflow_approval_steps s
JOIN workflow_approval_requests r ON r.id = s.approval_request_id
WHERE s.step_name = 'finance_review' AND s.status = 'active'
```

**Could `approval_steps` be merged into `approval_tasks`?**

No — one step has N tasks (e.g., 5 committee members each get a task). The step tracks "3 of 5 approved, majority reached, step complete." Without the step record, `required_approvals` and `position` would repeat on every task row.

### Key Queries

```sql
-- Approver's inbox: "What's waiting for me?"
SELECT r.record_type, r.record_id, s.step_name, s.label
FROM workflow_approval_tasks t
JOIN workflow_approval_steps s ON s.id = t.approval_step_id
JOIN workflow_approval_requests r ON r.id = s.approval_request_id
WHERE t.approver_id = :current_user_id
  AND t.status = 'pending'
  AND r.status = 'pending'

-- Record show page: "Approval progress"
SELECT s.step_name, s.label, s.status, s.position,
       COUNT(t.id) AS total,
       COUNT(t.id) FILTER (WHERE t.status = 'approved') AS approved_count
FROM workflow_approval_steps s
LEFT JOIN workflow_approval_tasks t ON t.approval_step_id = s.id
WHERE s.approval_request_id = :request_id
GROUP BY s.id ORDER BY s.position

-- Audit trail: "Full approval history of this record"
SELECT r.status AS request_status, s.step_name, t.approver_id, t.status, t.comment, t.decided_at
FROM workflow_approval_requests r
JOIN workflow_approval_steps s ON s.approval_request_id = r.id
JOIN workflow_approval_tasks t ON t.approval_step_id = s.id
WHERE r.record_type = 'purchase_order' AND r.record_id = :id
ORDER BY r.created_at, s.position, t.created_at
```

## Three Definition Sources

Approval definitions follow the same three-source pattern as the state machine ([Workflow State Machine — Three Definition Sources](workflow_state_machine.md#three-definition-sources)).

### Contract

```ruby
# lib/lcp_ruby/workflow/approval_contract.rb
module LcpRuby
  module Workflow
    module ApprovalContract
      # @param workflow_name [String]
      # @param state_name [String]
      # @return [Hash, nil] approval definition
      def approval_for(workflow_name, state_name)
        raise NotImplementedError
      end

      # @param group_name [String]
      # @return [Hash, nil] group definition
      def approval_group(group_name)
        raise NotImplementedError
      end

      # @param step [Hash] step definition
      # @param record [ActiveRecord::Base]
      # @param current_user [Object]
      # @return [Array<Integer>] user IDs
      def resolve_approvers(step:, record:, current_user:)
        raise NotImplementedError
      end
    end
  end
end
```

### Static Source

Reads the `approvals` section from workflow YAML/DSL files and `approval_groups.yml`. Implements both `StateMachineContract` and `ApprovalContract`.

### Model Source

Configuration:

```ruby
LcpRuby.configure do |c|
  c.approval_source = nil         # nil = follows workflow_source
  c.approval_model = "approval_definition"
  c.approval_model_fields = {
    workflow_name: "workflow_name", state_name: "state_name",
    strategy: "strategy", resolution: "resolution",
    steps: "steps", active: "active"
  }
end
```

### Host Source

The host provider class can implement `ApprovalContract` alongside `StateMachineContract`:

```ruby
class WorkflowProvider
  include LcpRuby::Workflow::StateMachineContract
  include LcpRuby::Workflow::ApprovalContract

  def resolve_approvers(step:, record:, current_user:)
    # Call org chart API, LDAP, etc.
    OrgChartService.managers_for(current_user, levels: step.dig(:approvers, :levels_up))
  end
end
```

## General Implementation Approach

### Implementation Structure

```
lib/lcp_ruby/workflow/approval/
  engine.rb                 # Creates requests/steps/tasks, evaluates completion
  approver_resolver.rb      # Resolves user IDs: role/field/group/hierarchy/service
  task_manager.rb           # CRUD operations on approval task records
  step_evaluator.rb         # Checks step completion, activates next step
```

These are additions to the workflow module structure defined in [Workflow State Machine](workflow_state_machine.md#implementation-structure).

### Reused Modules

| Approval need | Module |
|---|---|
| Step condition evaluation | `ConditionEvaluator` (from [Advanced Conditions](advanced_conditions.md)) |
| Bypass condition | `ConditionEvaluator` |
| Triggering state transitions | `Workflow::TransitionExecutor` (from [Workflow State Machine](workflow_state_machine.md)) with `trigger: system` |
| Audit logging | `workflow_audit_logs` table (from [Workflow State Machine](workflow_state_machine.md)) — transitions triggered by approval engine include `metadata: { triggered_by: "approval_engine", step: "..." }` |
| User snapshot | `LcpRuby::UserSnapshot` (from [Auditing](auditing.md)) |
| Group membership | `Groups` subsystem (existing) — approval groups can reference platform groups |
| Table creation | `SchemaManager` |

## Usage Examples

### Complete Purchase Order with Approval

Building on the [Workflow State Machine example](workflow_state_machine.md#complete-purchase-order-example), add the approval definition:

```ruby
define_workflow :purchase_order_workflow do
  model :purchase_order
  field :status
  version 1

  # States and transitions from state machine doc...
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
    label: "Return to Draft", icon: "rotate-ccw", roles: [:author, :admin],
    trigger: :system

  transition :force_approve, from: :pending_approval, to: :approved,
    label: "Force Approve", icon: "shield", roles: [:admin], require_comment: true

  # Approval engine configuration
  approval :pending_approval do
    strategy :sequential
    resolution approved: :approve, rejected: :reject, returned: :rework
    bypass_when field: :total_amount, operator: :lte, value: 1000
    rework_policy reset: :all

    step :manager_review, label: "Manager Review" do
      approvers type: :role, role: :manager
      assignment :all
      fallback type: :role, role: :hr_manager
    end

    step :finance_review, label: "Finance Review" do
      approvers type: :group, group: :finance_team
      assignment :claim
      condition field: :total_amount, operator: :gt, value: 50000
    end
  end
end
```

### What Happens at Runtime

1. User creates PO (status: `draft`, workflow_version: `1`).
2. User clicks "Submit" -> state machine checks guard, executes transition -> status becomes `pending_approval`, `on_entry: notify_approvers` fires.
3. **Approval engine activates.** Checks `bypass_when` (total_amount <= 1000?):
   - **Yes**: skip all steps -> trigger `approve` transition via system trigger -> status becomes `approved`. Audit log: `metadata: { triggered_by: "approval_engine", bypassed: true }`.
   - **No**: create `ApprovalRequest`, evaluate step conditions, create `ApprovalStep` records.
4. Step 1 (manager) activates -> resolve approvers with role `manager` -> empty? falls back to `hr_manager` -> create tasks.
5. Step 2 (finance, `assignment: claim`) condition: total_amount > 50,000? If no, step is pre-marked `skipped`.
6. Manager approves -> task marked `approved` -> step 1 complete -> step 2 activates (or skipped) -> all steps complete -> `resolution.approved` triggers `approve` transition via system trigger -> status becomes `approved`, `readonly_fields: all` locks the record.
7. **Alternative — rejection**: Manager rejects -> task marked `rejected` -> request marked `rejected` -> triggers `reject` transition via system trigger -> status becomes `rejected`.
8. **Alternative — rework**: Manager clicks "Return" -> task marked `returned` -> request marked `returned` -> triggers `rework` transition via system trigger -> status becomes `draft`. Author edits and resubmits -> `rework_policy.reset: all` -> new ApprovalRequest created, process restarts from step 1.
9. All transitions are recorded in `workflow_audit_logs` (from state machine). Approval-triggered transitions include `metadata: { triggered_by: "approval_engine", step: "manager_review" }`.
10. Data audit log (if `auditing: true`) independently records field-level changes.

## Decisions

1. **Approval engine connects to state machine only through `on_entry` events and system triggers.** No direct coupling. The state machine does not import approval code.

2. **Three separate tables for approval data.** Requests, steps, and tasks are normalized for efficient querying and reporting (see [Why Three Tables](#why-three-tables-not-json-or-merged)).

3. **`resolution` maps approval outcomes to existing transition names.** The approval engine does not define its own state changes — it triggers transitions already defined in the state machine.

4. **Step conditions use `ConditionEvaluator`.** Same condition syntax as guards, `visible_when`, `record_rules`. No custom condition logic.

5. **`rework_policy.reset: all` is the default.** The safest option — a reworked record goes through the full approval process again. `pending_only` and `none` are available for less strict processes.

6. **Approval groups are separate from platform groups.** Approval groups (`approval_groups.yml`) are purpose-built for approver resolution. They can reference platform groups via `type: scope`, but they are a separate concept with different semantics.

## Deferred Items

### Deferred to Phase 3 (Notifications & Time)

- **SLA triggers on states and steps** — requires a scheduled job runner to check deadlines. The `sla` key on states and steps is accepted in the schema but has no effect until the scheduler is implemented.
- **Step-level timeout and escalation** — `timeout_days`, `escalation.after`, `escalation.to` on steps. Requires the same scheduler infrastructure.
- **Reminder notifications** — periodic reminders to approvers with pending tasks.

### Deferred to Future Iterations

- **Approval decision payload schema** — structured data capture during approval (reason enum, amount limit, attachment). Currently only `comment` (free text) is supported. Future: `decision_fields` array on steps with type/validation.
- **Sub-approval modules** — parallel approval branches with different rules that join before resolution. Current parallel steps within a single approval cover most cases.
- **Re-approval on material change** — detecting that a field changed after approval and automatically resetting the approval. Requires field-level change tracking and "material change" definition. Workaround: use `rework_policy.reset: all` and require manual resubmission.
- **Visual workflow editor** — drag-and-drop UI for designing workflows. Requires significant frontend investment.

## Open Questions

1. **Should the approval panel be a view slot or a fixed section?** Using the existing `ViewSlots` system would make it more flexible (host app can move or replace it). But auto-injection as a fixed section is simpler. Recommendation: view slot with a default position.

2. **Should approval task notifications be built-in or left to event handlers?** The `on_entry` event fires when the state changes, but individual task creation (e.g., "you have a new approval task") is approval-internal. Options: built-in notification hooks on task creation, or a generic `approval_task_created` event that handlers can subscribe to. Recommendation: fire events, let handlers decide.

3. **Should the approver inbox be a dedicated presenter or a generic query?** A presenter for "My Pending Approvals" across all models would be very useful but requires cross-model querying. Recommendation: a built-in query method + optional presenter template that host apps can include.
