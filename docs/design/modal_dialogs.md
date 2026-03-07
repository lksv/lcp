# Feature Specification: Modal Dialogs

**Status:** Tier 1 Implemented
**Date:** 2026-03-03
**Updated:** 2026-03-07 (Tier 1 complete: dialog rendering, confirm dialogs, saved filter dialog)

## Problem / Motivation

Currently, modal dialogs in LCP (e.g., saved filter save dialog) are hardcoded ERB partials with hand-written HTML and JavaScript. This contradicts the platform's core principle: everything should be driven by YAML/DSL metadata.

The goal is that **every modal dialog is a page rendered in a modal context** — the same model/presenter/permission system that drives full pages also drives dialogs. This applies to both built-in dialogs (saved filters, confirmations, quick create) and user-defined dialogs.

## Core Concept

**Dialog = page rendered in a modal layout instead of a full-page layout.** The rendering pipeline is identical — the only difference is the layout wrapper (modal chrome vs. full page chrome).

This builds on the [Pages](composite_pages_v2.md) abstraction:

```
View Group  — WHERE (menu, breadcrumbs)
  └── Page  — HOW (zones, spatial layout)     ← dialog opens a page
        └── Presenter(s)  — WHAT (fields, sections, actions)
```

Every presenter has a page (auto-created for simple cases). A dialog action opens that page in a modal. No new abstractions needed — dialog is just a rendering context.

**What already exists and works:**
- **Virtual models** (`table_name: _virtual`) — metadata without a DB table
- **Real models** — standard DB-backed models (e.g., saved filters)
- **Presenters** — layout, fields, sections, conditional rendering
- **Pages** — auto-created from presenters, carry slug and dialog config
- **Actions** — trigger point for opening dialogs
- **Permissions** — who can open / submit a dialog
- **Events** — what happens after submit
- **Condition evaluator** — `visible_when`, `disable_when` inside dialogs
- **JsonItemWrapper** — ActiveModel wrapper with validations and type coercion for virtual models

**What is new:**
1. **Dialog rendering context** — page renders inside modal chrome (overlay, header, footer)
2. **Dialog trigger** — new action type `dialog` in `ActionSet` (alongside existing `built_in` and custom types). Opens a page in a modal via Turbo. Replaces `BaseAction#param_schema` for cases needing full presenter-driven forms
3. **Dialog response format** — controller returns Turbo Stream for success (close) / error (re-render)
4. **Dialog lifecycle** — open → fill → validate → submit → success/error → close/stay
5. **Dialog routing** — `/lcp_dialog/:page_name/*` routes for slugless (dialog-only) pages; routable pages reuse `/:lcp_slug/*` with `?_dialog=1`
6. **Virtual model controller branch** — `set_presenter_and_model` must handle `@model_class = nil` for virtual models; `new`/`create` actions use `JsonItemWrapper` instead of AR records

## User Scenarios

### Tier 1 (MVP)

| # | Dialog | Data source | Example |
|---|--------|------------|---------|
| 1 | **Save filter** | real model | Save current filter with name, visibility, pinning |
| 2 | **Delete confirmation** | no model (lightweight) | "Are you sure you want to delete?" |
| 3 | **Quick create** | real model | "Add contact" without leaving the page |
| 4 | **Quick edit** | existing record | Edit in a modal |
| 5 | **Bulk edit params** | virtual model | "Set status=closed for 15 records" |
| 6 | **Custom action input** | virtual model | "Reassign to user" → user picker |
| 7 | **Workflow transition** | virtual model | "Approve order" — requires comment |

### Tier 2

| # | Dialog | Example |
|---|--------|---------|
| 8 | **Quick view** | Detail preview without navigation |
| 9 | **Nested form** | Add invoice line from a modal |
| 10 | **Note / comment** | "Add internal note" to a record |

### Tier 3+

