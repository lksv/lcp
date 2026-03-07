# Feature Specification: Multi-Step Forms

**Status:** Proposed
**Date:** 2026-03-07

## Problem / Motivation

LCP Ruby needs multi-step form flows (wizards) for use cases like complex record creation, onboarding, and import processes. The initial instinct was to build a dedicated `wizard` concept (`config/lcp_ruby/wizards/`), but analysis shows that most wizard functionality can be composed from existing platform primitives:

- **Model** with `status` and `current_step` enum fields (DB draft pattern)
- **Presenter** with section-level `visible_when` conditions (show/hide fields per step)
- **Conditional validations** (`when:` key) to validate only the current step's fields
- **Custom actions** for step transitions (next, previous, complete)
- **Action `visible_when`** to show/hide navigation buttons per step

This approach is preferable because it requires no new top-level concept, the configurator uses familiar primitives, and it naturally extends with workflow state machines when those are implemented.

However, several gaps prevent a smooth multi-step experience today. This spec identifies those gaps and proposes targeted enhancements.

### What Already Works

| Primitive | Multi-Step Use | Status |
|-----------|---------------|--------|
| Section-level `visible_when` | Show/hide field groups per step | Fully implemented |
| Conditional validations (`when:`) | Validate only current step's fields | Fully implemented |
| Custom actions | Step transitions (update `current_step`) | Fully implemented |
| Action `visible_when` / `disable_when` | Show Next/Previous/Complete per step | Fully implemented |
| Dialog actions (Tier 1) | Collect extra input before transition | Fully implemented |
| Enum fields | `current_step` with ordered values | Fully implemented |
| `status: draft/completed` | Draft lifecycle, garbage collection scope | Fully implemented |

### What's Missing

| Gap | Impact | Section |
|-----|--------|---------|
| Form buttons are hardcoded Save/Cancel | Cannot replace with step navigation buttons | Enhancement 1 |
| No built-in step navigation actions | Configurator must write Ruby action classes for basic next/prev/complete | Enhancement 2 |
| No step-aware routing | Cannot deep-link to a specific step, no clean URLs | Enhancement 3 |
| No stepper/progress UI | User doesn't see which step they're on or how many remain | Enhancement 4 |
| Form pages lack view slots | Cannot inject stepper component into form layout | Enhancement 5 |
| No review/summary step rendering | Confirm step must manually list fields as read-only | Enhancement 6 |
| Verbose `visible_when` repetition | Each section needs its own `visible_when` condition per step | Enhancement 7 |

## User Scenarios

**Scenario 1: Employee onboarding.** HR creates a new employee record. Step 1 collects personal info (name, email, phone). Step 2 collects job details (department, position, salary). Step 3 uploads documents. Step 4 shows a summary for review. At each step, a progress bar shows "Step 2 of 4 — Job Details." The URL reads `/onboard/42/step/job`. Clicking "Next" saves the current fields and advances. Clicking "Back" saves and goes to the previous step. Clicking "Complete" on step 4 sets `status: completed` and redirects to the show page.

**Scenario 2: Import wizard.** An admin uploads a CSV (step 1), maps columns (step 2), previews data (step 3), and sees results (step 4). Steps 2–4 use custom components, not standard form fields. The import_batch record tracks progress via `current_step`.

**Scenario 3: Resume abandoned wizard.** A user starts employee onboarding, fills step 1, and closes the browser. Next day, they open the record and are taken to step 2 (where they left off). The stepper shows step 1 as completed.

**Scenario 4: Conditional step skip.** In a product creation wizard, step 3 "Variants" is skipped when `product_type` is "simple" (no variants). The stepper shows 3 steps instead of 4, and "Next" on step 2 jumps directly to step 4 (review).

**Scenario 5: Zero-code wizard setup.** A configurator creates a multi-step form without writing any Ruby code: they define a model with `current_step` enum, a presenter with `steps:` shorthand and built-in `next_step`/`prev_step`/`complete` form actions. The platform handles everything — step navigation, routing, validation, stepper UI.

