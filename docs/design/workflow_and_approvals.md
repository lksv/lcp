# Workflow & Approval Process — Design Document

## Overview

This document describes the design for adding workflow (state machine) and approval
process capabilities to LCP Ruby. The goal is a metadata-driven system where
workflows are defined declaratively (YAML, DSL, DB records, or host application
code) and the engine interprets them at runtime — consistent with the platform's
low-code philosophy.

### Design Principles

1. **Metadata-driven** — workflows defined in YAML/DSL, not hardcoded in Ruby model classes.
2. **Three definition sources** — static files, DB records, or host-implemented contract (same pattern as roles and custom fields).
3. **Reuse existing building blocks** — ConditionEvaluator, Events::Dispatcher, PermissionEvaluator, ActionExecutor.
4. **Custom implementation** — no external state machine gems (AASM, Statesman). They assume code-level DSL definitions, incompatible with runtime metadata sources.
5. **Separation of concerns** — model defines data (enum field), workflow defines behavior (transitions), presenter defines UI (action buttons).

### Scope

| In scope | Out of scope (for now) |
|---|---|
| State machine (states, transitions, guards) | Notifications & communication |
| Approval engine (steps, strategies, delegation) | SLA triggers & scheduled escalation |
| Audit log | Visual workflow editor |
| Compound conditions (AND/OR/NOT) | Sub-workflows / nested processes |
| Related entity references in conditions | Workflow templates / presets |
| Three definition sources (static, model, host) | Approval decision payload schema |
| State-level hooks (on_entry/on_exit) and field locking | Re-approval on material change detection |
| Rework policy, auto-approval bypass, task assignment modes | |

---

## 1. State Machine

### 1.1 Relationship to Model

The model defines an `enum` field with possible values (states). The workflow adds
behavioral rules on top — which transitions are allowed, under what conditions, with
what side effects. The model stays clean:

```yaml
# Model — data structure only
field :stage, :enum, values: { draft: "Draft", submitted: "Submitted", approved: "Approved" }

# Workflow — behavioral rules (separate file)
workflow:
  field: stage  # references the model's enum
  transitions:
    submit:
      from: draft
      to: submitted
```

When a workflow is active on a model, direct enum updates are blocked — the record
can only change state through defined transitions.

### 1.2 Configuration — YAML Format

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
      readonly_fields: [title, total_amount, department_id]   # locked while approving
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
      guard:                        # compound condition (see section 4)
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
      roles: [admin]               # manual trigger by admin (approval engine also triggers this)
      trigger: approval_approved   # or null for user-triggered only
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
      trigger: approval_rejected
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

### 1.3 Configuration — DSL Format

```ruby
# config/lcp_ruby/workflows/purchase_order.rb
define_workflow :purchase_order_workflow do
  model :purchase_order
  field :status
  version 1
  audit_log true

  state :draft, initial: true, category: :draft, color: "gray", icon: "file-text"
  state :pending_approval, category: :waiting, color: "blue", icon: "clock"
  state :approved, category: :terminal, color: "green", icon: "check-circle"
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
    trigger: :approval_approved do
    set_fields approved_at: :now
  end

  transition :reject, from: :pending_approval, to: :rejected,
    label: "Reject", icon: "x", style: :danger, roles: [:admin],
    trigger: :approval_rejected, require_comment: true do
    set_fields rejected_at: :now
  end

  transition :rework, from: :rejected, to: :draft,
    label: "Return to Draft", icon: "rotate-ccw", roles: [:author, :admin]

  transition :force_approve, from: :pending_approval, to: :approved,
    label: "Force Approve", icon: "shield", roles: [:admin], require_comment: true
end
```

### 1.4 Transition Reference

| Key | Type | Required | Description |
|---|---|---|---|
| `from` | String or Array | yes | Source state(s) |
| `to` | String | yes | Target state |
| `label` | String | yes | Button label in UI |
| `icon` | String | no | Icon name |
| `style` | String | no | `default` / `primary` / `success` / `danger` |
| `roles` | Array | no | Roles allowed to trigger (intersected with permission system) |
| `guard` | Hash | no | Condition (simple or compound) that must be true |
| `actions.set_fields` | Hash | no | Field values to auto-set on transition |
| `events` | Array | no | Named events to fire after transition |
| `require_comment` | Boolean | no | Mandatory comment input (default: false) |
| `confirm` | Boolean | no | Show confirmation dialog (default: false) |
| `confirm_message` | String | no | Custom confirmation text |
| `trigger` | String | no | `null` = user-triggered, `approval_approved` / `approval_rejected` = auto-triggered by approval engine |

### 1.5 Set Fields — Value Expressions

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

### 1.6 State-Level Behavior