| # | Dialog | Example |
|---|--------|---------|
| 11 | **Record picker** | Advanced association select with filters (index in modal) |
| 12 | **Multi-step wizard** | Employee onboarding (3 steps) |
| 13 | **Import** | CSV/Excel import with file upload + mapping |
| 14 | **Composite dialog** | Multi-zone dialog (e.g., transfer: source preview + form) |

## Configuration & Behavior

### Dialog-only presenter (most common case)

A presenter without a slug creates a dialog-only auto-page. The `dialog:` key on the presenter provides defaults for modal rendering:

```yaml
# config/lcp_ruby/presenters/save_filter_dialog.yml
presenter:
  name: save_filter_dialog
  model: saved_filter
  # no slug → auto-page has no route → dialog-only
  dialog:
    size: medium

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
```

The system auto-creates a page from this presenter:

```
PageDefinition(
  name: "save_filter_dialog",
  model: "saved_filter",
  slug: nil,                          ← not routable
  dialog: { size: "medium" },         ← copied from presenter
  zones: [{ name: "main", presenter: "save_filter_dialog", area: "main" }]
)
```

### Dialog trigger — action type `dialog`

An action with `type: dialog` opens a page in a modal. This is a **new action type** for `ActionSet` (alongside `built_in` and custom types):

```yaml
# In deals presenter (index page)
actions:
  collection:
    - name: save_filter
      type: dialog
      icon: save
      dialog:
        page: save_filter_dialog       # references the auto-page by name
        defaults:                       # pre-fill form values
          visibility: personal
        on_success: reload              # what happens in parent after close
```

**Authorization:** `ActionSet#filter_actions` must handle the new type. Dialog actions are authorized by checking `can_access_presenter?(dialog_page.main_zone.presenter_name)` — if the user can't access the dialog's presenter, the action button is hidden. This is different from `built_in` (which checks `can?(action_name)`) and custom actions (which check `can_execute_action?(action_name)`).

**Quick edit dialog** (opening an existing record in a modal):

```yaml
actions:
  single:
    - name: quick_edit
      type: dialog
      dialog:
        page: contact_quick_form
        record: :current               # use the current record (from single action context)
        on_success: reload
```

The `record: :current` tells the trigger to open `/:lcp_slug/:id/edit?_dialog=1` (or `/lcp_dialog/:page_name/:id/edit`) with the action's target record ID. Without `record:`, the dialog opens `new` (create mode).

### Quick create (real model in dialog)

```yaml
# contacts presenter - index page action
actions:
  collection:
    - name: quick_add_contact
      type: dialog
      label: "Quick Add"
      dialog:
        page: contact_quick_form
        on_success: reload

# config/lcp_ruby/presenters/contact_quick_form.yml
presenter:
  name: contact_quick_form
  model: contact                       # real model, not virtual
  # no slug → dialog-only
  dialog:
    size: small

  sections:
    - name: main
      fields: [first_name, last_name, email, phone]
      # subset of fields — full form has 20 fields, dialog shows only 4
```

### Dual-use presenter (page AND dialog)

A presenter with both a slug and `dialog:` defaults works as a full page (via URL) and as a dialog (via action):

```yaml
presenter:
  name: contact_edit
  model: contact
  slug: contacts               # routable as full page
  dialog:
    size: medium               # defaults when opened as dialog

  sections:
    - name: main
      fields: [first_name, last_name, email, phone, company_id, notes]
```

```yaml
# From deals page — open contact edit as dialog
actions:
  single:
    - name: edit_contact
      type: dialog
      dialog:
        page: contact_edit       # same page, rendered in modal
        size: large              # override default size for this context
        on_success: reload
```

### Virtual model dialog (no persistence)

```yaml
# config/lcp_ruby/models/bulk_status_change.yml
name: bulk_status_change
table_name: _virtual

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

```yaml
# config/lcp_ruby/presenters/bulk_status_change_dialog.yml
presenter:
  name: bulk_status_change_dialog
  model: bulk_status_change
  dialog:
    size: small

  sections:
    - name: main
      fields: [new_status, comment, notify_assignees]