**Scenario 6: Custom logic on specific transition.** A configurator needs to send a notification email when moving from "documents" to "review." They replace the built-in `next_step` with a custom action for that specific transition (using `visible_when` to scope it to the documents step), while all other transitions use the built-in action.

## Enhancement 1: Form Actions as Equal Citizens

### Problem

Today, form submit buttons (Save, Cancel) are hardcoded in the form template. They are not configurable — the configurator cannot replace them, reorder them, or add additional submit buttons.

### Solution

Form buttons become a new action context `form` in the presenter, on equal footing with `collection`, `single`, and `batch`. `save` and `cancel` are built-in form actions that appear by default when no `form` actions are explicitly configured.

### Configuration

```yaml
# Default behavior (implicit when no form actions are defined)
actions:
  form:
    - { name: save, type: built_in, style: primary }
    - { name: cancel, type: built_in, style: secondary }
```

```yaml
# Multi-step: replace save/cancel with step navigation
actions:
  form:
    - name: prev_step
      type: built_in
      icon: arrow-left
      style: secondary
      visible_when: { field: current_step, operator: neq, value: personal }
    - name: next_step
      type: built_in
      icon: arrow-right
      style: primary
      visible_when: { field: current_step, operator: neq, value: review }
    - name: complete
      type: built_in
      icon: check
      style: success
      visible_when: { field: current_step, operator: eq, value: review }
    - { name: cancel, type: built_in, style: secondary }
```

```yaml
# Hybrid: keep "Save Draft" alongside step navigation
actions:
  form:
    - { name: save, type: built_in, style: secondary }
    - name: next_step
      type: built_in
      style: primary
      visible_when: { field: current_step, operator: neq, value: review }
```

### Behavior

- When `form:` is explicitly defined, only the listed actions appear — no implicit save/cancel
- When `form:` is not defined, the form renders the default `save` + `cancel` (backward compatible)
- All form actions support `visible_when`, `disable_when`, `confirm`, `icon`, `style` — same as other action contexts
- Custom (`type: custom`) form actions are also supported, mixed freely with built-in ones

### Controller Integration

Every form action is a submit button. When clicked, the form submits to the standard endpoint (`PATCH /:slug/:id` or `POST /:slug`) with an additional `_form_action` parameter identifying which button was pressed.

The controller flow:

1. Save form data (standard update/create with permitted params)
2. If save fails → re-render form with errors, regardless of which button was pressed
3. If save succeeds → check `params[:_form_action]`
4. If `_form_action` is a built-in (`save`, `next_step`, `prev_step`, `complete`) → controller handles it directly
5. If `_form_action` is a custom action → delegate to `ActionExecutor`
6. Use the action's result for redirect

The built-in `save` action simply redirects back to edit (or show, depending on configuration). Custom form actions return their own redirect target.

## Enhancement 2: Built-in Step Navigation Actions

### Problem

For a basic multi-step form (linear steps, no custom logic between transitions), the configurator must write Ruby action classes that do nothing more than "find the next step in the enum and update the field." This is boilerplate.

### Solution

Three new built-in form actions: `next_step`, `prev_step`, and `complete`. The platform implements them using the `stepper:` configuration — it knows the step sequence, the step field, and the skip conditions.

### Built-in Action Behavior

| Action | Save? | Step Field Update | Redirect |
|--------|-------|-------------------|----------|
| `save` | Yes | No change | Back to current step |
| `cancel` | No | No change | To show page or index |
| `next_step` | Yes | Advance to next step (skipping steps where `skip_when` is true) | To next step URL |
| `prev_step` | Yes | Go back to previous step (skipping steps where `skip_when` is true) | To previous step URL |
| `complete` | Yes | Set `status` to `stepper.completed_status` (default: `completed`) | To show page |

All built-in step actions require the `stepper:` configuration on the presenter. Without it, using `next_step` / `prev_step` / `complete` raises a configuration error at boot.

### How Step Sequence Is Determined