States can define behavior that applies regardless of which transition brought the
record there.

#### Entry/Exit Hooks

`on_entry` and `on_exit` fire named events when a record enters or leaves a state.
Unlike transition-level `events` (which fire for a specific transition), these fire
for ANY transition that leads to/from this state. Uses existing `Events::Dispatcher`.

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

Execution order for a transition `draft → pending_approval`:
1. Guard evaluated
2. `set_fields` applied
3. Record saved (state updated)
4. Audit log written
5. `on_exit` events for `draft` (if any)
6. `on_entry` events for `pending_approval`
7. Transition-level `events`

#### Readonly Fields per State

`readonly_fields` makes fields non-writable while the record is in a given state.
Integrates with existing `PermissionEvaluator` — the fields become non-writable for
all roles except those in the transition's `roles` list during transition execution.

```yaml
states:
  pending_approval:
    readonly_fields: [title, total_amount, department_id]

  approved:
    readonly_fields: all            # all fields locked
```

This replaces the need to manually write `record_rules` for each state. The engine
generates the equivalent permission restrictions automatically. Admin override
remains possible via `force_approve` transition or similar.

In the presenter, readonly fields render with disabled styling (same as existing
`disable_when` behavior). On the server side, the controller's `permitted_params`
filters them out.

### 1.7 Versioning and Definition Freeze

Each record stores the workflow version it was created with (in a `workflow_version`
integer field, auto-added by the engine). When the workflow definition changes:

- New records use the new version.
- Existing records continue using their stored version.
- The engine loads all active versions and applies the correct one per record.
- Old versions can be marked `deprecated: true` to prevent new records from using them.

**Definition freeze per instance**: The workflow engine always resolves the definition
matching the record's `workflow_version`. This means:

- A running approval process uses the step definitions from the version the record
  started with — even if the current version has different steps.
- The audit log stores `workflow_version` on every entry, so the audit trail is
  fully reproducible: "transition T was allowed because guard G passed in definition
  version V."
- When `workflow_source == :model` (DB-stored definitions), the `Registry` must
  be able to load specific versions, not just the latest. The DB model should store
  all versions (not overwrite in place).

### 1.8 Presenter Integration

Transitions auto-generate action buttons in the presenter. The presenter can
customize appearance or suppress individual transitions:

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

### 1.9 Permission Integration

Transition `roles` work alongside the existing permission system. A user must have
BOTH the transition role AND `update` CRUD permission. Existing `record_rules` also
apply — if a record rule denies `update`, no transitions are possible.

No duplication needed between permissions YAML and workflow YAML. Permissions control
field-level and CRUD access; workflows control state transitions.

---

## 2. Approval Engine

The approval engine is an optional layer on top of the state machine. It manages
multi-step approval routing for specific workflow states. Without it, transitions
are simple role-guarded actions.

### 2.1 Configuration — YAML

Approvals are defined inside the workflow file, in a separate `approvals` section
keyed by the state where the approval process runs:

```yaml
# Inside config/lcp_ruby/workflows/purchase_order.yml, after transitions:
  approvals:
    pending_approval:                    # approval runs while record is in this state
      strategy: sequential               # sequential | parallel

      # Condition to bypass the entire approval process.
      # If true, skip all steps and immediately trigger the "approved" transition.
      # If absent or false, normal approval flow runs.
      bypass_when:                       # auto-approval for trivial cases
        field: total_amount
        operator: lte
        value: 1000

      resolution:
        approved: approve                # all steps pass → trigger "approve" transition
        rejected: reject                 # any step rejects → trigger "reject" transition
        returned: rework                 # approver returns for rework → trigger "rework" transition

      # Global resolution rules for parallel strategy:
      on_reject: any                     # any | all — reject on first rejection vs. wait for all
      short_circuit: true                # when outcome is determined, cancel remaining pending tasks

      # What happens to approval progress when record returns to draft and is resubmitted:
      rework_policy:
        reset: all                       # all | pending_only | none
                                         #   all: discard all approvals, start from step 1
                                         #   pending_only: keep completed steps, reset pending
                                         #   none: resume where left off (no reset)

      steps:
        - name: manager_review
          label: "Manager Review"
          approvers:
            type: role                   # role | field | group | hierarchy | service
            role: manager
          required: 1                    # how many must approve (default: 1)
          assignment: all                # all | claim | single (see section 2.7)
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

### 2.2 Configuration — DSL

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

### 2.3 Approver Resolution Types

| Type | Config | Resolves to |
|---|---|---|
| `role` | `role: manager` | All users with this role |
| `field` | `field: "department.manager_id"` | User ID from record field (dot-path supported) |
| `group` | `group: finance_team` | Members of a named approval group |
| `hierarchy` | `levels_up: 2` | N levels above record author in org hierarchy |
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

### 2.4 Approval Strategies

**Sequential** — steps execute one after another. Step 2 does not start until step 1
resolves.

```
submit → [step 1: manager] → [step 2: finance] → [step 3: director] → approved
                                    ↓ (reject at any step)
                                 rejected
