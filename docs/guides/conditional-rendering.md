# Conditional Rendering

Conditional rendering allows showing/hiding or enabling/disabling form fields, form sections, show page sections, and action buttons based on field values or custom service logic. There are two condition forms: field-value conditions (evaluated client-side with JavaScript on forms, server-side on show pages) and service conditions (evaluated server-side and re-evaluated via AJAX on forms).

## Field-Level Conditions

### `visible_when`

Show or hide a form field based on a condition.

```yaml
fields:
  - field: contact_id
    input_type: association_select
    visible_when: { field: stage, operator: not_in, value: [lead] }
```

When the condition is false, the field renders with `display:none`. Values are preserved on form submit -- the field is hidden visually but remains in the DOM.

### `disable_when`

Disable a form field based on a condition.

```yaml
fields:
  - field: value
    input_type: number
    disable_when: { field: stage, operator: in, value: [closed_won, closed_lost] }
```

When the condition is true, the field gets `opacity: 0.6` and `pointer-events: none`. This uses CSS instead of the HTML `disabled` attribute so that values are still submitted with the form.

## Section-Level Conditions

Conditions can be applied to entire form sections (fieldsets). The section and all its fields are hidden or disabled together.

```yaml
sections:
  - title: "Metrics"
    visible_when: { field: stage, operator: not_eq, value: lead }
    fields:
      - { field: revenue }
      - { field: margin }
```

## Action Conditions

### Record Rules (Automatic)