1. The platform reads `stepper.field` to identify the enum field (e.g., `current_step`)
2. If `stepper.steps` is defined, it uses that list as the sequence
3. Otherwise, it reads the enum values from the model definition (in declared order)
4. For `next_step` and `prev_step`, the platform evaluates `skip_when` on each candidate step and skips those where the condition is true
5. If `next_step` is called on the last step (or `prev_step` on the first), the action does nothing (stays on current step)

### Transition Validation

The built-in actions enforce sequential navigation — a user cannot jump from step 1 to step 4. The step field is only updated to the adjacent step in the sequence. This is a platform guarantee, not something the configurator must implement.

For non-sequential navigation (e.g., clicking on a completed step in the stepper), a separate mechanism is needed (see Enhancement 4, clickable stepper).

### Mixing Built-in and Custom

The configurator can replace a built-in step action with a custom one for specific transitions:

```yaml
actions:
  form:
    # Custom action for the documents → review transition (sends notification)
    - name: submit_for_review
      type: custom
      icon: arrow-right
      style: primary
      visible_when: { field: current_step, operator: eq, value: documents }
    # Built-in next_step for all other transitions
    - name: next_step
      type: built_in
      style: primary
      visible_when:
        all:
          - { field: current_step, operator: neq, value: review }
          - { field: current_step, operator: neq, value: documents }
    - name: prev_step
      type: built_in
      style: secondary
      visible_when: { field: current_step, operator: neq, value: personal }
    - name: complete
      type: built_in
      style: success
      visible_when: { field: current_step, operator: eq, value: review }
```

The `submit_for_review` custom action handles the `documents → review` transition with custom logic. All other transitions use the built-in. The `visible_when` conditions ensure only one "forward" button is visible at a time.

### Interaction with Workflow

When workflow state machines are implemented, built-in step actions become a thin layer over workflow transitions:

- `next_step` triggers the "forward" transition defined in the workflow
- `prev_step` triggers the "backward" transition
- `complete` triggers the "finalize" transition
- Workflow guards replace `skip_when`, workflow hooks replace custom action logic

The YAML configuration stays the same — only the underlying engine changes. Built-in step actions are the pre-workflow solution that workflow subsumes.

## Enhancement 3: Step-Aware Routing

### Problem

Multi-step forms need clean, bookmarkable, shareable URLs per step. Without step-aware routing, the URL is always `/:slug/:id/edit` regardless of which step the user is on.

### Solution: URL Segment Routing

A new route pattern for step-aware forms:

```
GET   /:lcp_slug/:id/step/:step_name     → display the form for a specific step
PATCH /:lcp_slug/:id/step/:step_name     → save + execute form action for that step
```

These routes live alongside (not replace) the existing edit routes:

```
GET   /:lcp_slug/:id/edit                → standard edit page (non-step)
PATCH /:lcp_slug/:id                     → standard update
GET   /:lcp_slug/:id/step/:step_name     → step-aware edit page
PATCH /:lcp_slug/:id/step/:step_name     → step-aware update
```

### Behavior

- The `step` URL parameter is a **navigation hint**. The `current_step` field on the record is the source of truth for which step is "active."
- When a user navigates to `/:slug/:id/step/job`:
  - If `record.current_step` is `job` or later → render the `job` step (allow revisiting completed steps)
  - If `record.current_step` is before `job` (e.g., `personal`) → redirect to `/:slug/:id/step/personal` (cannot skip ahead)
- Navigating to `/:slug/:id/edit` on a record that has a `stepper:` configured → redirect to `/:slug/:id/step/<current_step>`
- Built-in step actions (`next_step`, `prev_step`) redirect to the appropriate step URL after save

### Path Helpers

The platform provides step-aware path helpers:

- `step_resource_path(record, :job)` → `/:slug/:id/step/job`
- `current_step_resource_path(record)` → `/:slug/:id/step/<record.current_step>`

The stepper component and form actions use these helpers to generate correct URLs.

### Controller

The step routes are handled by the existing `ResourcesController` with a `before_action` that:

1. Detects `params[:step_name]`
2. Validates the step name against the `stepper.steps` list
3. Checks that the requested step is reachable (index ≤ current step index)
4. Sets `@current_step` for the view layer
5. The view uses `@current_step` (from URL) instead of `record.current_step` (from DB) to determine which section to show — this allows revisiting completed steps

## Enhancement 4: Stepper Component

### Problem

When a user is on step 2 of 4, there is no visual indication of progress. The form looks like a regular edit page with a subset of fields visible.

### Solution: Built-in Stepper View Slot Component

A platform-provided view slot component that renders a step progress indicator. It reads configuration from the presenter and the record's `current_step` field.

### Configuration

```yaml
# On the presenter, alongside sections and actions
presenter:
  name: employee_onboarding
  model: employee_onboarding

  stepper:
    field: current_step                 # enum field that tracks progress
    completed_status: completed         # optional: status value that means "all done"
    steps:                              # optional: override enum order/labels
      - personal
      - job
      - documents
      - review
```

If `steps:` is omitted, the stepper reads values from the `current_step` enum definition on the model. The `steps:` key allows reordering, omitting steps, or referencing a subset.

Labels come from i18n: `lcp_ruby.presenters.<presenter>.stepper.<step_name>` with humanized fallback.

### Rendering

The stepper renders in the `:page_header` slot on form pages (see Enhancement 5):

```
Step 1          Step 2          Step 3          Step 4
Personal    >   Job Details >   Documents   >   Review
[completed]     [current]       [upcoming]      [upcoming]
```

Visual states per step:
- **Completed** — step index < current step index (checkmark icon, muted style)
- **Current** — active step (highlighted, bold label)
- **Upcoming** — step index > current step index (numbered, muted)
- **Skipped** — step was skipped via `skip_when` (not shown or shown as dashed)

The component is a standard partial registered in `ViewSlots::Registry` at boot. It is automatically enabled when the presenter has a `stepper:` configuration block.

### Clickable Completed Steps

Completed steps in the stepper are rendered as links to their step URL (`/:slug/:id/step/<step_name>`). This allows users to navigate back to a completed step to review or edit data. The step-aware routing (Enhancement 3) handles the navigation.

Upcoming steps are not clickable — the user must proceed sequentially via the built-in step actions.

### Steps with `skip_when`

Steps where `skip_when` evaluates to true are hidden from the stepper entirely — the step count adjusts dynamically. For example, if step 3 "Variants" is skipped, the stepper shows "Step 1 — Step 2 — Step 3 (Review)" instead of "Step 1 — Step 2 — Step 3 (Variants) — Step 4 (Review)."

## Enhancement 5: View Slots on Form Pages

### Problem

Form pages (`new.html.erb`, `edit.html.erb`) do not call `render_slot`. The stepper component (and any other slot-based component) cannot be injected into form pages.

### Solution

Add `render_slot` calls to form page templates for `:page_header` and optionally `:below_content` slots. This mirrors the slot infrastructure already present on index and show pages.

### Slots Added

| Slot | Position in Form | Use Case |
|------|-----------------|----------|
| `:page_header` | Above form title | Stepper, info banners, warnings |
| `:below_content` | Below form actions | Help text, related info |

The `:toolbar_*` slots are not added to forms in v1 — forms have their own action bar (form actions). If needed, they can be added later.

### SlotContext on Form Pages

The `SlotContext` for form pages includes `record` (the record being edited or a new unsaved instance). This allows the stepper component to read `record.current_step`.

## Enhancement 6: Summary/Review Section Type

### Problem

A common wizard pattern is a final "review" step showing all previously entered data as read-only before confirmation. Today, the configurator must manually create a section with all fields listed and somehow mark them as read-only — there's no auto-summary.

### Solution: `type: summary` Section

A new section type that automatically collects fields from named sections and renders them read-only (using show-page renderers, not form inputs).

### Configuration