```

Conditional steps are evaluated when their turn comes. If the condition is false, the
step is marked `skipped` and the next step activates.

**Parallel** — all steps start simultaneously. Each step has its own `required`
count.

```
submit → [step 1: manager (1/1)]   ─┐
         [step 2: finance (1/3)]   ─┼→ all resolved → approved
         [step 3: director (1/1)]  ─┘
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

### 2.5 Approval Groups

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
# config/lcp_ruby/approval_groups.rb
define_approval_group :finance_team do
  label "Finance Team"
  members type: :role, role: :finance_reviewer
end

define_approval_group :review_committee do
  label "Review Committee"
  members type: :scope, model: :user, scope: :review_committee_members
end
```

### 2.6 Delegation

When `allow_delegation: true`, an approver can delegate their task to another user.
Delegation creates a new task for the delegate and marks the original as `delegated`.

| Config key | Type | Description |
|---|---|---|
| `allow_delegation` | Boolean | Enable delegation (default: false) |
| `delegation_roles` | Array | Restrict who can be delegated to (optional) |
| `max_delegation_depth` | Integer | Prevent infinite chains (default: 1) |

### 2.7 Task Assignment Modes

When a step has multiple potential approvers (e.g., a group of 10 people), the
`assignment` mode controls how tasks are distributed:

| Mode | Behavior |
|---|---|
| `all` (default) | All resolved approvers receive a task. Any `required` of them can approve. Tasks stay open until `required` count is met. |
| `claim` | All resolved approvers see the task in their inbox, but one must **claim** it before deciding. After claim, others can no longer act on it. Prevents duplicate work in large pools. |
| `single` | The resolver returns exactly one person (or the engine picks the first). Only that person gets a task. Useful with `type: field` or `type: hierarchy`. |

In the `claim` model, the `workflow_approval_tasks` table tracks:
- `status: pending` → visible in inbox, not yet claimed.
- `status: claimed` → claimed by this approver, others' tasks move to `cancelled`.
- `status: approved` / `rejected` → decision made.

### 2.8 Fallback Approvers

When the primary approver resolver returns an empty list (e.g., no user has the
`manager` role, or the `department.manager_id` field is null), the step would be
stuck forever. The `fallback` key provides an alternative:

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

Resolution order: primary approvers → fallback → error (if both empty, the step
is marked `error` and the approval request moves to a `stuck` status, visible in
admin monitoring).

### 2.9 Auto-Approval Bypass

When `bypass_when` is defined on an approval and the condition evaluates to true
at the moment the record enters the approval state, the entire approval process
is skipped. The engine immediately triggers the `resolution.approved` transition.

```yaml
approvals:
  pending_approval:
    bypass_when: { field: total_amount, operator: lte, value: 1000 }
    resolution:
      approved: approve
```

This avoids creating dummy approval steps for trivial cases. The audit log records
the bypass: `transition_name: "approve"`, `metadata: { bypassed: true, reason: "bypass_when condition met" }`.

### 2.10 Return for Rework

In addition to `approved` and `rejected`, the `resolution` mapping supports
`returned` — a third outcome where the approver sends the record back for
modifications without terminating the process.

```yaml
resolution:
  approved: approve        # all steps pass → final approval
  rejected: reject         # hard rejection → process terminated
  returned: rework         # return to author for changes → process paused
```

The `returned` action appears as a third button alongside Approve and Reject in
the approval panel UI.

### 2.11 Rework Policy

When a record goes through rework (returned to draft, then resubmitted), the
`rework_policy` controls what happens to previous approval progress:

| `reset` value | Behavior |
|---|---|
| `all` (default) | All previous approvals are discarded. A new `ApprovalRequest` is created. Process starts from step 1. |
| `pending_only` | Completed steps keep their approval. Only pending/active steps reset. Useful for minor corrections. |
| `none` | Resume exactly where the process left off. No steps reset. The record re-enters the approval state and the next pending step activates. |

```yaml
rework_policy:
  reset: all
```

The old `ApprovalRequest` is marked `cancelled`. A new one is created with a
reference to the previous (`previous_request_id`).

### 2.12 Global Resolution Rules (Parallel Strategy)

For parallel approval, additional rules control how the overall outcome is
determined:

| Key | Values | Description |
|---|---|---|
| `on_reject` | `any` (default) / `all` | `any`: first rejection → immediately rejected. `all`: wait for all steps, reject only if all reject. |
| `short_circuit` | `true` / `false` | When the outcome is already determined (e.g., quorum reached or rejection in `any` mode), cancel remaining pending tasks instead of waiting. |

```yaml
approvals:
  pending_approval:
    strategy: parallel
    on_reject: any
    short_circuit: true
