# Conditional Rendering

Conditional rendering allows showing/hiding or enabling/disabling form fields, form sections, show page sections, and action buttons based on field values or custom service logic. Conditions range from simple field-value checks to compound logic with dynamic references, dot-path traversal, and collection quantifiers.

## Quick Reference

| Condition type | Example | Client-side? | Server-side? |
|---------------|---------|:------------:|:------------:|
| Simple field-value | `{ field: status, operator: eq, value: "active" }` | Yes | Yes |
| Compound (`all`/`any`/`not`) | `all: [{ field: ... }, { field: ... }]` | No | Yes (AJAX) |
| Dot-path field | `{ field: "company.verified", operator: eq, value: "true" }` | No | Yes (AJAX) |
| Dynamic value ref | `value: { field_ref: budget_limit }` | No | Yes (AJAX) |
| Lookup value ref | `value: { lookup: tax_limit, match: { key: vat_a }, pick: threshold }` | No | Yes (AJAX) |
| Collection quantifier | `collection: approvals, quantifier: any, condition: { ... }` | No | Yes (AJAX) |
| Service condition | `{ service: persisted_check }` | No | Yes (AJAX) |

Simple field-value conditions with literal values are evaluated client-side in JavaScript for instant UI reactivity. All other condition types are evaluated server-side (via AJAX on forms, directly on show/index pages).

## Simple Field-Value Conditions

The basic condition format used everywhere:

```yaml
{ field: status, operator: eq, value: "active" }
```

### `visible_when` on fields

Show or hide a form field based on a condition.

```yaml
fields:
  - field: contact_id
    input_type: association_select
    visible_when: { field: stage, operator: not_in, value: [lead] }
```

When the condition is false, the field renders with `display:none`. Values are preserved on form submit -- the field is hidden visually but remains in the DOM.

### `disable_when` on fields

Disable a form field based on a condition.

```yaml
fields:
  - field: value
    input_type: number
    disable_when: { field: stage, operator: in, value: [closed_won, closed_lost] }
```

When the condition is true, the field gets `opacity: 0.6` and `pointer-events: none`. This uses CSS instead of the HTML `disabled` attribute so that values are still submitted with the form.

### DSL

```ruby
form do
  section "Details" do
    field :contact_id, input_type: :association_select,
      visible_when: { field: :stage, operator: :not_in, value: [:lead] }
    field :value, input_type: :number,
      disable_when: { field: :stage, operator: :in, value: [:closed_won, :closed_lost] }
  end
end
```

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

```ruby
form do
  section "Metrics", visible_when: { field: :stage, operator: :not_eq, value: "lead" } do
    field :revenue
    field :margin
  end
end
```

## Compound Conditions

Combine multiple conditions with `all` (AND), `any` (OR), and `not` (negation). Nesting is supported to arbitrary depth (max 20 levels).

### `all` -- AND

All conditions must be true.

```yaml
# Form section: show description only when not draft AND high priority
sections:
  - title: "Description"
    visible_when:
      all:
        - { field: status, operator: not_eq, value: "draft" }
        - { field: priority, operator: in, value: [high, critical] }
    fields:
      - { field: description, input_type: textarea }
```

### `any` -- OR

At least one condition must be true.

```yaml
# Show section: financial details visible for active, review, or approved
show:
  layout:
    - section: "Financial Details"
      visible_when:
        any:
          - { field: status, operator: eq, value: "active" }
          - { field: status, operator: eq, value: "review" }
          - { field: status, operator: eq, value: "approved" }
      fields:
        - { field: amount }
        - { field: budget_limit }
```

### `not` -- Negation

The condition must be false. Accepts a single condition (not an array). For negating multiple conditions, use `not: { all: [...] }` or `not: { any: [...] }`.

```yaml
# Action: destroy only when status is NOT closed
actions:
  single:
    - name: destroy
      type: built_in
      visible_when:
        not: { field: status, operator: eq, value: "closed" }
```