```yaml
sections:
  edit:
    sections:
      - name: personal
        visible_when: { field: current_step, operator: eq, value: personal }
        fields: [first_name, last_name, email, phone]

      - name: job
        visible_when: { field: current_step, operator: eq, value: job }
        fields: [department_id, position_id, salary]

      - name: review
        type: summary
        visible_when: { field: current_step, operator: eq, value: review }
        source_sections: [personal, job]    # collect fields from these sections
```

### Behavior

- The `review` section renders fields from `personal` and `job` sections grouped by source section (with section name as header)
- Fields are rendered using show-page renderers (read-only display), not form inputs
- Hidden fields carry the values for form submission (so the review step can still be "saved")
- If `source_sections` is omitted, all non-summary sections are included

### Rendering

```
Review & Confirm
-----------------------------------------
Personal Information
  First Name:   Jan Novak
  Email:        jan@example.com
  Phone:        +420 123 456 789

Job Details
  Department:   Engineering
  Position:     Senior Developer
  Salary:       85,000 CZK
-----------------------------------------
[Back]                          [Complete]
```

## Enhancement 7: `steps` Shorthand (Optional Sugar)

### Problem

Setting up a multi-step form requires repetitive configuration: each section needs its own `visible_when` condition referencing the same field, and the stepper config must list the same step names. This is verbose and error-prone.

### Solution: `steps` Shorthand in Presenter

A `steps` key in the edit/new section that auto-generates section-level `visible_when` conditions and stepper configuration.

### Configuration (Shorthand)

```yaml
presenter:
  name: employee_onboarding
  model: employee_onboarding
  slug: onboard

  stepper:
    field: current_step

  sections:
    edit:
      steps:
        - name: personal
          fields: [first_name, last_name, email, phone]

        - name: job
          fields: [department_id, position_id, salary]
          skip_when:
            field_ref: employment_type
            operator: eq
            value: contractor

        - name: documents
          fields: [contract, photo]

        - name: review
          type: summary
          source_sections: [personal, job, documents]
```

### Expansion

The `steps` key is syntactic sugar. At load time, it expands to standard sections with `visible_when` conditions:

```yaml
# Equivalent expanded form (what the system sees internally)
sections:
  edit:
    sections:
      - name: personal
        visible_when: { field: current_step, operator: eq, value: personal }
        fields: [first_name, last_name, email, phone]

      - name: job
        visible_when:
          all:
            - { field: current_step, operator: eq, value: job }
            - not: { field_ref: employment_type, operator: eq, value: contractor }
        fields: [department_id, position_id, salary]

      - name: documents
        visible_when: { field: current_step, operator: eq, value: documents }
        fields: [contract, photo]

      - name: review
        type: summary
        visible_when: { field: current_step, operator: eq, value: review }
        source_sections: [personal, job, documents]
```

The `stepper.field` tells the system which enum field drives the step progression. Each step name must match an enum value in that field. The `skip_when` on a step is merged into the `visible_when` condition as an additional `not:` clause.

### Why Shorthand, Not New Concept

- **No new rendering pipeline** — it expands to existing sections with conditions
- **No new state management** — standard model field
- **Inspectable** — the configurator can see what it expands to
- **Mixable** — you can use shorthand for some steps and manual sections alongside
- **Gradually adoptable** — works without the shorthand, shorthand just reduces boilerplate

## Configuration & Behavior: Complete Example

### Model

```yaml
# config/lcp_ruby/models/employee_onboarding.yml
model:
  name: employee_onboarding
  fields:
    - { name: status, type: enum, values: [draft, completed, cancelled], default: draft }
    - { name: current_step, type: enum, values: [personal, job, documents, review], default: personal }
    # Step 1: Personal
    - { name: first_name, type: string }
    - { name: last_name, type: string }
    - name: email
      type: email
      validations:
        - type: presence
          when: { field: current_step, operator: in, value: [personal, job, documents, review] }
    # Step 2: Job
    - name: department_id
      type: integer
      validations:
        - type: presence
          when: { field: current_step, operator: in, value: [job, documents, review] }
    - { name: position_id, type: integer }
    - name: salary
      type: decimal
      validations:
        - type: numericality
          options: { greater_than: 0 }
          when: { field: current_step, operator: in, value: [job, documents, review] }
    # Step 3: Documents
    - { name: contract, type: attachment }
  associations:
    - { name: department, type: belongs_to, model: department }
    - { name: position, type: belongs_to, model: position }
  scopes:
    - { name: drafts, where: { status: draft } }
    - { name: completed, where: { status: completed } }
```