```

Example: 3 parallel steps, `on_reject: any`, `short_circuit: true`. Step 2 rejects
→ remaining pending tasks in steps 1 and 3 are cancelled → request is rejected
immediately.

### 2.13 Approval Lifecycle

```
Record enters approval state
  │
  ├─ Evaluate bypass_when condition
  │    └─ TRUE → skip all steps → trigger resolution.approved transition
  │
  ├─ Engine creates ApprovalRequest (status: pending)
  ├─ Engine evaluates step conditions (skips steps where condition is false)
  ├─ Engine creates ApprovalStep records (pending, active, or skipped)
  ├─ Engine resolves approvers for first active step(s)
  │    └─ Empty? → try fallback approvers → still empty? → step.status = error
  ├─ Engine creates ApprovalTask records (status: pending)
  │    └─ assignment: claim? → tasks visible but must be claimed first
  │
  │  ┌─ Approver approves task → task.status = approved
  │  │    └─ Check: step.required met?
  │  │         ├─ YES → step.status = completed
  │  │         │    └─ Check: all steps completed?
  │  │         │         ├─ YES → request.status = approved
  │  │         │         │    └─ Trigger resolution.approved transition
  │  │         │         └─ NO → activate next step (sequential)
  │  │         │              or wait (parallel, check short_circuit)
  │  │         └─ NO → wait for more approvals
  │  │
  │  ├─ Approver rejects task → task.status = rejected
  │  │    └─ Check on_reject policy:
  │  │         ├─ on_reject: any → request.status = rejected immediately
  │  │         └─ on_reject: all → wait for all steps, then evaluate
  │  │    └─ short_circuit? → cancel remaining pending tasks
  │  │    └─ Trigger resolution.rejected transition
  │  │
  │  ├─ Approver returns task → task.status = returned
  │  │    └─ request.status = returned
  │  │         └─ Trigger resolution.returned transition (rework)
  │  │              └─ On resubmit: apply rework_policy.reset
  │  │
  │  ├─ Approver delegates → task.status = delegated
  │  │    └─ New task created for delegate
  │  │
  │  └─ Approver claims task (assignment: claim)
  │       └─ task.status = claimed, other tasks for same step → cancelled
  │
```

### 2.14 Presenter Integration — Approval UI

When a record is in a state with an active approval process, the show page
auto-renders an approval panel:

```
┌─ Approval Status ──────────────────────────────────────────┐
│                                                            │
│  Step 1: Manager Review          ✓ Completed               │
│    Jan Novak — approved (Jan 15, 14:32)                    │
│                                                            │
│  Step 2: Finance Review          ● Active                  │
│    Eva Svobodova — pending                                 │
│    Petr Malek — pending                                    │
│    [Approve]  [Return]  [Reject]  [Delegate]                │
│                                                            │
│  Step 3: Director Approval       ○ Pending                 │
│    (will activate after step 2)                            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

The panel is auto-added to the show layout. It shows:

- Progress indicator (step 2 of 3).
- Each step with its approvers and their status.
- Action buttons for the current user (if they are an approver on the active step).
- Comment field (required for reject, optional for approve).
- Delegate button (if allowed).
- History of completed steps.

---

## 3. Data Model

### 3.1 Tables

Four tables, all polymorphic (work with any model that has a workflow).
Auto-created by the engine via `SchemaManager` — no manual migrations.

