# Dialogs Guide

This guide walks through common dialog patterns: quick create, quick edit, virtual model dialogs, styled confirms, and page-based confirms.

## Quick Create Dialog

Open a create form in a modal from any presenter's index page.

### 1. Define the form presenter

```yaml
# config/lcp_ruby/presenters/contact_quick_form.yml
presenter:
  name: contact_quick_form
  model: contact
  dialog:
    size: medium
    title_key: lcp_ruby.dialogs.quick_create_contact
  form:
    sections:
      - title: "Basic Info"
        fields:
          - { field: first_name }
          - { field: last_name }
          - { field: email }
```

### 2. Add the dialog action to the parent presenter

```yaml
# config/lcp_ruby/presenters/contacts.yml
presenter:
  name: contacts
  model: contact
  slug: contacts
  actions:
    collection:
      - name: quick_add
        type: dialog
        label: Quick Add
        icon: plus
        dialog:
          page: contact_quick_form
          on_success: reload
```

The `contact_quick_form` presenter gets an auto-generated page (name = `contact_quick_form`) with dialog config inherited from the presenter. No explicit page YAML needed.

When the user clicks "Quick Add", a modal opens with the form. On successful save, the index page reloads.

## Quick Edit Dialog

Edit an existing record in a modal using `record: current`.

```yaml
# In the presenter with the list/table
actions:
  single:
    - name: quick_edit
      type: dialog
      label: Quick Edit
      icon: pencil
      dialog:
        page: contact_quick_form
        record: current
        on_success: reload
```

The `record: current` tells the dialog to load the clicked record's data into the edit form.

## Virtual Model Dialog

Virtual models (`table_name: _virtual`) are for dialogs that collect input without persisting to a database table. The form data is dispatched as a `dialog_submit` event to your event handler.

### 1. Define the virtual model

```yaml
# config/lcp_ruby/models/feedback_form.yml
model:
  name: feedback_form
  table_name: _virtual
  fields:
    - { name: message, type: text }
    - { name: rating, type: integer }
  validations:
    - { field: message, presence: true }
    - { field: rating, numericality: { greater_than: 0, less_than_or_equal_to: 5 } }
```

### 2. Define the presenter

```yaml
# config/lcp_ruby/presenters/feedback_form.yml
presenter:
  name: feedback_form
  model: feedback_form
  dialog:
    size: medium
    title_key: lcp_ruby.dialogs.feedback
  form:
    sections:
      - title: "Your Feedback"
        fields:
          - { field: message }
          - { field: rating }
```

### 3. Handle the event

```ruby
# app/event_handlers/feedback_submitted_handler.rb
class FeedbackSubmittedHandler
  def self.event_name
    "dialog_submit"
  end

  def self.handle(event)
    record = event[:record]
    # record.message, record.rating are available
    FeedbackMailer.new_feedback(
      message: record.message,
      rating: record.rating
    ).deliver_later
  end
end
```

### 4. Add the dialog action

```yaml
actions:
  collection:
    - name: feedback
      type: dialog
      label: Give Feedback
      icon: message-square
      dialog:
        page: feedback_form
        on_success: close
```

## Styled Confirmation Dialog

For destructive actions, use a styled confirm with custom title, message, and button color.

```yaml
actions:
  single:
    - name: deactivate
      type: custom
      label: Deactivate
      icon: x-circle
      style: danger
      confirm:
        title_key: lcp_ruby.confirm.deactivate_title
        message_key: lcp_ruby.confirm.deactivate_message
        style: danger
```

Add the translations:

```yaml
# config/locales/en.yml
en:
  lcp_ruby:
    confirm:
      deactivate_title: "Confirm Deactivation"
      deactivate_message: "This will deactivate the record and revoke all access. Continue?"
```

The `style: danger` renders the confirm button with a danger (red) styling.

## Page-Based Confirmation Dialog

When a confirmation needs user input (e.g., a reason for deletion), use a page-based confirm.

### 1. Define the reason model (virtual)

```yaml
# config/lcp_ruby/models/delete_reason.yml
model:
  name: delete_reason
  table_name: _virtual
  fields:
    - { name: reason, type: text }
    - { name: acknowledged, type: boolean }
  validations:
    - { field: reason, presence: true }
    - { field: acknowledged, presence: true }
```

### 2. Define the reason form presenter

```yaml
# config/lcp_ruby/presenters/delete_reason_form.yml
presenter:
  name: delete_reason_form
  model: delete_reason
  dialog:
    size: small
    title_key: lcp_ruby.confirm.delete_reason_title
  form:
    sections:
      - title: "Confirm Deletion"
        fields:
          - { field: reason }
          - { field: acknowledged }
```

### 3. Use in the action's confirm

```yaml
actions:
  single:
    - name: destroy
      type: built_in
      confirm:
        page: delete_reason_form
```

When the user clicks delete:
1. The confirmation dialog opens with the reason form
2. User fills in reason and acknowledges
3. On success (`on_success: confirm_action`), the original destroy action executes
4. The `confirmation_data[reason]` and `confirmation_data[acknowledged]` params are available in the action handler

## Dual-Use Presenter

A presenter can serve both as a regular routable page and as a dialog target. When the presenter has a `slug:`, it's navigable directly. When referenced by a dialog action, it opens in a modal.

```yaml
# config/lcp_ruby/presenters/task_form.yml
presenter:
  name: task_form
  model: task
  slug: task-form
  dialog:
    size: large
    title_key: lcp_ruby.dialogs.task
  form:
    sections:
      - title: "Task Details"
        fields:
          - { field: title }
          - { field: description }
          - { field: due_date }
```

This presenter:
- Navigable at `/task-form/new` and `/task-form/:id/edit` (full page)
- Opens at `/task-form/new?_dialog=1` (modal) when triggered by a dialog action

## Pre-Populating Fields with Defaults

Pass default values to pre-fill dialog form fields:

```yaml
actions:
  collection:
    - name: add_subtask
      type: dialog
      label: Add Subtask
      dialog:
        page: task_form
        on_success: reload
        defaults:
          parent_id: 42
          priority: high
```

The `defaults` are sent as query parameters and applied to the new record before the form renders. Only model-defined fields are permitted.
