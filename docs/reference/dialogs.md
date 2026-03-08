# Dialogs Reference

Dialogs are modal overlays that render a page's content inline without navigating away. They are used for quick create/edit forms, confirmation prompts, and virtual model workflows.

## Dialog Action Configuration

Actions with `type: dialog` open a page in a modal. Configured in presenter YAML under `actions:`.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | yes | Action identifier. |
| `type` | string | yes | Must be `dialog`. |
| `label` | string | no | Button label. |
| `icon` | string | no | Button icon. |
| `on` | string | no | `collection` (index toolbar) or `member` (per-row). |
| `dialog` | object | yes | Dialog configuration (see below). |

### Dialog Config Object

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `page` | string | yes | Page name to open. Must match a `PageDefinition` name. |
| `on_success` | string | no | Action after successful submit: `reload` (default), `close`, `redirect`, `confirm_action`. |
| `record` | string | no | Set to `current` for member actions that edit the clicked record. |
| `defaults` | object | no | Field defaults passed as query params to pre-populate the form. |

```yaml
actions:
  collection:
    - name: quick_add
      type: dialog
      label: Quick Add
      icon: plus
      dialog:
        page: employee_quick_add
        on_success: reload
        defaults:
          department_id: 42

  member:
    - name: quick_edit
      type: dialog
      label: Edit
      icon: pencil
      dialog:
        page: employee_quick_edit
        record: current
        on_success: reload
```

## Page `dialog:` Config Key

Pages that can be rendered as dialogs define their dialog properties in the page YAML.

```yaml
page:
  name: employee_quick_add
  dialog:
    size: large
    closable: false
    title_key: lcp_ruby.dialogs.quick_add_employee
  zones:
    - name: main
      presenter: employee_quick_form
```

See [Pages Reference](pages.md#dialog-configuration) for the full dialog config attributes.

## `on_success` Taxonomy

| Value | Behavior |
|-------|----------|
| `reload` | Reloads the current page (default). |
| `close` | Closes the dialog without reloading. |
| `redirect` | Navigates to a specified URL. |
| `confirm_action` | Submits the pending action with confirmation data (used with page-based confirms). |

## Confirm Dialog Variants

The `confirm:` key on actions controls confirmation behavior before the action executes.

### Simple Boolean

Standard browser-style confirmation.

```yaml
- name: destroy
  type: built_in
  confirm: true
```

### Role-Conditional

Only prompt specific roles. Other roles skip the confirmation.

```yaml
- name: destroy
  type: built_in
  confirm:
    only: [user, viewer]

# or exclude specific roles:
- name: archive
  type: custom
  confirm:
    except: [admin]
```

### Styled Confirmation

Custom title, message, and button style using a native `<dialog>` element.

```yaml
- name: deactivate
  type: custom
  confirm:
    title_key: lcp_ruby.confirm.deactivate_title
    message_key: lcp_ruby.confirm.deactivate_message
    style: danger
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `title_key` | string | i18n key for the dialog title. |
| `message_key` | string | i18n key for the confirmation message. |
| `style` | string | Button style class: `danger`, `warning`, `primary`. |

### Page-Based Confirmation

Opens a full page dialog for complex confirmations (e.g., requiring a reason).

```yaml
- name: delete_with_reason
  type: custom
  confirm:
    page: delete_reason_form
```

The confirmation page uses a virtual model (`table_name: _virtual`) for the reason form. On success, `on_success: confirm_action` submits the original action with `confirmation_data[...]` params.

## Dialog Routing

Dialogs are accessible through two routing paths:

### 1. Via Routable Page (query parameter)

For pages with a `slug:`, append `?_dialog=1` to render as a dialog:

```
GET  /:lcp_slug/new?_dialog=1          → new form in dialog
POST /:lcp_slug?_dialog=1              → create in dialog
GET  /:lcp_slug/:id/edit?_dialog=1     → edit in dialog
PATCH /:lcp_slug/:id?_dialog=1         → update in dialog
```

### 2. Via Dialog-Only Page (DialogsController)

For pages without a slug (dialog-only pages):

```
GET   /lcp_dialog/:page_name/new          → new form
POST  /lcp_dialog/:page_name              → create
GET   /lcp_dialog/:page_name/:id/edit     → edit form
PATCH /lcp_dialog/:page_name/:id          → update
```

## Virtual Model Dialog Flow

Virtual models (`table_name: _virtual` in model YAML) are metadata-only — no database table or ActiveRecord class is created.

When a dialog uses a virtual model:

1. Form data is wrapped in a `JsonItemWrapper` instance
2. Fields are validated via `validate_with_model_rules!` (presence, length, numericality, format)
3. On success: a `dialog_submit` event is dispatched with the wrapper as the record
4. Host app event handlers receive the form data and perform custom logic

```yaml
# Model (virtual)
model:
  name: feedback_form
  table_name: _virtual
  fields:
    - { name: message, type: text }
    - { name: rating, type: integer }
  validations:
    - { field: message, presence: true }
    - { field: rating, numericality: { greater_than: 0, less_than_or_equal_to: 5 } }

# Page (dialog-only)
page:
  name: feedback_dialog
  model: feedback_form
  dialog:
    size: medium
    title_key: lcp_ruby.dialogs.feedback
  zones:
    - name: main
      presenter: feedback_form
```

## Context Passing with `defaults:`

Dialog actions can pre-populate form fields using `defaults:`:

```yaml
dialog:
  page: quick_create_task
  defaults:
    project_id: 42
    priority: high
```

Defaults are passed as query parameters (`defaults[project_id]=42&defaults[priority]=high`) and applied to the new record instance. Only fields defined on the model are permitted.

## Authorization

Dialog actions are authorized through the dialog page's presenter and model:

1. The action's `dialog.page` is resolved to a `PageDefinition`
2. The page's main presenter determines the model context
3. A `PermissionEvaluator` checks `can_access_presenter?` for the dialog presenter
4. The dialog form respects field-level permissions (readable/writable fields)

This enables cross-model dialogs: an `orders` presenter can have a dialog action that opens an `order_item` form, with proper authorization for the target model.