```
┌──────────────────────────────────────────────────────────┐
│ <any model with workflow>                                │
│  stage: enum           ← current state (fast reads)      │
│  workflow_version: int ← locked at record creation       │
└───────┬──────────────────────────────────────────────────┘
        │ 1:N
┌───────▼──────────────────────────────────────────────────┐
│ workflow_audit_logs                                       │
├──────────────────────────────────────────────────────────┤
│  record_type      string    (polymorphic)                │
│  record_id        integer   (polymorphic)                │
│  workflow_name    string                                 │
│  workflow_version integer                                │
│  transition_name  string                                 │
│  from_state       string                                 │
│  to_state         string                                 │
│  user_id          integer                                │
│  comment          text      (nullable)                   │
│  metadata         json      (guard eval result, etc.)    │
│  created_at       datetime                               │
├──────────────────────────────────────────────────────────┤
│ PURPOSE: Immutable history of every state transition.    │
│ Answers: "Who moved it, when, from where to where, why." │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ workflow_approval_requests                                │
├──────────────────────────────────────────────────────────┤
│  record_type      string    (polymorphic)                │
│  record_id        integer   (polymorphic)                │
│  workflow_name    string                                 │
│  state_name       string    (the state with approval)    │
│  strategy         string    (sequential | parallel)      │
│  status           enum      (pending | approved |        │
│                              rejected | returned |       │
│                              cancelled)                  │
│  initiated_by_id  integer                                │
│  previous_request_id integer (nullable, for rework chain)│
│  created_at       datetime                               │
│  resolved_at      datetime  (nullable)                   │
├──────────────────────────────────────────────────────────┤
│ PURPOSE: Tracks one approval process instance.           │
│ One record can have multiple historical requests          │
│ (submit → return → rework → resubmit → approve).        │
└───────┬──────────────────────────────────────────────────┘
        │ 1:N
┌───────▼──────────────────────────────────────────────────┐
│ workflow_approval_steps                                   │
├──────────────────────────────────────────────────────────┤
│  approval_request_id  integer  (FK)                      │
│  step_name            string                             │
│  label                string                             │
│  position             integer  (order in sequence)       │
│  status               enum     (pending | active |       │
│                                 completed | skipped |    │
│                                 error)                   │
│  required_approvals   integer  (how many must approve)   │
│  assignment           string   (all | claim | single)    │
│  activated_at         datetime (nullable)                │
│  completed_at         datetime (nullable)                │
├──────────────────────────────────────────────────────────┤
│ PURPOSE: Runtime instance of a step from the workflow    │
│ definition. Tracks sequential progress ("step 2 of 3"), │
│ conditional skipping, and per-step timing for reporting. │
└───────┬──────────────────────────────────────────────────┘
        │ 1:N
┌───────▼──────────────────────────────────────────────────┐
│ workflow_approval_tasks                                   │
├──────────────────────────────────────────────────────────┤
│  approval_step_id     integer  (FK)                      │
│  approver_id          integer                            │
│  status               enum     (pending | claimed |      │
│                                 approved | rejected |    │
│                                 returned | delegated |   │
│                                 cancelled)               │
│  delegated_from_id    integer  (nullable)                │
│  comment              text     (nullable)                │
│  created_at           datetime                           │
│  decided_at           datetime (nullable)                │
├──────────────────────────────────────────────────────────┤
│ PURPOSE: One row per individual approver assignment.     │
│ This is what the approver sees in their task list.       │
│ Tracks individual decisions, delegation chains, and      │
│ timing for bottleneck analysis.                          │
└──────────────────────────────────────────────────────────┘
```

### 3.2 Why Four Tables

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

No — one step has N tasks (e.g., 5 committee members each get a task). The step
tracks "3 of 5 approved, majority reached, step complete." Without the step record,
`required_approvals` and `position` would repeat on every task row.

### 3.3 Key Queries

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

-- Audit trail: "Full history of this record"
SELECT transition_name, from_state, to_state, user_id, comment, created_at
FROM workflow_audit_logs
WHERE record_type = 'purchase_order' AND record_id = :id
ORDER BY created_at
```

---

## 4. Rule Engine Enhancement

The workflow guard conditions need compound expressions and related entity references.
These improvements apply to all conditions in the platform (not just workflows):
`visible_when`, `disable_when`, `record_rules`, validation `when`, event `condition`.

### 4.1 Compound Conditions

Current syntax (single condition) remains valid and backward-compatible:

```yaml
guard: { field: title, operator: present }
```

New compound syntax adds `all` (AND), `any` (OR), `not` (NOT):

```yaml
# AND — all must be true
guard:
  all:
    - { field: title, operator: present }
    - { field: total_amount, operator: gt, value: 0 }

# OR — at least one must be true
guard:
  any:
    - { field: role, operator: eq, value: admin }
    - { field: stage, operator: eq, value: draft }

# NOT — inverts the result
guard:
  not: { field: stage, operator: eq, value: closed }

# Nested — arbitrary depth
guard:
  all:
    - { field: title, operator: present }
    - any:
      - { field: total_amount, operator: gt, value: 100000 }
      - all:
        - { field: priority, operator: eq, value: high }
        - { field: "company.industry", operator: eq, value: finance }
    - not: { field: stage, operator: in, value: [closed_won, closed_lost] }