### Nested compound

```yaml
# Complex: title present AND (high value OR high priority in finance industry)
visible_when:
  all:
    - { field: title, operator: present }
    - any:
      - { field: total_amount, operator: gt, value: 100000 }
      - all:
        - { field: priority, operator: eq, value: high }
        - { field: "company.industry", operator: eq, value: finance }
```

### DSL with `proc` blocks

In Ruby DSL presenters, use `proc { }` blocks with the condition builder for compound conditions:

```ruby
# Form section with compound visible_when
section "Description", columns: 1,
  visible_when: proc {
    all do
      field(:status).not_eq("draft")
      field(:priority).in("high", "critical")
    end
  } do
  field :description, input_type: :textarea
end

# Show section with any
section "Financial Details", columns: 2,
  visible_when: proc {
    any do
      field(:status).eq("active")
      field(:status).eq("review")
      field(:status).eq("approved")
    end
  } do
  field :amount
  field :budget_limit
end

# Action with not
action :destroy, type: :built_in, on: :single,
  visible_when: proc {
    not_condition do
      field(:status).eq("closed")
    end
  }
```

**Important:** Use `proc { }`, not `-> { }` (lambda). The condition builder uses `instance_eval`, which passes the receiver as an argument -- lambdas have strict arity and will raise `ArgumentError`.

**Empty lists:** `all: []` returns true (vacuous truth, emits a dev warning). `any: []` returns false.

## Dot-Path Fields