Built-in `edit` and `destroy` actions are automatically hidden on the index page when [record_rules](../reference/permissions.md#record-rules) deny the corresponding CRUD operation. No `visible_when` needed in the presenter:

```yaml
# permissions/deal.yml — this is all you need
record_rules:
  - name: closed_deals_readonly
    condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

On the index page, sales reps will not see edit/destroy buttons on closed deals. Admins (excepted from the rule) still see them.

### `disable_when` on Actions

Actions support `disable_when` to prevent execution based on field values.

```yaml
actions:
  single:
    - name: close_won
      type: custom
      disable_when: { field: value, operator: blank }
```

When the condition is true, the action renders as `<span class="btn lcp-action-disabled">` instead of a clickable link.

## Service Conditions

For conditions that require server-side logic (database lookups, API calls, complex business rules), use service conditions instead of field-value conditions.

```yaml
fields:
  - field: description
    visible_when: { service: persisted_check }
```

Create a service class:

```ruby
# app/condition_services/persisted_check.rb
module LcpRuby
  module HostConditionServices
    class PersistedCheck
      def self.call(record)
        record.persisted?
      end
    end
  end
end
```

Register via auto-discovery in your initializer:

```ruby
LcpRuby::ConditionServiceRegistry.discover!(Rails.root.join("app").to_s)
```

Service conditions:

- Are evaluated server-side on initial page render
- Are re-evaluated via AJAX when form fields change (300ms debounce)
- Return a boolean: `true` means the condition is met, `false` means it is not

## Row-Scoped Conditions in Nested Fields

Conditions on fields inside `nested_fields` rows (both `association:` and `json_field:` sources) are evaluated against the **current row's data only**, not the parent record or other rows. This enables per-item conditional logic.

### Example

```yaml
form:
  sections:
    - title: "Line Items"
      type: nested_fields
      association: line_items
      columns: 4
      fields:
        - { field: item_type, input_type: select }
        - { field: description }
        - field: discount_percent
          input_type: number
          visible_when: { field: item_type, operator: eq, value: discount }
          hint: "Enter discount percentage"
        - field: notes
          visible_when: { field: item_type, operator: in, value: "service,discount" }
```

```ruby
nested_fields "Line Items", association: :line_items, columns: 4 do
  field :item_type, input_type: :select
  field :description
  field :discount_percent, input_type: :number,
    visible_when: { field: :item_type, operator: :eq, value: "discount" },
    hint: "Enter discount percentage"
  field :notes,
    visible_when: { field: :item_type, operator: :in, value: "service,discount" }
end
```

In this example, `discount_percent` only appears when the row's `item_type` is `"discount"`. Changing `item_type` in one row has no effect on other rows.

### How It Works

Each nested row renders with a `data-lcp-condition-scope` attribute. When evaluating conditions, the JavaScript looks for the closest `[data-lcp-condition-scope]` container and restricts field lookups to that container. If no scope container is found (standard forms), the entire `<form>` is searched — so this is fully backward-compatible.

After adding a new row (via the "Add" button), a synthetic `change` event is dispatched on the first input to trigger initial condition evaluation for the new row.

### Sub-section conditions

Sub-sections within nested rows also support `visible_when` and `disable_when`, evaluated against the row's data:

```yaml
sub_sections:
  - title: "Discount Details"
    visible_when: { field: item_type, operator: eq, value: discount }
    fields:
      - { field: discount_percent }
      - { field: discount_reason }
```

### Supported features in nested rows

Fields inside nested rows support the same rendering features as standard form fields:

| Feature | Standard form | Nested row |
|---------|--------------|------------|
| `visible_when` | Yes | Yes |
| `disable_when` | Yes | Yes |
| `col_span` | Yes | Yes |
| `hint` | Yes | Yes |
| `prefix`/`suffix` | Yes | Yes |
| `readonly` | Yes | Yes |

## Client-Side Behavior

Field-value conditions are evaluated client-side with vanilla JavaScript:

- Conditions re-evaluate on every `change` and `input` event
- No page reload needed -- updates are instant
- Uses standard DOM queries (`[name$="[field_name]"]`) to read current values, scoped to `[data-lcp-condition-scope]` when inside nested rows
- Handles checkboxes (Rails hidden+checkbox pattern), radio buttons, and selects

## Ruby DSL

The same conditions can be expressed using the presenter DSL:

```ruby
form do
  section "Details", visible_when: { field: :stage, operator: :not_eq, value: "lead" } do
    field :title
    field :contact_id, input_type: :association_select,
      visible_when: { field: :stage, operator: :not_in, value: [:lead] }
    field :value, input_type: :number,
      disable_when: { field: :stage, operator: :in, value: [:closed_won, :closed_lost] }
  end
end

action :close_won, type: :custom, on: :single,
  disable_when: { field: :value, operator: :blank }
```

## Show Page Conditions

Show page sections (both regular `section` and `association_list`) support `visible_when` and `disable_when`. Unlike form conditions which are evaluated client-side, show page conditions are evaluated **server-side only** — hidden sections are not rendered in the DOM at all (no JavaScript toggling needed).

```yaml
show:
  layout:
    - section: "Metrics"
      visible_when: { field: stage, operator: not_eq, value: lead }
      fields:
        - { field: priority }
        - { field: progress }
    - section: "Related Contacts"
      type: association_list
      association: contacts
      visible_when: { field: status, operator: eq, value: active }
```

Using the DSL:

```ruby
show do
  section "Metrics",
    visible_when: { field: :stage, operator: :not_eq, value: "lead" } do
    field :priority
    field :progress
  end

  association_list "Related Contacts", association: :contacts,
    visible_when: { field: :status, operator: :eq, value: "active" }
end
```

When `disable_when` evaluates to true, the section is rendered with a `lcp-conditionally-disabled` CSS class for visual styling.

Service conditions also work on show page sections:

```yaml
show:
  layout:
    - section: "Internal Notes"
      visible_when: { service: admin_only_check }
      fields:
        - { field: internal_notes }
```

## Operator Reference

See [Condition Operators](../reference/condition-operators.md) for the full list of supported operators (`eq`, `not_eq`, `in`, `not_in`, `gt`, `gte`, `lt`, `lte`, `present`, `blank`, `matches`, `not_matches`).

## Common Patterns

### Show payment details based on payment type

```yaml
- field: card_number
  visible_when: { field: payment_type, operator: eq, value: credit_card }
- field: bank_account
  visible_when: { field: payment_type, operator: eq, value: bank_transfer }
```

### Disable fields on closed records

```yaml
- field: amount
  disable_when: { field: status, operator: in, value: [closed, cancelled] }
```

### Show section only for specific types

```yaml
sections:
  - title: "Vehicle Details"
    visible_when: { field: asset_type, operator: eq, value: vehicle }
    fields:
      - { field: make }
      - { field: model }
      - { field: vin }
```

### Validate email format (visual feedback)

```yaml
- field: email
  disable_when: { field: email, operator: not_matches, value: "^[^@]+@[^@]+\\.[^@]+$" }
```