### Presenter

```yaml
# config/lcp_ruby/presenters/employee_onboarding.yml
presenter:
  name: employee_onboarding
  model: employee_onboarding
  slug: onboard

  stepper:
    field: current_step

  sections:
    index:
      fields: [first_name, last_name, email, status, current_step]
    show:
      fields: [first_name, last_name, email, department_id, position_id, salary, status, current_step]
    edit:
      steps:
        - name: personal
          fields: [first_name, last_name, email, phone]
        - name: job
          fields: [department_id, position_id, salary]
        - name: documents
          fields: [contract]
        - name: review
          type: summary
          source_sections: [personal, job, documents]

  actions:
    collection:
      - { name: create, type: built_in }
    form:
      - name: prev_step
        type: built_in
        icon: arrow-left
        style: secondary
        visible_when: { field: current_step, operator: neq, value: personal }
      - name: next_step
        type: built_in
        icon: arrow-right
        style: primary
        visible_when: { field: current_step, operator: neq, value: review }
      - name: complete
        type: built_in
        icon: check
        style: success
        visible_when: { field: current_step, operator: eq, value: review }
      - { name: cancel, type: built_in, style: secondary }
    single:
      - { name: show, type: built_in }
      - { name: edit, type: built_in }
      - { name: destroy, type: built_in }
```

### Validation Strategy

Conditional validations ensure that fields are only required from their step onward:

- `email` required from step `personal` onward (`in: [personal, job, documents, review]`)
- `department_id` required from step `job` onward (`in: [job, documents, review]`)

This means: saving step 1 does not require `department_id`, but saving step 2 requires both `email` (from step 1) and `department_id` (from step 2). The pattern is "cumulative validation" — each step adds its fields to the validation set, and all previous steps' fields remain validated.

Alternative: validate only the current step's fields (`operator: eq` instead of `operator: in`). This is more lenient — a user could go back to step 1, clear a field, and advance again. The configurator chooses the strategy by writing the `when:` conditions.

### Full User Flow

1. User clicks "New" on the index page → `POST /onboard` creates a draft record (status: draft, current_step: personal) → redirect to `/onboard/42/step/personal`
2. User fills in personal info, clicks "Next" → `PATCH /onboard/42/step/personal` with `_form_action=next_step` → saves fields, advances to `job` → redirect to `/onboard/42/step/job`
3. User fills in job details, clicks "Next" → saves, advances to `documents` → redirect to `/onboard/42/step/documents`
4. User uploads contract, clicks "Next" → saves, advances to `review` → redirect to `/onboard/42/step/review`
5. User reviews summary, clicks "Complete" → saves, sets status: completed → redirect to `/onboard/42` (show page)
6. At any point, user can click "Back" or click a completed step in the stepper to go back
7. If user closes browser at step 2 and returns later, navigating to `/onboard/42/edit` redirects to `/onboard/42/step/job`

## General Implementation Approach

### Enhancement 1: Form Actions

The `ActionSet` gains a `form` context. The presenter schema adds `form:` to the `actions:` block. Form actions are rendered as submit buttons in the form template (replacing the hardcoded Save/Cancel).

Each form action button sets a hidden `_form_action` value. The `ResourcesController#update` (and `#create`) checks `params[:_form_action]` after a successful save:
- Built-in actions (`save`, `cancel`, `next_step`, `prev_step`, `complete`) are handled directly by the controller
- Custom actions are delegated to `ActionExecutor`

When no `form:` actions are defined, the controller injects the default `save` + `cancel` (backward compatible).

