# Feature Specification: Modal Dialogs (Self-Hosted)

**Status:** Proposed
**Date:** 2026-03-03

## Problem / Motivation

Currently, modal dialogs in LCP (e.g., saved filter save dialog) are hardcoded ERB partials with hand-written HTML and JavaScript. This contradicts the platform's core principle: everything should be driven by YAML/DSL metadata.

The goal is that **every modal dialog is a presenter rendered in a modal context** — the same model/presenter/permission system that drives full pages also drives dialogs. This applies to both built-in dialogs (saved filters, confirmations, quick create) and user-defined dialogs.

## Core Concept

**Dialog = presenter rendered in a modal context instead of a full page.**

Everything else (fields, sections, validations, permissions, conditional rendering, actions) already exists. The only new concept is *where* and *how* the presenter is rendered.

```
┌─────────────────────────────────────────────────┐
│  Existing LCP concepts        New concept        │
│                                                   │
│  Model (real / virtual)  ─┐                       │
│  Presenter (fields,       ├──▶  Dialog            │
│    sections, actions)    ─┘    (= render context) │
│  Permissions             ─────▶  (reuse as-is)    │
│  Actions (trigger)       ─────▶  (trigger source) │
│  Events (on_submit)      ─────▶  (reuse as-is)    │
└─────────────────────────────────────────────────┘
```

What already exists and works:
- **Virtual models** (`table_name: _virtual`) — metadata without a DB table
- **Real models** — standard DB-backed models (e.g., saved filters)
- **Presenters** — layout, fields, sections, conditional rendering
- **Actions** — trigger point for opening dialogs
- **Permissions** — who can open / submit a dialog
- **Events** — what happens after submit
- **Condition evaluator** — `visible_when`, `disable_when` inside dialogs

What is **new**:
1. **Render context** — presenter knows it renders as a dialog (not a full page)
2. **Dialog trigger** — action/button knows to open a dialog (not navigate)
3. **Submit behavior** — what happens after form submission (create, update, execute action, close)
4. **Dialog lifecycle** — open → fill → validate → submit → success/error → close/stay

## User Scenarios

### Built-in (platform provides)

| # | Dialog | Data source | Example |
|---|--------|------------|---------|
| 1 | **Save filter** | real model (persisted to DB) | Save current filter with name, visibility, pinning |
| 2 | **Delete confirmation** | no model, just text + confirm | "Are you sure you want to delete?" |
| 3 | **Quick create** | real model | "Add contact" without leaving the page |
| 4 | **Quick edit** | existing record | Inline edit in a modal |
| 5 | **Quick view** | existing record (readonly) | Detail preview without navigation |
| 6 | **Record picker** | real model (index view in modal) | Advanced association select with filters |
| 7 | **Bulk edit** | virtual model (fields for bulk change) | "Set status=closed for 15 records" |
| 8 | **Import** | virtual model (file upload + mapping) | CSV/Excel import |
| 9 | **Export config** | virtual model (format, columns, filter) | "Export as PDF with these columns" |
| 10 | **Workflow transition** | virtual model (comment, reason, date) | "Approve order" — requires comment |
| 11 | **Approval** | virtual model (approve/reject + comment) | Approval dialog |
| 12 | **Share / permissions** | virtual model or real | "Share this report with role X" |

### User-defined

| # | Dialog | Example |
|---|--------|---------|
| 13 | **Custom action with input** | "Reassign to user" → user picker |
| 14 | **Multi-step wizard** | Employee onboarding (3 steps) |
| 15 | **Nested form** | Add invoice line from a modal |
| 16 | **Calculator / preview** | "Calculate price" → readonly result |
| 17 | **Note / comment** | "Add internal note" to a record |
| 18 | **Filter builder** | Advanced filter as a dialog (not inline panel) |

## Configuration & Behavior

### 1. Model (real model for saved filters)

Saved filters are persisted records, so they use a real DB-backed model (not virtual):

```yaml
# config/lcp_ruby/models/saved_filter.yml
name: saved_filter
fields:
  - name: name
    type: string
    required: true
  - name: description
    type: text
  - name: visibility
    type: enum
    values: [personal, role, global, group]
    default: personal
  - name: target_role
    type: string
  - name: target_group
    type: string
  - name: pinned
    type: boolean
    default: false
  - name: default_filter
    type: boolean
    default: false
  - name: condition_tree
    type: json
  - name: ql_text
    type: text
  - name: target_presenter
    type: string
    required: true
  - name: owner_id
    type: integer
    required: true
```

### 2. Virtual model (for dialogs that don't persist)

For dialogs that collect input but don't save a record (e.g., bulk edit, export config):

```yaml
# config/lcp_ruby/models/bulk_status_change.yml
name: bulk_status_change
table_name: _virtual          # no DB table, form-only

fields:
  - name: new_status
    type: enum
    values: [open, in_progress, closed]
    required: true
  - name: comment
    type: text
  - name: notify_assignees
    type: boolean
    default: true
```

### 3. Presenter (dialog mode)

