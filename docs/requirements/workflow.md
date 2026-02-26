# Workflow and Approval Processes — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Workflow Definitions

- [~] Workflow defined in metadata (without deployment) — enum fields + presenters + permissions are YAML-driven, but no dedicated "workflow definition" object exists
- [~] State machine — defining states and allowed transitions between them — enum fields define states; transitions must be enforced via custom actions (no built-in state machine DSL)
- [~] Multiple workflows per entity (different process for different record types) — multiple presenters per model via view groups, but not multiple workflow definitions
- [ ] Workflow versioning (new records run on new version, in-progress records finish on old version)
- [ ] Visual workflow editor (drag & drop states and transitions)
- [ ] Support for sub-workflows / nested processes
- [ ] Workflow templates (pre-built patterns: simple approval, multi-level, parallel...)

## States and Transitions

- [x] State definition with metadata (name, color, icon, description) — enum_values with labels + badge renderer with color_map
- [x] State categorization (draft, in_progress, waiting, approved, rejected, closed...) — scopes (e.g., `open_deals`, `won`, `lost`) + search predefined_filters
- [~] Guard conditions for transitions — transition allowed only when rules are met — implementable via custom actions with validation logic, not declarative in metadata
- [x] Conditions based on record data (e.g., amount > 100,000 → different branch) — ConditionEvaluator with 12 operators (eq, gt, in, present, matches...)
- [x] Conditions based on user role — PermissionEvaluator with role-based CRUD, field-level, and action-level permissions
- [~] Conditions based on external system (API call) — condition services (server-side) exist for visibility/disabling, but not for state transitions
- [ ] Automatic transitions (trigger on condition met without user intervention)
- [ ] Timed transitions (auto-escalation after X days without response)
- [x] Transition back (return to previous state, rework) — custom actions can set any enum value

## Approval Process

- [ ] Simple approval (single approver)
- [ ] Multi-level approval (sequential chain of approvers)
- [ ] Parallel approval (multiple approvers simultaneously)
- [ ] Rule for parallel approval: all must approve vs. majority vs. at least one
- [ ] Dynamic approver — determined from record data (e.g., department head of the author)
- [ ] Approver by organizational hierarchy (direct manager → their manager → ...)
- [ ] Approval groups (pool of approvers — first to act approves)
- [ ] Approver delegation (substitution during absence / vacation)
- [ ] Escalation on inactivity (after X days, moves to higher level or notifies)
- [ ] Approval with condition (approved, but with note / request for minor correction)
- [ ] Partial approval (for documents with multiple items — some approved, some rejected)

## Side Effects on Transition

- [x] Field value changes on transition (auto-fill approval date, approver...) — event handlers can modify record fields on state change
- [x] Field locking / unlocking by state (after approval, record is locked) — disable_when + record_rules deny_crud with except_roles
- [~] Send notification (email, in-app, webhook) — no built-in notification system; implementable via async event handlers + ActionMailer
- [~] External API call (integration with other systems) — implementable via async event handlers, no declarative config
- [ ] Document generation (PDF, report) upon reaching a state
- [~] Create follow-up record (e.g., approved order → create invoice) — implementable via event handlers
- [ ] Trigger another workflow (chain / trigger)
- [ ] Mandatory transition reason logging (required comment on rejection)

## Notifications and Communication

- [ ] Notification to approver when waiting for their action
- [ ] Notification to requester on state change (approved / rejected / returned)
- [ ] Reminders (reminder after X days without action)
- [ ] Escalation notifications (to approver's manager)
- [ ] Configurable notification templates per workflow / transition
- [ ] Notification channels driven from metadata (email, SMS, in-app, Slack, webhook...)
- [ ] Ability to respond directly from notification (approve/reject from email)

## Rules and Business Logic

- [x] Rule engine for condition evaluation (expressions in metadata) — ConditionEvaluator with field-value and service conditions
- [x] Support for simple expressions (field == value, field > value, field IN [a, b, c]) — 12 operators: eq, not_eq, in, not_in, gt, gte, lt, lte, present, blank, matches, not_matches
- [ ] Support for compound expressions (AND, OR, NOT, parentheses)
- [ ] Expressions referencing related entities (e.g., author.department.head)
- [ ] Expressions with functions (SUM, COUNT, DATEDIFF...)
- [ ] Test mode for rules (dry-run — what would happen if...)
- [ ] Rule evaluation logging (why transition was / wasn't allowed)

## SLA and Time Management

- [ ] SLA definition per state (maximum duration in a state)
- [ ] SLA per transition (maximum response time for approver)
- [ ] Different SLA by record priority
- [ ] SLA compliance dashboard (what % of records met SLA)
- [ ] Automatic escalation on SLA breach
- [ ] Business calendar (SLA counts only on business days / hours)
- [ ] SLA pause (pause while waiting for external input)

## Monitoring and Reporting

- [ ] Overview of in-progress processes (where things are stuck)
- [ ] Bottleneck analysis (which state / approver is causing delays)
- [ ] Average workflow throughput time
- [ ] Transition history for a specific record (timeline visualization)
- [x] Filtering and searching by workflow state — scopes + predefined search filters in presenter
- [ ] Workflow data export (CSV, API)
- [ ] Dashboard with KPI per workflow (approved / rejected count, average time...)

## Administration and Maintenance

- [ ] Record migration on workflow change (what to do with old records in a removed state)
- [~] Manual record move by admin (workflow override for exceptional situations) — record_rules with except_roles: [admin] allows admin to bypass restrictions
- [~] Bulk operations on records in a state (bulk approve / reject) — batch actions exist in the action framework, but no built-in bulk approve/reject
- [ ] Completed process archival
- [ ] Workflow deactivation without deletion (soft disable)
- [ ] Copy workflow as basis for new process

---

## Key Points

- **Workflow versioning** — without it, changing a process breaks in-progress records. Records must finish on the version they started with.
- **Approver delegation** — in practice, one of the most common user requests. A person goes on vacation and the entire process stalls.
- **Business calendar for SLA** — without it, SLA is counted over weekends and holidays, which distorts metrics and generates false escalations.
- **Mandatory comment on rejection** — small detail, but without it, the requester doesn't learn why their request was rejected and submits it again unchanged.
