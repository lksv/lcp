# Feature Specification: Row Styling (Index Pages)

**Status:** Implemented
**Date:** 2026-03-04

## Problem / Motivation

Index pages currently render all table rows with identical visual treatment. In professional information systems, users need visual cues to quickly identify records that require attention — overdue items, high-priority tasks, completed records, disabled accounts, or records in specific workflow states. Without conditional row styling, users must scan column values one by one to assess record status.

Badge renderers already solve this at the cell level (e.g., color-coded status badges), but row-level styling provides a stronger, immediate visual signal across the entire row — especially useful when the distinguishing field is not the first visible column.

## User Scenarios

**As a project manager,** I want overdue tasks highlighted in red and completed tasks grayed out, so I can immediately spot items that need attention without reading every due date.

**As a CRM administrator,** I want high-value deals (above $100k) displayed in bold and lost deals struck through, so the sales team can visually prioritize their pipeline at a glance.

**As a helpdesk operator,** I want unassigned tickets highlighted with a warning color, so I can quickly identify tickets that need to be picked up.

**As a platform user using tree view,** I want the same row styling rules to apply to tree nodes, so visual cues are consistent regardless of the index layout.

**As a platform user,** I want to combine multiple styling rules — a row can be both bold (high priority) and red (overdue) at the same time.

## Configuration & Behavior

### YAML configuration

Row styling is configured under `index.item_classes` in the presenter YAML. Each rule maps a CSS class to a condition evaluated against each record.

```yaml
# config/lcp_ruby/presenters/tasks.yml
index:
  item_classes:
    - class: "lcp-row-danger"
      when:
        field: due_date
        operator: lt
        value: "2026-01-01"
    - class: "lcp-row-muted"
      when:
        field: status
        operator: eq
        value: "done"
    - class: "lcp-row-bold"
      when:
        field: priority
        operator: eq
        value: "high"
```

Each rule has:
- `class` (required) — one or more CSS class names (space-separated string) to apply when the condition matches.
- `when` (required) — a condition hash in the standard platform condition format (`field`/`operator`/`value` or `service`).

### DSL configuration

```ruby
define_presenter :tasks do
  model :task

  index do
    item_class "lcp-row-danger", when: { field: :due_date, operator: :lt, value: "2026-01-01" }
    item_class "lcp-row-muted", when: { field: :status, operator: :eq, value: "done" }
    item_class "lcp-row-bold", when: { field: :priority, operator: :eq, value: "high" }
  end
end
```

### Evaluation rules

- **All rules are evaluated** for every record. Classes accumulate — a record matching multiple rules gets all matching CSS classes on its `<tr>` (or tile/tree node element).
- **Order does not matter.** There is no "first match wins" logic. All matching classes are applied. CSS cascade determines the final visual result.
- **Conditions reuse `ConditionEvaluator`** — the same 12 operators used by `visible_when`, `disable_when`, and `record_rules`. This includes field-value conditions and service-based conditions.
- **Nil field values** follow standard `ConditionEvaluator` behavior — `lt` on nil uses `nil.to_f` (0.0), `eq` on nil compares `"" == value.to_s`, `blank` on nil returns true. No special handling.
- **Enum fields** compare against the raw database value (string), not the i18n-translated label.

### Custom fields support

Custom fields are supported in conditions using the field name from the custom field definition:

```yaml
item_classes:
  - class: "lcp-row-warning"
    when:
      field: risk_level       # custom field
      operator: eq
      value: "high"
```

This works because `ConditionEvaluator` uses `record.send(field)` and custom field accessors are installed by `CustomFields::Applicator`.

### Condition services

For complex logic that cannot be expressed with a single field-value comparison, condition services are supported:

```yaml
item_classes:
  - class: "lcp-row-danger"
    when:
      service: overdue_checker
```

The service must be registered in `ConditionServiceRegistry` and follow the standard `def self.call(record) -> boolean` contract.

### Permissions

Row styling conditions are evaluated **regardless of field read permissions**. The styling is applied server-side and does not expose field values to the user — it only adds CSS classes to the HTML element. A user without read access to `priority` still sees styled rows based on priority conditions, but cannot see the priority column value.

### Cross-view support

The key is named `item_classes` (not `row_classes`) because it applies across all index layouts:

| Layout | Where classes are applied |
|--------|--------------------------|
| `table` (default) | `<tr>` element in the table body |
| `tree` | `<tr>` element for each tree node |
| `tiles` (future) | Card container element (`.lcp-tile-card`) |

### Built-in utility CSS classes

The engine provides a set of utility classes in its default stylesheet. Users may also use any custom CSS class.

| Class | Visual effect |
|-------|---------------|
| `lcp-row-danger` | Light red background |
| `lcp-row-warning` | Light yellow/amber background |
| `lcp-row-success` | Light green background |
| `lcp-row-info` | Light blue background |
| `lcp-row-muted` | Gray text, reduced opacity |
| `lcp-row-bold` | Bold text weight |
| `lcp-row-strikethrough` | Line-through text decoration |

These classes are designed to be combinable — `lcp-row-danger lcp-row-bold` produces a bold red row.

### Boot-time validation

`ConfigurationValidator` validates `item_classes` at boot:

- Each entry must have `class` (non-empty string) and `when` (hash).
- The `when` hash is validated using the same condition validation as `visible_when`/`disable_when`: field must exist on the model (or model has custom fields enabled), operator must be valid, operator must be compatible with the field type.
- Service-based conditions validate that the `service` key is a non-empty string (actual service registration is checked at runtime since services are discovered after validation).
- Invalid `item_classes` entries produce a hard error — the application does not boot.

## Usage Examples

### Task list with status-based styling

```yaml
name: tasks
model: task
slug: tasks

index:
  table_columns:
    - { field: title }
    - { field: status, renderer: badge }
    - { field: priority }
    - { field: due_date }
    - { field: assignee.name }
  item_classes:
    - class: "lcp-row-muted lcp-row-strikethrough"
      when: { field: status, operator: eq, value: "done" }
    - class: "lcp-row-danger"
      when: { field: status, operator: eq, value: "overdue" }
    - class: "lcp-row-bold"
      when: { field: priority, operator: eq, value: "critical" }
```

### CRM deals with value-based highlighting

```yaml
name: deals
model: deal
slug: deals

index:
  table_columns:
    - { field: name }
    - { field: stage, renderer: badge }
    - { field: value, renderer: currency }
    - { field: company.name }
  item_classes:
    - class: "lcp-row-bold"
      when: { field: value, operator: gte, value: 100000 }
    - class: "lcp-row-muted lcp-row-strikethrough"
      when: { field: stage, operator: in, value: ["closed_lost"] }
    - class: "lcp-row-success"
      when: { field: stage, operator: eq, value: "closed_won" }
```

### Using a condition service

```yaml
name: invoices
model: invoice
slug: invoices

index:
  item_classes:
    - class: "lcp-row-danger"
      when: { service: overdue_invoice_checker }
    - class: "lcp-row-warning"
      when: { field: payment_status, operator: eq, value: "pending" }
```

### DSL equivalent

```ruby
define_presenter :tasks do
  model :task
  slug "tasks"

  index do
    table_column :title
    table_column :status, renderer: :badge
    table_column :priority
    table_column :due_date

    item_class "lcp-row-muted lcp-row-strikethrough",
               when: { field: :status, operator: :eq, value: "done" }
    item_class "lcp-row-danger",
               when: { field: :status, operator: :eq, value: "overdue" }
    item_class "lcp-row-bold",
               when: { field: :priority, operator: :eq, value: "critical" }
  end
end
```

## General Implementation Approach

### Condition evaluation at render time

For each record in the index loop, the view iterates over the presenter's `item_classes` rules and evaluates each condition using `ConditionEvaluator.evaluate_any`. Matching CSS classes are collected into a string and applied to the row element.

This is an in-memory operation per record (no additional DB queries). For a page with 50 records and 5 rules, that is 250 condition evaluations — each is a simple field access + comparison, effectively free.

### Eager loading

Fields referenced in `item_classes` conditions may require eager loading (e.g., dot-path fields like `company.status`). The `IncludesResolver` / `DependencyCollector` is extended to scan `item_classes` condition fields the same way it scans table columns and `visible_when`/`disable_when` conditions.

### CSS utility classes

The built-in utility classes are added to the engine's existing stylesheet. They use `!important` sparingly (only for `lcp-row-muted` opacity) to avoid specificity wars. Colors use CSS custom properties (`--lcp-row-danger-bg`, etc.) so host applications can easily override them.

### ConfigurationValidator extension

The validator gains a new `validate_item_classes` method that iterates over the `item_classes` array and delegates each `when` hash to the existing `validate_condition` method. This ensures field existence, operator validity, and operator-type compatibility are checked at boot time.

### JSON schema extension

The presenter JSON schema is updated to include `item_classes` under the `index` object. Each array item requires `class` (string) and `when` (condition object — reusing the existing condition schema definition).

## Decisions

1. **Name: `item_classes`** — View-agnostic name that works for table rows, tree nodes, and future tile cards. Lives under `index:` because it applies to the index page specifically.

2. **All rules accumulate.** No priority or "first match wins". Multiple matching rules add all their classes. CSS determines the visual outcome. This is simpler and more predictable.

3. **Server-side evaluation, no field permission check.** Styling is a visual hint, not a data disclosure. The user sees a colored row but cannot infer the exact field value from it (many values could produce the same style).

4. **Hard error on validation failure.** Consistent with `visible_when`, `disable_when`, and `record_rules`. Invalid configuration is a bug, not a runtime graceful degradation scenario.

5. **No shorthand syntax.** Only the full `class` + `when` format is supported. This keeps the schema simple and consistent with other condition-based features in the platform.

6. **Reuse `ConditionEvaluator.evaluate_any`.** No new evaluation logic. This automatically gains compound conditions (`all`/`any`/`not`) and dynamic value references (`field_ref`, `date: today`) when those are implemented in the unified condition system.

## Open Questions

1. ~~**Hover/tooltip on styled rows?**~~ **No hover/tooltip needed.** Row styling is a visual cue only — no tooltip explaining why the row is highlighted. The CSS class communicates the state; users learn the color meaning from context (column values are visible in the same row). Adding tooltips would require extra i18n config per rule with little practical benefit.
