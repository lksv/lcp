# Feature Specification: Modal Dialogs (Self-Hosted)

**Status:** Proposed
**Date:** 2026-03-03

## Problem / Motivation

Currently, modal dialogs in LCP (e.g., saved filter save dialog) are hardcoded ERB partials with hand-written HTML and JavaScript. This contradicts the platform's core principle: everything should be driven by YAML/DSL metadata.

The goal is that **every modal dialog is a presenter rendered in a modal context** — the same model/presenter/permission system that drives full pages also drives dialogs. This applies to both built-in dialogs (saved filters, confirmations, quick create) and user-defined dialogs.

## Core Concept

**Dialog = presenter rendered in a modal context instead of a full page.** The render context (page vs dialog) is a separate concern from the presenter content (fields, sections, actions).

Key terminology:
- **Presenter** = one specific UI variant of a model. Defines *what* is rendered: fields, sections, layout, actions, permissions linkage.
- **View Group** = navigational-organizational layer above presenters. Defines *where* and *how* presenters are accessed: grouping, default presenter, menu position, breadcrumb, view switcher.

The open question is **where the "render as dialog" responsibility belongs** — see [Q2: Render context ownership](#q2-render-context-ownership--where-does-display-dialog-live).

```
┌─────────────────────────────────────────────────┐
│  Existing LCP concepts        New concept        │
│                                                   │
│  Model (real / virtual)  ─┐                       │
│  Presenter (fields,       ├──▶  Dialog            │
│    sections, actions)    ─┘    (= render context) │
│  View Group (navigation,  ────▶  (candidate owner)│
│    switcher, display)                              │
│  Permissions             ─────▶  (reuse as-is)    │
│  Actions (trigger)       ─────▶  (trigger source) │
│  Events (on_submit)      ─────▶  (reuse as-is)    │
└─────────────────────────────────────────────────┘
```

What already exists and works:
- **Virtual models** (`table_name: _virtual`) — metadata without a DB table
- **Real models** — standard DB-backed models (e.g., saved filters)
- **Presenters** — layout, fields, sections, conditional rendering
- **View Groups** — presenter grouping, navigation, breadcrumb, view switcher
- **Actions** — trigger point for opening dialogs
- **Permissions** — who can open / submit a dialog
- **Events** — what happens after submit
- **Condition evaluator** — `visible_when`, `disable_when` inside dialogs

What is **new**:
1. **Render context** — something determines the presenter renders as a dialog (not a full page)
2. **Dialog trigger** — action/button knows to open a dialog (not navigate)
3. **Submit behavior** — split into two parts (see [Q3](#q3-submit-behavior--who-controls-what-happens-after-submit))
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

### D1: Submit behavior is split between presenter and caller

Submit has two distinct concerns with different owners:

| Concern | Owner | Mechanism |
|---------|-------|-----------|
| **What operation** (create, update, custom action) | **Presenter** | Existing `redirect_after` + actions. `redirect_after: { create: close }` where `close` is a new redirect target value |
| **What happens in parent context after dialog closes** (reload parent page, redirect, callback) | **Caller** (trigger action) | `on_success: reload` on the action that opens the dialog |

This mirrors the existing architecture: the presenter already defines actions and `redirect_after`, the caller already defines navigation intent. Dialog just adds `close` as a new redirect target.

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

### Q2: Render context ownership — where does `display: dialog` live?

The central design question. A presenter can render as a full page or as a modal dialog. Who decides? Two variants under consideration:

#### Variant A: View Group owns it (`display: dialog` on view group)

View group gets a `display: dialog | page` attribute (default `page`). Presenter stays pure — defines what to render. View group says where/how.

```yaml
# View group — optional, auto-created if missing
view_group:
  name: contact_dialogs
  model: contact
  display: dialog
  navigation: false
  dialog:
    size: medium
  views:
    - presenter: contact_quick_form
    - presenter: contact_full_form

# Presenter — no dialog knowledge
presenter:
  name: contact_quick_form
  model: contact
  redirect_after: { create: close }
  sections:
    - name: main
      fields: [first_name, last_name, email]

# Caller action — knows what happens in parent context
actions:
  - name: quick_add
    type: dialog
    dialog:
      presenter: contact_quick_form
      on_success: reload
```

**Pro:**
- Clean separation: presenter = what, view group = where/how — matches existing architecture
- Presenter stays a pure UI variant, reusable in both page and dialog contexts
- View switcher inside dialogs works naturally (same concept, different display)
- Auto-creation covers simple cases — no view group file needed for single-presenter dialogs
- Future render modes (drawer, sidebar, embedded) are just new `display:` values, no presenter changes
- Discoverability — grep `display: dialog` in view groups to find all dialogs
- Navigation, breadcrumb, switcher logic already lives in view groups — dialog is just another context

**Contra:**
- Dialog size lives in view group, fields live in presenter — two files to understand a dialog (but same as page presenters today: navigation in view group, layout in presenter)
- If two presenters in the same dialog view group need different sizes, per-view overrides are needed:
  ```yaml
  views:
    - presenter: quick_form
      dialog: { size: small }
    - presenter: full_form
      dialog: { size: large }
  ```
- One presenter in two view groups (page + dialog) requires relaxing the current "one view group per presenter" validation rule — new rule: "at most one view group per display type"
- Auto-creation needs new logic: how does the engine know a presenter is "dialog-intended" if there's no explicit view group? Needs a signal (e.g., no `slug`, or explicit `dialog:` key on presenter)

#### Variant B: Caller owns it (trigger action determines render context)

Presenter is completely agnostic. The action that invokes it decides the render context.

```yaml
# Presenter — no dialog knowledge, no mode
presenter:
  name: contact_quick_form
  model: contact
  redirect_after: { create: close }
  sections:
    - name: main
      fields: [first_name, last_name, email]

# Caller action — decides everything about the dialog context
actions:
  - name: quick_add
    type: dialog
    dialog:
      presenter: contact_quick_form
      size: medium
      on_success: reload
```

No view group involvement. The dialog concept doesn't exist as a first-class entity — it's just an action render mode.

**Pro:**
- Maximum reuse — same presenter works as full page (via URL/view group) and as dialog (via action), zero duplication, zero extra config
- Minimal schema changes — no new concepts on presenter or view group, only a new action type
- Clean separation: presenter = what, action = how to invoke
- Per-caller customization is natural — same dialog opened from deals page is `size: medium`, from contacts page is `size: large`, no overrides needed
- No view group validation changes needed
- No auto-creation logic changes needed
- Simple mental model: "an action can navigate to a page, or open a presenter in a dialog"

**Contra:**
- Dialog config (size, behavior) is scattered across every trigger — if 5 actions open `contact_quick_form` as a dialog, size is duplicated 5 times
- No single place to list "all dialogs in this app" — must grep all presenter actions for `type: dialog`
- No view switcher inside dialogs — without a view group there's no sibling set to switch between. Would need ad-hoc config:
  ```yaml
  dialog:
    presenter: contact_quick_form
    alternatives:
      - presenter: contact_full_form
        label: "Full"
  ```
  This reinvents view group structure inside the action
- Presenter can't adapt its own layout to the modal context (e.g., 2 columns on page, 1 column in dialog) — it doesn't know it's in a dialog
- Platform built-in dialogs (save filter, delete confirm) have no natural home — they're just actions with inline config, not discoverable as a concept

#### Side-by-side comparison

| Criterion | A: View Group | B: Caller |
|-----------|:-:|:-:|
| Separation of concerns | presenter=what, view group=how, caller=aftermath | presenter=what, caller=how+aftermath |
| Same presenter in page + dialog | yes (two view groups, one per display type) | yes (URL for page, action for dialog) |
| Simple cases (1 dialog, no view group) | auto-creation handles it | no extra files at all |
| View switcher inside dialog | natural (view group siblings) | must reinvent inside action config |
| Config duplication | dialog config in one view group, reused by all callers | each caller duplicates size, etc. |
| Discoverability | grep `display: dialog` in view groups | grep `type: dialog` across all actions |
| Presenter layout adaptation | presenter knows context via view group's `display` | presenter doesn't know it's in a dialog |
| Future render modes (drawer, sidebar) | new `display:` values | new action types or action options |
| Schema complexity | view group gets `display` + `dialog` keys | action gets `dialog` block |
| Built-in dialogs (save filter, confirm) | first-class view group entries | inline action config, no central definition |
| Validation / boot-time checks | can validate dialog view groups at boot | can only validate at action resolution time |

### Q3: Nesting — dialog from dialog?

User opens "New Invoice" → clicks "Add Contact" → nested dialog opens. Support this? Stacking? Or max 1 level?

### Q4: Record picker as a special dialog?

Record picker (advanced association select) is essentially a dialog presenter with an `index` view instead of a `form` view. It has a selection mode (single/multi select) and returns selected records. Is it:
- **(a)** A special dialog type (`mode: picker`)
- **(b)** A normal dialog with index view and `select_mode: true`
- **(c)** A completely different mechanism (not a dialog)
