# Conditional Rendering

Conditional rendering allows showing/hiding or enabling/disabling form fields, form sections, and action buttons based on field values or custom service logic. There are two condition forms: field-value conditions (evaluated client-side with JavaScript) and service conditions (evaluated server-side and re-evaluated via AJAX).

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

## Client-Side Behavior

Field-value conditions are evaluated client-side with vanilla JavaScript:

- Conditions re-evaluate on every `change` and `input` event
- No page reload needed -- updates are instant
- Uses standard DOM queries (`[name$="[field_name]"]`) to read current values
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