```

Applies everywhere conditions are used:

| Location | Example |
|---|---|
| `visible_when` | `visible_when: { all: [...] }` |
| `disable_when` | `disable_when: { any: [...] }` |
| `record_rules.condition` | `condition: { all: [...] }` |
| `validation.when` | `when: { all: [...] }` |
| `event.condition` | `condition: { not: {...} }` |
| `transition.guard` | `guard: { all: [...] }` |
| `approval step.condition` | `condition: { any: [...] }` |

**Client-side evaluation**: `all`, `any`, `not` with field-value-only conditions
remain client-evaluable (JavaScript). Mixed conditions containing `service` or
dot-path references fall back to server-side AJAX.

### 4.2 Related Entity References in Conditions

The platform already supports dot-path for display (`company.name` in table columns).
Extending to conditions:

```yaml
guard:
  all:
    - { field: "company.industry", operator: eq, value: finance }
    - { field: "contact.active", operator: eq, value: true }
    - { field: "company.country.code", operator: in, value: ["CZ", "SK"] }
```

Dot-path conditions require server-side evaluation (database JOIN or eager-loaded
association). They cannot be client-evaluated.

| Condition type | Client-evaluable? |
|---|---|
| `{ field: stage, ... }` | Yes (instant) |
| `{ field: "company.name", ... }` | No (AJAX) |
| `{ service: custom_check }` | No (AJAX) |
| `{ all: [field-only...] }` | Yes (instant) |
| `{ all: [field + dot-path mix] }` | No (AJAX) |

### 4.3 Dynamic Value References

Beyond literal values, conditions support dynamic references:

```yaml
# Compare field to current user
guard:
  field: author_id
  operator: eq
  value: { ref: current_user.id }

# Compare field to another field
guard:
  field: approved_amount
  operator: lte
  value: { ref: field.budget_limit }

# Compare field to today
guard:
  field: deadline
  operator: gte
  value: { ref: today }
```

| Reference | Resolves to |
|---|---|
| `{ ref: current_user.id }` | Authenticated user's ID |
| `{ ref: current_user.role }` | Authenticated user's role |
| `{ ref: field.other_field }` | Value of another field on the record |
| `{ ref: today }` | `Date.current` |
| `{ ref: now }` | `Time.current` |

---

## 5. Three Definition Sources

Both state machine and approval definitions support three interchangeable sources.
All three satisfy the same contract — the engine doesn't care where definitions
come from.

```
┌────────────────────────────────────────────┐
│           Workflow::Resolver               │
│  (merges definitions from active sources)  │
│  priority: static > model > host           │
└──────┬─────────┬─────────────┬─────────────┘
       │         │             │
  ┌────▼───┐ ┌──▼─────┐ ┌────▼────┐
  │ Static │ │ Model  │ │  Host   │
  │ (YAML/ │ │ (DB    │ │ (Ruby   │
  │  DSL)  │ │ table) │ │  class) │
  └────────┘ └────────┘ └─────────┘