Reference fields on associated records using dot-path syntax. Only `belongs_to` / `has_one` chains are supported -- `has_many` segments are invalid (use [collection conditions](#collection-conditions) instead).

```yaml
# Show section: only when category is verified
show:
  layout:
    - section: "Category Info"
      visible_when:
        field: "showcase_condition_category.verified"
        operator: eq
        value: "true"
      fields:
        - { field: "showcase_condition_category.name" }
        - { field: "showcase_condition_category.industry" }
```

```yaml
# Item class: warning for unverified categories
index:
  item_classes:
    - class: "lcp-row-warning"
      when: { field: "company.verified", operator: eq, value: "false" }
```

**Eager loading required:** Associations referenced in dot-path conditions must be included in the presenter's `includes` configuration to avoid N+1 queries on index pages. The `ConfigurationValidator` enforces this at boot time.

```yaml
index:
  includes: [showcase_condition_category]  # Required for dot-path conditions
```

## Dynamic Value References

The `value` side of a condition can be a typed reference hash that resolves at evaluation time instead of a literal.

### `field_ref` -- another field on the same record

Compare two fields on the same record:

```yaml
# Row styling: bold when amount exceeds budget_limit
index:
  item_classes:
    - class: "lcp-row-bold"
      when: { field: amount, operator: gt, value: { field_ref: budget_limit } }
```

Supports dot-paths: `{ field_ref: "company.credit_limit" }`.

### `current_user` -- attribute of the authenticated user

```yaml
# Record rule: only the author can destroy
record_rules:
  - name: owner_only_destroy
    condition:
      not:
        field: author_id
        operator: eq
        value: { current_user: id }
    effect:
      deny_crud: [destroy]
      except_roles: [admin]
```

### `date` -- dynamic date/time

| Value | Resolves to |
|-------|-------------|
| `today` | `Date.current` |
| `now` | `Time.current` |

```yaml
# Row styling: red highlight for overdue active records
index:
  item_classes:
    - class: "lcp-row-danger"
      when:
        all:
          - { field: status, operator: not_eq, value: "closed" }
          - { field: due_date, operator: lt, value: { date: today } }
          - { field: due_date, operator: present }
```

No date arithmetic syntax (e.g., `today - 7.days`). Complex date computations use [value services](#value-services) instead.

### `service` -- value service (inside `value:`)

A value service provides a **computed value** for comparison (unlike condition services which return a boolean). Position in YAML determines the role: top-level `{ service: "X" }` is a condition service; inside `value:` it is a value service.

```yaml
condition:
  field: price
  operator: lt
  value:
    service: calculate_vat_threshold
    params:
      region: { field_ref: region }
```

```ruby
# app/condition_services/calculate_vat_threshold.rb
module LcpRuby
  module HostConditionServices
    class CalculateVatThreshold
      def self.call(record, **params)
        TaxLimit.where(region: params[:region]).pick(:vat_threshold)
      end
    end
  end
end
```

The `params:` hash supports typed value references (`field_ref`, `current_user`, etc.) -- the evaluator resolves all references before calling the service.

### `lookup` -- query another model

Compare a field against a value looked up from another model at runtime:

```yaml
# Amount must be under the VAT threshold for this record's tax category
visible_when:
  field: amount
  operator: lt
  value:
    lookup: tax_limit
    match: { key: vat_a }
    pick: threshold
```

With dynamic match criteria:

```yaml
visible_when:
  field: amount
  operator: lt
  value:
    lookup: tax_limit
    match:
      key: { field_ref: tax_key }
    pick: threshold
```

DSL equivalent:

```ruby
field(:amount).lt(LcpRuby::Dsl::ConditionBuilder.lookup(:tax_limit, match: { key: "vat_a" }, pick: :threshold))
```

**Constraints:** Target model must be defined. `match` is passed to `find_by`. Nested lookups are not supported. Raises `ConditionError` if no record matches.

**Performance note:** Each lookup executes a `find_by` query per record evaluation. When used in `item_classes` or action `visible_when` on index pages, this means one query per row. For static match criteria (e.g., `match: { key: vat_a }`) this is typically fast (hits DB index), but for high-volume index pages consider using a [value service](#service----value-service-inside-value) with caching instead.

## Collection Conditions

For conditions on `has_many` associations, use explicit quantifier syntax.

```yaml
# At least one task is approved
condition:
  collection: "showcase_condition_tasks"
  quantifier: any
  condition: { field: status, operator: eq, value: "approved" }
```

**Quantifiers:**

| Quantifier | Meaning |
|------------|---------|
| `any` | At least one child matches |
| `all` | Every child matches |
| `none` | No child matches |

### Collection inside compound conditions

```yaml
# Action: approve only when in review AND has approved tasks
actions:
  single:
    - name: approve
      type: custom
      visible_when:
        all:
          - { field: status, operator: eq, value: "review" }
          - collection: "showcase_condition_tasks"
            quantifier: any
            condition: { field: status, operator: eq, value: "approved" }
```

### DSL

```ruby
action :approve, type: :custom, on: :single,
  visible_when: proc {
    all do
      field(:status).eq("review")
      collection(:showcase_condition_tasks, quantifier: :any) do
        field(:status).eq("approved")
      end
    end
  }
```

### Row styling with collection conditions

```yaml
index:
  includes: [showcase_condition_tasks]  # Required!
  item_classes:
    - class: "lcp-row-success"
      when:
        collection: "showcase_condition_tasks"
        quantifier: any
        condition: { field: status, operator: eq, value: "approved" }
```

**Eager loading required:** The referenced `has_many` association must be included in `includes`. The `ConfigurationValidator` enforces this.

## Action Conditions

### Record Rules (Automatic)

Built-in `edit` and `destroy` actions are automatically hidden on the index page when [record_rules](../reference/permissions.md#record-rules) deny the corresponding CRUD operation. No `visible_when` needed in the presenter:

```yaml
# permissions/deal.yml -- this is all you need
record_rules:
  - name: closed_deals_readonly
    condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

Record rules support compound conditions, dynamic value references, and collection conditions:

```yaml
record_rules:
  # Compound: lock high-value closed records
  - name: high_value_closed_locked
    condition:
      all:
        - { field: status, operator: eq, value: closed }
        - { field: amount, operator: gt, value: 10000 }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]

  # Dynamic: only author can destroy
  - name: owner_only_destroy
    condition:
      not:
        field: author_id
        operator: eq
        value: { current_user: id }
    effect:
      deny_crud: [destroy]
      except_roles: [admin]
```

### `visible_when` on Actions

```yaml
actions:
  single:
    - name: approve
      type: custom
      visible_when:
        all:
          - { field: status, operator: eq, value: "review" }
          - collection: "approvals"
            quantifier: any
            condition: { field: decision, operator: eq, value: "approved" }
```

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

## Row-Level Styling (`item_classes`)

`item_classes` applies CSS classes to entire index rows (or tile cards / tree nodes) based on record field values. The element always renders -- only its visual appearance changes. All matching rules accumulate.

```yaml
index:
  includes: [showcase_condition_category, showcase_condition_tasks]
  item_classes:
    # Compound (all): overdue active records
    - class: "lcp-row-danger"
      when:
        all:
          - { field: status, operator: not_eq, value: "closed" }
          - { field: due_date, operator: lt, value: { date: today } }
          - { field: due_date, operator: present }

    # Compound (any): early-stage records
    - class: "lcp-row-info"
      when:
        any:
          - { field: status, operator: eq, value: "draft" }
          - { field: status, operator: eq, value: "review" }

    # Not: closed records get muted
    - class: "lcp-row-muted lcp-row-strikethrough"
      when:
        not: { field: status, operator: not_eq, value: "closed" }

    # Dot-path: unverified category
    - class: "lcp-row-warning"
      when: { field: "showcase_condition_category.verified", operator: eq, value: "false" }

    # field_ref: amount exceeds budget
    - class: "lcp-row-bold"
      when: { field: amount, operator: gt, value: { field_ref: budget_limit } }

    # Collection: has approved tasks
    - class: "lcp-row-success"
      when:
        collection: "showcase_condition_tasks"
        quantifier: any
        condition: { field: status, operator: eq, value: "approved" }

    # String operators
    - class: "lcp-item-urgent"
      when: { field: code, operator: starts_with, value: "URGENT" }
    - class: "lcp-item-temp"
      when: { field: code, operator: contains, value: "temp" }
```

DSL equivalent:

```ruby
index do
  item_class "lcp-row-danger", when: proc {
    all do
      field(:status).not_eq("closed")
      field(:due_date).lt({ "date" => "today" })
      field(:due_date).present
    end
  }

  item_class "lcp-row-info", when: proc {
    any do
      field(:status).eq("draft")
      field(:status).eq("review")
    end
  }

  item_class "lcp-row-success", when: proc {
    collection(:showcase_condition_tasks, quantifier: :any) do
      field(:status).eq("approved")
    end
  }
end
```

Built-in utility classes: `lcp-row-danger`, `lcp-row-warning`, `lcp-row-success`, `lcp-row-info`, `lcp-row-muted`, `lcp-row-bold`, `lcp-row-strikethrough`. Custom CSS classes are also supported.

Row styling is evaluated server-side regardless of field read permissions.

## Show Page Conditions

Show page sections support `visible_when` and `disable_when`. Unlike form conditions, show page conditions are evaluated **server-side only** -- hidden sections are not rendered in the DOM at all.

```yaml
show:
  layout:
    # Compound: visible for active/review/approved
    - section: "Financial Details"
      columns: 2
      visible_when:
        any:
          - { field: status, operator: eq, value: "active" }
          - { field: status, operator: eq, value: "review" }
      fields:
        - { field: amount }
        - { field: budget_limit }

    # Dot-path: show category info when verified
    - section: "Category Info"
      visible_when:
        field: "showcase_condition_category.verified"
        operator: eq
        value: "true"
      fields:
        - { field: "showcase_condition_category.name" }
```

DSL:

```ruby
show do
  section "Financial Details", columns: 2,
    visible_when: proc {
      any do
        field(:status).eq("active")
        field(:status).eq("review")
      end
    } do
    field :amount
    field :budget_limit
  end

  section "Category Info",
    visible_when: { field: "showcase_condition_category.verified", operator: :eq, value: "true" } do
    field "showcase_condition_category.name"
  end
end
```

When `disable_when` evaluates to true, the section is rendered with a `lcp-conditionally-disabled` CSS class.

## Form Section `disable_when`

Disable an entire form section based on a condition. Fields inside render as disabled.

```yaml
sections:
  - title: "Budget Override"
    disable_when: { field: status, operator: eq, value: "closed" }
    fields:
      - { field: budget_limit, input_type: number, prefix: "$" }
```

```ruby
section "Budget Override", columns: 2,
  disable_when: { field: :status, operator: :eq, value: "closed" } do
  info "Budget cannot be modified on closed records."
  field :budget_limit, input_type: :number, prefix: "$"
end
```

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

Register via auto-discovery in your initializer (see [Extensibility Guide -- Auto-Discovery Setup](extensibility.md#auto-discovery-setup) for the required Zeitwerk ignore configuration):

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

Each nested row renders with a `data-lcp-condition-scope` attribute. The JavaScript restricts field lookups to that container. Sub-sections within nested rows also support `visible_when` and `disable_when`.

## Client-Side Behavior

Simple field-value conditions with literal values (no dot-paths, no dynamic references, no compound) are evaluated client-side with vanilla JavaScript:

- Conditions re-evaluate on every `change` and `input` event
- No page reload needed -- updates are instant
- Handles checkboxes (Rails hidden+checkbox pattern), radio buttons, and selects

Advanced conditions (compound, dot-path, dynamic references, collection, service) are evaluated **server-side via AJAX** (300ms debounce) because they require access to associated records, the current user, or custom service logic.

## Operator Reference

See [Condition Operators](../reference/condition-operators.md) for the full list of supported operators:

| Group | Operators |
|-------|----------|
| String comparison | `eq`, `not_eq`/`neq`, `in`, `not_in` |
| Numeric comparison | `gt`, `gte`, `lt`, `lte` |
| String pattern | `starts_with`, `ends_with`, `contains`, `matches`, `not_matches` |
| Presence | `present`, `blank` |

## Common Patterns

### Overdue items with danger styling

```yaml
item_classes:
  - class: "lcp-row-danger"
    when:
      all:
        - { field: status, operator: not_in, value: [closed, done] }
        - { field: due_date, operator: lt, value: { date: today } }
        - { field: due_date, operator: present }
```

### Owner-only actions

```yaml
# In permissions YAML
record_rules:
  - name: owner_only_edit
    condition:
      not:
        field: author_id
        operator: eq
        value: { current_user: id }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

### Budget exceeded warning

```yaml
item_classes:
  - class: "lcp-row-bold"
    when: { field: amount, operator: gt, value: { field_ref: budget_limit } }
```

### Workflow gate with approval check

```ruby
action :finalize, type: :custom, on: :single,
  visible_when: proc {
    all do
      field(:status).eq("pending_approval")
      collection(:approvals, quantifier: :any) do
        field(:decision).eq("approved")
      end
    end
  }
```

### Show section for verified associations

```yaml
show:
  layout:
    - section: "Partner Details"
      visible_when:
        field: "partner_company.verified"
        operator: eq
        value: "true"
```

### Disable section on closed records

```yaml
form:
  sections:
    - title: "Budget Override"
      disable_when: { field: status, operator: eq, value: "closed" }
```

### Conditional description visibility (compound)

```ruby
section "Description",
  visible_when: proc {
    all do
      field(:status).not_eq("draft")
      field(:priority).in("high", "critical")
    end
  } do
  field :description, input_type: :textarea
end
```