### Enhancement 2: Built-in Step Actions

The controller implements `next_step`, `prev_step`, and `complete` as built-in handlers (no `ActionExecutor` needed for these). The logic:

1. Read `stepper.field` and `stepper.steps` from presenter configuration
2. Determine current position in the step sequence
3. For `next_step`: find the next step where `skip_when` is false (or nil), update the field
4. For `prev_step`: find the previous step where `skip_when` is false, update the field
5. For `complete`: set the `stepper.completed_status` field (on the `status` field, not the step field)
6. Redirect to the appropriate step URL

`skip_when` conditions are evaluated using the existing `ConditionEvaluator` against the freshly-saved record.

### Enhancement 3: Step-Aware Routing

A new route is added to the engine:

```ruby
resources :resources, path: ":lcp_slug", param: :id do
  member do
    get  "step/:step_name", action: :edit, as: :step
    patch "step/:step_name", action: :update
  end
end
```

The `ResourcesController` detects `params[:step_name]` and:
1. Validates it against the presenter's stepper configuration
2. Checks reachability (step index ≤ current_step index)
3. Sets `@display_step` for the view (may differ from `record.current_step` when revisiting)
4. The `visible_when` conditions in the expanded `steps:` compare against `current_step` (the DB field), but the `@display_step` overrides which section is shown — this is how revisiting completed steps works

When the standard `/edit` route is accessed on a record with stepper configuration, it redirects to the step URL for the current step.

### Enhancement 4: Stepper Component

A built-in view slot component registered at boot:

1. Reads `presenter.stepper` configuration
2. Reads enum values from `model_definition.fields` for the configured `field`
3. Determines current step from `record.send(stepper_field)`
4. Evaluates `skip_when` on each step to determine visibility
5. Computes step states (completed, current, upcoming)
6. Renders a horizontal step indicator with i18n labels and links for completed steps

The component is registered for `:edit` and `:new` pages in the `:page_header` slot (requires Enhancement 5). It is automatically enabled when the presenter has a `stepper:` block.

### Enhancement 5: Form Page View Slots

Add `render_slot` calls to `new.html.erb` and `edit.html.erb` (or the shared `_form.html.erb`) for the `:page_header` and `:below_content` slots. The `SlotContext` is built with the current record, presenter, model_definition, and evaluator — same as show/index pages.

This is a small template change with no new infrastructure.

### Enhancement 6: Summary Section

`LayoutBuilder` recognizes `type: summary` sections. Instead of building form fields, it:

1. Resolves `source_sections` to their field lists
2. Builds a read-only section using show-page renderers (`FieldValueResolver` + display renderers)
3. Includes hidden fields for each value (so the form submission carries all data)
4. Groups fields by source section with section name headers

### Enhancement 7: Steps Shorthand

`PresenterDefinition` (or a pre-processing step) recognizes the `steps:` key under `edit:` / `new:` and expands it to standard `sections:` with `visible_when` conditions:

1. Reads `stepper.field` to know which field drives visibility
2. For each step, generates `visible_when: { field: <stepper_field>, operator: eq, value: <step_name> }`
3. Merges any `skip_when` as `not:` in a compound `all:` condition
4. Passes the expanded sections through the normal `LayoutBuilder` pipeline

## Integration with Future Features

### Workflow State Machine

When workflows are implemented, the manual custom actions (`next_step`, `prev_step`, `complete`) will be replaced by declarative transitions:

```yaml
workflow:
  field: current_step
  transitions:
    - { from: personal, to: job, action: next }
    - { from: job, to: personal, action: back }
    - { from: job, to: documents, action: next }
    # ...
```

The workflow auto-generates the action buttons with correct visibility conditions. The `steps` shorthand, stepper component, and form actions continue to work — only the action definitions change. Built-in step actions become a thin layer over workflow transitions.

### Modal Dialogs (Multi-Step)

When modal infrastructure supports multi-step content (Tier 3), multi-step forms can render inside modals. The same presenter configuration works — the modal renders the edit form, and form actions submit within the modal context. The stepper component adapts to modal layout.