```

The virtual model creates a `JsonItemWrapper`-based ActiveModel object with validations and type coercion. The form builder binds to it the same way as a real model.

Virtual models need a permission file to control access:

```yaml
# config/lcp_ruby/permissions/bulk_status_change.yml
permissions:
  model: bulk_status_change
  roles:
    admin:
      crud: [create]
      presenters: all
    manager:
      crud: [create]
      presenters: [bulk_status_change_dialog]
```

The `crud: [create]` permission is required because the dialog submit triggers the `create` action flow. Without a permission file, the default permission definition applies (which may deny access).

### Confirmation dialog (lightweight — no page needed)

Simple confirmations don't need a model, presenter, or page. They use the `confirm:` key directly on the action:

```yaml
actions:
  single:
    - name: destroy
      type: built_in
      confirm:
        title_key: confirm_delete
        message_key: confirm_delete_message
        style: danger

    # For complex confirmations with a form (e.g., deletion reason):
    - name: destroy_with_reason
      type: built_in
      confirm:
        page: delete_reason_dialog     # full presenter-driven dialog
```

**Compatibility with existing `confirm:` format:** Today, `ActionSet#resolve_confirm` handles `confirm: true`, `confirm: { except: [roles] }`, and `confirm: { only: [roles] }` for role-based confirmation toggling. The new hash format (`confirm: { title_key:, message_key:, style: }`) extends this — the resolver detects the shape:

| `confirm:` value | Behavior |
|-----------------|----------|
| `true` | Browser `confirm()` (today) → styled modal (after migration) |
| `{ except: [...] }` / `{ only: [...] }` | Role-based toggle, existing behavior unchanged |
| `{ title_key:, message_key:, style: }` | Styled confirmation modal with i18n text (new) |
| `{ page: ... }` | Full presenter-driven confirmation dialog (new) |

The resolver distinguishes formats by checking for the presence of `title_key`/`message_key` (styled confirmation) or `page` (full dialog) keys. Existing role-based format is unaffected.

### Dialog config properties

The `dialog:` key on a page (or presenter, copied to auto-page) contains only modal rendering properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `size` | `small` / `medium` / `large` / `fullscreen` | `medium` | Modal width |
| `closable` | boolean | `true` | Whether ESC / overlay click closes the dialog |
| `title_key` | string | presenter label | i18n key for dialog title |

Submit behavior (`on_success`) belongs to the **caller** (action), not the dialog definition.

**Resolution priority:** action `dialog:` override > page `dialog:` config > system defaults.

### `on_success` taxonomy

`on_success` is a sibling key to `page` inside the `dialog:` block:

| `on_success` value | Behavior | Context |
|--------------------|---------|---------|
| `reload` | Reload current page | Universal |
| `close` | Close dialog, do nothing | Universal |
| `redirect` | Navigate to URL (requires `redirect_to:` sibling key) | Universal |
| `reload_zone` | Refresh the zone that triggered the dialog | Composite page (Tier 2) |
| `reload_zones` | Refresh specific zones (requires `reload_zones: [a, b]` sibling key) | Composite page (Tier 2) |

Example with `reload_zones`:

```yaml
dialog:
  page: order_line_form
  on_success: reload_zones
  reload_zones: [order_lines, order_summary]
```

### Context passing

The trigger action can pass context to the dialog:

```yaml
dialog:
  page: order_line_form
  defaults:                          # pre-fill form values
    order_id: :record_id             # dynamic — resolved from current record
    status: draft                    # static value
  context:                           # metadata (not form values)
    selected_ids: :batch_selection   # for bulk operations
    source_presenter: :current       # for back-navigation
```