```yaml
# config/lcp_ruby/presenters/save_filter_dialog.yml
slug: save-filter-dialog
model: saved_filter
mode: dialog                    # NEW — renders in modal, not full page

dialog:
  size: medium                  # small | medium | large | fullscreen
  submit_action: save           # which action triggers on submit
  cancel_closes: true           # ESC / overlay click closes

sections:
  - name: main
    fields:
      - name
      - description
      - visibility
      - target_role:
          visible_when:
            field: visibility
            operator: eq
            value: role
      - target_group:
          visible_when:
            field: visibility
            operator: eq
            value: group
  - name: options
    fields:
      - pinned
      - default_filter

actions:
  - name: save
    type: custom
    handler: SaveFilterAction   # existing action system
    style: primary
  - name: cancel
    type: built_in
    behavior: close_dialog      # NEW built-in behavior
```

### 4. Trigger (from another presenter)

```yaml
# In deals presenter (index page)
actions:
  - name: save_filter
    type: dialog                # NEW action type
    icon: save
    dialog:
      presenter: save-filter-dialog
      # optional: pre-fill data
      defaults:
        visibility: personal
    # what happens after successful submit:
    on_success: reload          # reload | close | redirect | callback
```

### 5. Quick create (real model in a dialog)

```yaml
# contacts presenter - index page action
actions:
  - name: quick_add_contact
    type: dialog
    label: "Quick Add"
    dialog:
      presenter: contact-quick-form   # separate presenter for the same model
      on_success: reload

# config/lcp_ruby/presenters/contact-quick-form.yml
slug: contact-quick-form
model: contact                 # real model, not virtual
mode: dialog
dialog:
  size: small
  submit_action: create        # built-in CRUD

sections:
  - name: main
    fields: [first_name, last_name, email, phone]
    # subset of fields — full form has 20 fields, dialog shows only 4
```

### 6. Confirmation dialog (minimal)

```yaml
actions:
  - name: destroy
    type: built_in
    confirm:                      # simplified dialog — no separate presenter needed
      title_key: confirm_delete
      message_key: confirm_delete_message
      style: danger
      # OR for complex confirmation:
      presenter: delete-confirmation-dialog
```

## General Implementation Approach

The dialog system reuses existing infrastructure with minimal additions:

1. **Render context**: The presenter renderer checks `mode: dialog` and wraps the output in a modal container (overlay + dialog chrome) instead of a full page layout. The form, fields, sections, and actions inside are rendered by the same helpers as full-page views.

2. **Virtual model instantiation**: For `table_name: _virtual` models, ModelFactory creates a lightweight ActiveModel-compliant object (not ActiveRecord) — with attribute accessors, validations, and type coercion, but no DB persistence. This object is what the form builder binds to.

3. **Dialog trigger**: A new action type `type: dialog` tells the frontend to fetch and render the dialog presenter via an AJAX/Turbo request instead of navigating. The response is the modal HTML which gets injected into the page.

4. **Submit flow**: Dialog form submits via fetch/Turbo to a dialog-aware endpoint. The endpoint runs validations, executes the configured action (create, update, custom), and returns success (close dialog + trigger `on_success`) or error (re-render form with errors inside the modal).

5. **Data passing**: The trigger can pass `defaults` (pre-fill values) and `context` (parent record ID, current filter state, selected record IDs for bulk operations) to the dialog presenter.

## Decisions

*(None yet — this is an initial brainstorm.)*

## Open Questions

### Q1: Virtual model scope — how "virtual"?

Today `_virtual` = no AR model at all. But a dialog form needs:
- Validations (already work via ModelDefinition)
- Attributes (getters/setters) — needs an object for form builder to call `.name`, `.visibility`
- Does NOT need `.save`, `.find`, DB table

Options:
- **(a)** Virtual model creates a lightweight ActiveModel object (not ActiveRecord) — validations work, no DB
- **(b)** Virtual model is a hash wrapper (like existing `JsonItemWrapper`) — simpler but fewer features
- **(c)** Virtual model is a full AR with in-memory SQLite table — overkill?

### Q2: One model, multiple presenters — dialog vs page?

A contact has 20 fields. Full-page form shows all 20. "Quick Add" dialog shows 4. This is just a different presenter for the same model — that already works today. But how to distinguish?
- **(a)** `mode: dialog` on the presenter — simple flag
- **(b)** View group with `display: dialog` — dialog is just another "view" of the same model
- **(c)** Presenter is just a presenter, the render context is determined by the caller (action)

### Q3: Submit behavior — who controls what happens after submit?

- **(a)** Dialog presenter defines `on_submit` (create/update/custom action)
- **(b)** Trigger action defines `on_success` (reload/close/redirect)
- **(c)** Both — presenter says *what* to execute, trigger says *what happens next*

### Q4: Nesting — dialog from dialog?

User opens "New Invoice" → clicks "Add Contact" → nested dialog opens. Support this? Stacking? Or max 1 level?

### Q5: Record picker as a special dialog?

Record picker (advanced association select) is essentially a `mode: dialog` presenter with an `index` view instead of a `form` view. It has a selection mode (single/multi select) and returns selected records. Is it:
- **(a)** A special dialog type (`mode: picker`)
- **(b)** A normal dialog with index view and `select_mode: true`
- **(c)** A completely different mechanism (not a dialog)