```

### 5.1 Contract

The contract defines what data shape any source must provide. Both
`StateMachineContract` and `ApprovalContract` are Ruby modules with required method
signatures.

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

### 5.2 Source: Static (YAML / DSL)

Definitions in `config/lcp_ruby/workflows/*.yml` or `.rb`, loaded at boot.
Always active if workflow files exist.

```ruby
class StaticSource
  include StateMachineContract
  include ApprovalContract

  def initialize(loader)
    @definitions = loader.workflow_definitions
  end

  def workflows_for(model_name)
    @definitions.values.select { |d| d[:model] == model_name.to_s }
  end

  def workflow_by_name(name)
    @definitions[name.to_s]
  end

  # ...
end
```

### 5.3 Source: Model (DB Table)

Same pattern as Custom Fields and Roles: a DB model stores workflow definitions
as records. Validated at boot via `ContractValidator`.

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

**Registry** — thread-safe cache with `Monitor`, same pattern as `Roles::Registry`:

```ruby
class Registry
  class << self
    def for_model(model_name)
      return [] unless available?
      monitor.synchronize { @cache[model_name] ||= load_for_model(model_name) }
    end

    def reload!(model_name = nil)  # called by ChangeHandler
    def clear!                      # called by LcpRuby.reset!
    def available?
    def mark_available!             # called by Setup after contract validation
  end
end
```

**ChangeHandler** — installed on the DB model, invalidates cache on `after_commit`:

```ruby
class ChangeHandler
  def self.install!(model_class)
    model_class.after_commit do |record|
      Registry.reload!(record.model_name)
    end
  end
end
```

### 5.4 Source: Host (Application Contract)

The host application provides a Ruby class implementing the contract methods.
For complex routing logic that can't be expressed in YAML or DB records.

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
  include LcpRuby::Workflow::ApprovalContract

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

  def resolve_approvers(step:, record:, current_user:)
    # Call org chart API, LDAP, etc.
    OrgChartService.managers_for(current_user, levels: step.dig(:approvers, :levels_up))
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
      transitions: { "submit" => { from: "draft", to: "pending", ... }, ... },
      approvals: { "pending" => { strategy: "sequential", steps: [...] } }
    }
  end
end
```

**Contract validation at boot** — checks that the host class responds to required
methods:

```ruby
def self.validate_host_provider(klass)
  errors = []
  %i[workflows_for workflow_by_name].each do |method|
    unless klass.method_defined?(method) || klass.respond_to?(method)
      errors << "Host provider '#{klass}' must implement ##{method}"
    end
  end
  Metadata::ContractResult.new(errors: errors, warnings: [])
end
```

### 5.5 Resolver (Merges Sources)

The Resolver aggregates definitions from all active sources. Priority on name
conflicts: static > model > host.

```ruby
class Resolver
  class << self
    def configure!(sources)
      @sources = sources
    end

    def workflows_for(model_name)
      seen = Set.new
      @sources.flat_map { |s| s.workflows_for(model_name) }
              .reject { |wf| !seen.add?(wf[:name]) }
    end

    def workflow_by_name(name)
      @sources.each { |s| (wf = s.workflow_by_name(name)) && (return wf) }
      nil
    end
  end
end
```

### 5.6 Configuration Reference

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

  # Approval source (defaults to same as workflow_source)
  c.approval_source = nil         # nil = follows workflow_source
  c.approval_model = "approval_definition"
  c.approval_model_fields = {
    workflow_name: "workflow_name", state_name: "state_name",
    strategy: "strategy", resolution: "resolution",
    steps: "steps", active: "active"
  }
end
```

### 5.7 Boot Sequence

```ruby
# In Engine.load_metadata!, after existing setup:
CustomFields::Setup.apply!(loader)
Roles::Setup.apply!(loader)
Workflow::Setup.apply!(loader)     # ← new, runs after roles
```

`Workflow::Setup.apply!` does:

1. Collect static source (if workflow YAML/DSL files exist).
2. If `workflow_source == :model`: find model definition → validate contract → mark registry available → install ChangeHandler.
3. If `workflow_source == :host`: constantize provider class → validate contract methods.
4. Configure `Resolver` with all active sources.

### 5.8 Comparison with Existing Patterns

| Aspect | Custom Fields | Roles | Workflow (new) |
|---|---|---|---|
| Config option | `custom_fields: true` | `role_source` | `workflow_source` |
| Valid sources | DB only | `:implicit` / `:model` | `:static` / `:model` / `:host` |
| Contract validator | 5 required fields | name + active | 7 fields + host method check |
| Setup | `Setup.apply!` | `Setup.apply!` | `Setup.apply!` |
| Registry | `Registry.for_model` | `Registry.all_role_names` | `Registry.for_model` + `by_name` |
| Cache invalidation | `DefinitionChangeHandler` | `ChangeHandler` | `ChangeHandler` |
| Generator | `lcp_ruby:custom_fields` | `lcp_ruby:role_model` | `lcp_ruby:workflow` |
| Multiple sources | No | No | Yes (Resolver merges) |

---

## 6. Implementation Structure

```
lib/lcp_ruby/workflow/
├── state_machine.rb              # Core: validates transition against definition
├── transition_executor.rb        # Orchestrates: guard → role → set fields →
│                                 #   update record → audit log → events
├── resolver.rb                   # Merges definitions from all active sources
├── registry.rb                   # Thread-safe cache for DB-sourced definitions
├── contract_validator.rb         # Validates DB model fields & host provider methods
├── setup.rb                      # Boot orchestration (same pattern as Roles::Setup)
├── change_handler.rb             # after_commit cache invalidation
├── audit_log.rb                  # Auto-creates table, writes entries, queries history
├── definition.rb                 # Normalized workflow definition value object
├── sources/
│   ├── static_source.rb          # Reads from Loader (parsed YAML/DSL)
│   ├── model_source.rb           # Reads from DB table via Registry
│   └── host_source.rb            # Delegates to host-provided class
└── approval/
    ├── engine.rb                 # Creates requests/steps/tasks, evaluates completion
    ├── approver_resolver.rb      # Resolves user IDs: role/field/group/hierarchy/service
    ├── task_manager.rb           # CRUD operations on approval task records
    └── step_evaluator.rb         # Checks step completion, activates next step
```

### Reused Existing Modules

| Workflow need | Existing module |
|---|---|
| Guard evaluation | `ConditionEvaluator` (extended with `all`/`any`/`not`) |
| Role checks | `PermissionEvaluator.can?` |
| Side effects | `Events::Dispatcher` + event handlers |
| Auto-set fields | Inspired by `TransformApplicator` |
| Dynamic table creation | `SchemaManager` |
| Cache pattern | `Roles::Registry` / `CustomFields::Registry` |
| Contract validation | `ContractValidator` / `ContractResult` |
| UI action buttons | `ActionSet` + `ActionExecutor` |

---

## 7. Example: Full Purchase Order Workflow

Complete working example showing all features together.

### Model

```ruby
# config/lcp_ruby/models/purchase_order.rb
define_model :purchase_order do
  label "Purchase Order"
  label_plural "Purchase Orders"

  field :title, :string, label: "Title", null: false do
    validates :presence
  end

  field :status, :enum, label: "Status", default: "draft",
    values: {
      draft: "Draft",
      pending_approval: "Pending Approval",
      approved: "Approved",
      rejected: "Rejected"
    }

  field :total_amount, :decimal, label: "Total Amount", precision: 12, scale: 2 do
    validates :numericality, greater_than: 0
  end

  field :submitted_at, :datetime, label: "Submitted At"
  field :submitted_by, :integer, label: "Submitted By"
  field :approved_at, :datetime, label: "Approved At"
  field :rejected_at, :datetime, label: "Rejected At"

  belongs_to :department, model: :department, required: true

  scope :pending, where: { status: "pending_approval" }
  scope :approved, where: { status: "approved" }

  timestamps true
  label_method :title
end
```

### Workflow

```ruby
# config/lcp_ruby/workflows/purchase_order.rb
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
    roles: [:admin], trigger: :approval_approved do
    set_fields approved_at: :now
  end

  transition :reject, from: :pending_approval, to: :rejected,
    roles: [:admin], trigger: :approval_rejected, require_comment: true do
    set_fields rejected_at: :now
  end

  transition :rework, from: [:rejected, :pending_approval], to: :draft,
    label: "Return to Draft", icon: "rotate-ccw", roles: [:author, :admin],
    trigger: :approval_returned

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

### Permissions

```yaml
# config/lcp_ruby/permissions/purchase_order.yml
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

### Approval Groups

```yaml
# config/lcp_ruby/approval_groups.yml
approval_groups:
  finance_team:
    label: "Finance Team"
    members:
      type: role
      role: finance_reviewer
```

### What Happens at Runtime

1. User creates PO (status: `draft`, workflow_version: `1`).
2. User clicks "Submit" → engine checks guard (title present, amount > 0), checks role (author), executes transition → status becomes `pending_approval`, `submitted_at` set, `po_submitted` event fired, `on_entry: notify_approvers` event fired.
3. Approval engine activates. First checks `bypass_when` (total_amount <= 1000?) — if yes, skip directly to `approve` transition. Otherwise, creates `ApprovalRequest`, evaluates step conditions, creates `ApprovalStep` records.
4. Step 1 (manager) activates → resolves approvers with role `manager` → empty? falls back to `hr_manager` → creates tasks. Step 2 (finance, `assignment: claim`) condition: total_amount > 50,000? — if no, step is pre-marked `skipped`.
5. Manager approves → task marked `approved` → step 1 complete → step 2 activates (or skipped) → all steps complete → resolution triggers `approve` transition → status becomes `approved`, `readonly_fields: all` locks the record.
6. Alternative flow: manager clicks "Return" → task marked `returned` → request marked `returned` → triggers `rework` transition → status becomes `draft`. Author edits and resubmits → `rework_policy.reset: all` → new ApprovalRequest created, process restarts from step 1.
7. Audit log records all transitions with `workflow_version: 1`: `draft → pending_approval`, `pending_approval → approved` (or `→ draft` for rework).

---

## 8. Deferred Items

The following items were identified in review but deferred because they require
infrastructure not yet available (scheduled jobs, complex UI) or have limited
applicability.

### Deferred to Phase 3 (Notifications & Time)

- **SLA triggers on states and steps** — requires a scheduled job runner to check
  deadlines. The `sla` key on states and steps is accepted in the schema but has no
  effect until the scheduler is implemented.
- **Step-level timeout and escalation** — `timeout_days`, `escalation.after`,
  `escalation.to` on steps. Requires the same scheduler infrastructure.
- **Reminder notifications** — periodic reminders to approvers with pending tasks.

### Deferred to future iterations

- **Approval decision payload schema** — structured data capture during approval
  (reason enum, amount limit, attachment). Currently only `comment` (free text) is
  supported. Future: `decision_fields` array on steps with type/validation.
- **Sub-approval modules** — parallel approval branches with different rules that
  join before resolution (legal + security + finance). Current parallel steps within
  a single approval cover most cases.
- **Re-approval on material change** — detecting that a field changed after approval
  and automatically resetting the approval. Requires field-level change tracking and
  "material change" definition. Workaround: use `rework_policy.reset: all` and
  require manual resubmission.
- **Visual workflow editor** — drag-and-drop UI for designing workflows. Requires
  significant frontend investment.