**Reference resolution:** Dynamic references (`:record_id`, `:record.field`, `:batch_selection`) use the same reference resolution layer described in the [Pages spec — scope_context](composite_pages_v2.md#context-passing--scope_context). Static values (e.g., `draft`) are passed as-is. Resolved values are sent as query params (`?defaults[order_id]=42&defaults[status]=draft`) on the dialog GET request.

## General Implementation Approach

### Submit flow — two routing paths

Dialogs use two routing paths depending on whether the page has a slug:

```
Routable pages (has slug) — reuses existing ResourcesController:
  GET  /:lcp_slug/new?_dialog=1      → #new, form in modal layout
  POST /:lcp_slug?_dialog=1          → #create, Turbo Stream response
  GET  /:lcp_slug/:id/edit?_dialog=1 → #edit, form in modal layout
  PATCH /:lcp_slug/:id?_dialog=1     → #update, Turbo Stream response

Slugless pages (dialog-only) — dedicated DialogsController:
  GET  /lcp_dialog/:page_name/new          → #new, form in modal layout
  POST /lcp_dialog/:page_name              → #create, Turbo Stream response
  GET  /lcp_dialog/:page_name/:id/edit     → #edit
  PATCH /lcp_dialog/:page_name/:id         → #update
```

`DialogsController` resolves the page by **name** (not slug), loads the page's presenter and model, and renders the form in the modal layout. It shares the same CRUD logic as `ResourcesController` via a shared concern — the only difference is page resolution and response format (always Turbo Stream).

The controller detects dialog context via `_dialog=1` param (routable) or controller type (DialogsController) and adjusts the response:

```ruby
def create
  # ... existing CRUD logic (unchanged) ...
  if @record.save
    if dialog_context?
      render turbo_stream: [
        turbo_stream.action(:close_dialog),
        turbo_stream.action(:trigger_success, on_success_config)
      ]
    else
      redirect_to resource_path(@record)  # existing behavior
    end
  else
    if dialog_context?
      render turbo_stream: turbo_stream.replace(
        "dialog-content",
        partial: "lcp_ruby/resources/form",
        locals: { record: @record }
      )
    else
      render :new  # existing behavior
    end
  end
end
```

No duplicated CRUD logic. Dialog is a response branch in ResourcesController and the only path in DialogsController.

### Dialog trigger (client-side)

Action buttons with `type: dialog` use Turbo to fetch and display the modal:

1. User clicks action button → JS intercepts click
2. GET request:
   - Routable page: `/:lcp_slug/new?_dialog=1&defaults[visibility]=personal`
   - Slugless page: `/lcp_dialog/:page_name/new?defaults[visibility]=personal`
3. Server renders presenter form wrapped in modal chrome partial
4. Response injected into a `<turbo-frame id="dialog">` container in the layout
5. Modal overlay shown, form is interactive
6. User fills form and submits → standard form POST
7. Turbo Stream response: close modal OR re-render with errors

The JS trigger logic reads the page name from the action config and builds the appropriate URL. For routable pages, it uses the page's slug; for slugless pages, it uses the `/lcp_dialog/` prefix.

### Virtual model handling

Virtual models (`table_name: _virtual`) are never registered in `LcpRuby.registry` — the engine skips them at boot (no AR class, no DB table). The standard controller setup (`registry.model_for(name)`) raises for virtual models.

**Controller setup must branch for virtual models:**

```ruby
def set_presenter_and_model
  # ... resolve page and presenter from slug/page_name ...
  @model_definition = LcpRuby.loader.model_definition(@presenter_definition.model)

  if @model_definition.virtual?
    @model_class = nil  # no AR class for virtual models
  else
    @model_class = LcpRuby.registry.model_for(@presenter_definition.model)
  end
end
```

**Form rendering** — `JsonItemWrapper` instead of an AR record:

```ruby
def new
  if current_model_definition.virtual?
    @record = JsonItemWrapper.new(defaults_from_params, current_model_definition)
  else
    @record = @model_class.new(defaults_from_params)
  end
  # ... same render logic
end
```

`JsonItemWrapper` already provides ActiveModel compliance (validations, type coercion, getters/setters). No new infrastructure needed.

**Submit** — the controller calls the custom action with the wrapper's data instead of `.save`:

```ruby
def create
  if current_model_definition.virtual?
    @record = JsonItemWrapper.new(permitted_params, current_model_definition)
    @record.validate_with_model_rules!
    if @record.errors.empty?
      # Execute the custom action with the virtual record's data
      result = execute_action_with(@record)
      handle_dialog_success(result)
    else
      handle_dialog_error(@record)
    end
  else
    # existing create logic
  end
end
```

**Pundit authorization** — Virtual models have no AR class for Pundit policy lookup. Authorization relies on action-level permission checks (`can_execute_action?`) rather than model-level Pundit policies. See [Pages spec, Open Question #8](composite_pages_v2.md#open-questions).

### Modal chrome rendering

The modal is rendered as a wrapper around the existing form/show partials:

```erb
<%# app/views/lcp_ruby/shared/_dialog.html.erb %>
<div class="lcp-dialog-overlay" data-action="close-dialog">
  <div class="lcp-dialog lcp-dialog-<%= dialog_size %>">
    <div class="lcp-dialog-header">
      <h3><%= dialog_title %></h3>
      <% if dialog_closable? %>
        <button class="lcp-dialog-close" data-action="close-dialog">&times;</button>
      <% end %>
    </div>
    <div class="lcp-dialog-body" id="dialog-content">
      <%= yield %>
    </div>
  </div>
</div>
```

The same `_form.html.erb` partial renders inside the dialog body. No duplication of form rendering logic.

## Decisions

### D1: Dialog always opens a page

Dialog trigger references a page (auto or explicit) via `page:` key. Every presenter has an auto-page. No need for separate `presenter:` vs `page:` distinction in the trigger — always `page:`. See [Pages spec](composite_pages_v2.md) for the auto-page mechanism.

### D2: Dialog config lives on the page, not the caller

The `dialog:` key on the presenter (copied to auto-page) provides defaults (size, closable, title). This eliminates duplication when multiple actions open the same dialog. Callers can override individual properties.

### D3: Caller owns `on_success`

What happens in the parent context after a dialog closes (reload, redirect, refresh zone) is the caller's concern, not the dialog's. The dialog doesn't know where it was opened from.

### D4: Dialogs reuse existing CRUD logic

Routable pages use `ResourcesController` with `_dialog=1` param. Slugless (dialog-only) pages use `DialogsController` that shares the same CRUD logic via a concern. Zero logic duplication — dialog is a response branch, not a new operation.

### D5: Lightweight confirmations are a special case

Simple "Are you sure?" confirmations use `confirm:` on the action — no model, no presenter, no page. Just text + buttons rendered as a minimal modal. Complex confirmations with form fields use a full presenter dialog via `confirm: { page: ... }`.

### D6: Virtual models use JsonItemWrapper

No new ActiveModel infrastructure. `JsonItemWrapper` already provides validations, type coercion, and ActiveModel compliance. Virtual model dialog forms bind to `JsonItemWrapper` instances.

### D7: No nesting in Tier 1

Dialog-from-dialog (e.g., "New Invoice" → "Add Contact") is not supported in Tier 1. Maximum one dialog level. Nesting support (stacking, z-index management, focus trapping) is a Tier 2 enhancement.

### D8: Record picker is a separate feature

Record picker (index-in-modal with selection) shares modal infrastructure but has distinct UX (search, filter, select, return selected IDs). It is not a form dialog. Deferred to Tier 3 with its own design.

### D9: Dialog actions are authorized via presenter access

`type: dialog` actions in `ActionSet` are authorized by checking `can_access_presenter?` on the dialog page's main zone presenter. This means:
- **Real model dialogs** — the user must have access to the dialog presenter (checked via the model's permission YAML `presenters:` key).
- **Virtual model dialogs** — the virtual model must have a permissions YAML file. The `presenters:` key in that file controls who can access the dialog presenter. If no permission file exists for the virtual model, the default permission definition applies.
- The **action that opens the dialog** controls visibility (via `visible_when`). The **dialog's permission definition** controls access (via `presenters:` list).

### D10: `type: dialog` replaces `param_schema` for complex forms

`BaseAction#param_schema` provides a simple mechanism for showing a form before action execution. `type: dialog` replaces it for cases that need full presenter-driven forms (conditional rendering, multiple sections, virtual model validation, etc.). `param_schema` remains available for simple cases (a few text inputs before a custom action) and is not deprecated.

## Tiered Delivery

**Tier 1 (MVP):**
- Auto-pages from presenters (internal concept from Pages spec)
- Action `type: dialog` opens auto-page in modal layout (new action type in ActionSet)
- Two routing paths: `/:lcp_slug/*?_dialog=1` for routable pages, `/lcp_dialog/:page_name/*` for slugless pages
- Submit via existing CRUD logic with Turbo Stream responses (shared concern between ResourcesController and DialogsController)
- Lightweight `confirm:` on actions (text-only, no page)
- `dialog:` defaults on presenter (new `PresenterDefinition` attribute; size, closable, title)
- Virtual model dialog forms via `JsonItemWrapper` (controller branches for `@model_class = nil`)
- `on_success: reload | close | redirect`
- Data passing: `defaults` for pre-fill values
- Replace hardcoded saved filter dialog with presenter-driven dialog
- Replace browser `confirm()` with styled modal confirmation

**Tier 2:**
- Quick edit / quick view (existing record in dialog)
- Dialog nesting (max 2 levels)
- `on_success: reload_zone` / `reload_zones` (composite page integration)
- Context passing: `selected_ids` for bulk operations
- Batch action parameter dialogs (replace `param_schema` modals)

**Tier 3:**
- Composite dialog pages (multi-zone modals, see [Pages spec](composite_pages_v2.md))
- Record picker (index-in-modal with selection mode)
- Multi-step wizard dialogs
- Import dialog (file upload + column mapping)

## Usage Examples

### Replacing the hardcoded saved filter dialog

Before (hardcoded ERB):
```erb
<%# _saved_filter_save_dialog.html.erb — 83 lines of hand-written HTML %>
<div class="lcp-save-dialog" id="lcp-save-filter-dialog" style="display: none;">
  ...hand-written form with manual visibility toggling...
</div>
```

After (YAML-driven):
```yaml
# Model already exists (saved_filter from generator)

# Presenter — dialog-only
presenter:
  name: save_filter_dialog
  model: saved_filter
  dialog:
    size: medium
  sections:
    - name: main
      fields:
        - name
        - description
        - visibility
        - target_role:
            visible_when: { field: visibility, operator: eq, value: role }
        - target_group:
            visible_when: { field: visibility, operator: eq, value: group }
        - pinned
        - default_filter

# Trigger — from any presenter with saved filters enabled
actions:
  collection:
    - name: save_filter
      type: dialog
      icon: save
      dialog:
        page: save_filter_dialog
        on_success: reload
```

The same `visible_when` conditions, the same fields, the same model — but now driven by the platform's standard rendering pipeline. No custom HTML, no custom JavaScript for visibility toggling.

### Workflow transition dialog

```yaml
# Virtual model — no DB table
name: approval_decision
table_name: _virtual
fields:
  - name: decision
    type: enum
    values: [approve, reject, return_for_revision]
    required: true
  - name: comment
    type: text
    required: true
  - name: effective_date
    type: date
```

```yaml
# Presenter
presenter:
  name: approval_dialog
  model: approval_decision
  dialog:
    size: small
  sections:
    - name: main
      fields: [decision, comment, effective_date]
```

```yaml
# Trigger from order presenter
actions:
  single:
    - name: approve
      type: dialog
      icon: check
      visible_when:
        field: status
        operator: eq
        value: pending_approval
      dialog:
        page: approval_dialog
        on_success: reload
```

### Bulk status change

```yaml
# Trigger from batch actions
actions:
  batch:
    - name: change_status
      type: dialog
      label: "Change Status"
      icon: pencil
      dialog:
        page: bulk_status_change_dialog
        on_success: reload
```

The batch action controller passes `selected_ids` as context. The custom action handler receives both the virtual model data (new_status, comment) and the selected record IDs.