### Import Wizard

The import flow (upload, mapping, preview, result) uses the same model-based pattern:
- `import_batch` model with `current_step` enum
- Step 1 is a standard form (file, format, mode)
- Steps 2–4 use `type: custom` sections with built-in platform components (column mapper, preview table, result summary)

The `type: custom` section type is not covered in this spec — it is specific to the import/export feature and will be defined there.

## Decisions

### D1: No dedicated wizard concept

Multi-step forms are composed from existing primitives (models, presenters, actions, conditions) plus targeted enhancements. No `config/lcp_ruby/wizards/` directory, no `WizardController`, no new top-level concept. This keeps the platform simple and lets the configurator use familiar tools.

### D2: DB draft pattern for state

Multi-step form state is a regular DB record with `status` and `current_step` fields. No session-based or hidden-field state management. This gives resumability, auditability, and garbage collection via standard model scopes.

### D3: Form actions as equal citizens

All form buttons (Save, Cancel, Next, Back, Complete) are actions in the `form` context — no hardcoded buttons. `save` and `cancel` are built-in form actions that appear by default when no `form` actions are explicitly configured. This unifies the form button model and gives the configurator full control.

### D4: Built-in step navigation actions

`next_step`, `prev_step`, and `complete` are built-in form actions. The platform implements step transitions using the `stepper:` configuration — zero Ruby code for basic wizards. Custom actions remain available as an escape hatch for transitions that need custom logic.

### D5: URL segment routing for steps

Step-aware routing uses URL segments (`/:slug/:id/step/:step_name`), not query params. Clean, bookmarkable, shareable URLs. The step URL is a navigation hint; the `current_step` DB field remains the source of truth. Visiting a step ahead of `current_step` redirects back; visiting a completed step is allowed.

### D6: Stepper as view slot component

The stepper is a built-in view slot component in the `:page_header` slot, not a section type or custom renderer. Automatically enabled by the `stepper:` presenter config. Completed steps are clickable links to their step URLs.

### D7: Steps shorthand is sugar, not required

The `steps:` key is optional syntactic sugar that expands to standard sections with `visible_when`. Configurators can always write the expanded form manually. This ensures the feature is fully transparent and debuggable.

### D8: Cumulative validation is the recommended pattern

The recommended pattern is cumulative validation — `when: { operator: in, value: [current_step, ...later_steps] }` — so that once a field is validated, it stays validated in all subsequent steps. The platform does not enforce this; the configurator writes the conditions.

### D9: Summary section renders with show-page renderers

The `type: summary` section uses the same display renderers as show pages (read-only). Hidden fields carry values for form submission. This reuses existing rendering infrastructure.

## Open Questions

### Q1: New record flow

When creating a new record (step 1), should the form submit to `POST /:slug` (create) with `_form_action=next_step`? This means the create action both creates the draft record AND advances to step 2. The redirect goes to `GET /:slug/:id/step/<next_step>`.

Or should "New" always create a draft record first (via a collection action or auto-create), then redirect to the step form?

### Q2: Revisiting completed steps — edit or display?

When a user clicks a completed step in the stepper (e.g., goes back to step 1 from step 3), should the step render as:

- **Editable form** — the user can change values and save. This is more flexible but allows "regression" (breaking already-validated data).
- **Read-only display** (like the summary section) with an explicit "Edit" action. Safer but more friction.

### Q3: Stepper on show page

Should the stepper component also render on the show page (not just edit/form pages)? For records still in draft, the show page could display the stepper showing progress. For completed records, the stepper shows all steps as completed. This is purely informational but provides useful context.

### Q4: Abandoned draft cleanup

How are abandoned draft records cleaned up?

- **Manual** — admin deletes them from the index page (filter by `status: draft`, bulk delete)
- **Automatic** — configurable TTL on drafts (e.g., `draft_ttl: 30.days`), background job or boot-time cleanup
- **Scope-based** — default scope excludes old drafts from index, but they remain in DB
