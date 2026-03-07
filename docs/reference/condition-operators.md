# Condition Operators Reference

Conditions are used in [action visibility](presenters.md#action-visibility) (`visible_when`/`disable_when`), [form field visibility](presenters.md#field-visibility) (`visible_when`/`disable_when`), [form section visibility](presenters.md#section-visibility) (`visible_when`/`disable_when`), [row styling](presenters.md#item-classes) (`item_classes[].when`), [record rules](permissions.md#record-rules) (`condition`), [event conditions](models.md#condition) (`condition`), and [conditional validations](models.md#conditional-validations-when) (`when:`). They all share the same operator syntax.

## Syntax

```yaml
{ field: <field_name>, operator: <operator>, value: <value> }
```

- `field` — the model attribute to evaluate
- `operator` — one of the operators below
- `value` — the comparison value (type depends on operator)

## Operators

### String Comparison

These operators convert both sides to strings via `to_s` before comparing.

| Operator | Description | Value Type |
|----------|-------------|------------|
| `eq` | Equal to | scalar |
| `not_eq` / `neq` | Not equal to | scalar |
| `in` | Included in list | array |
| `not_in` | Not included in list | array |

**Examples:**

```yaml
# Exact match
{ field: status, operator: eq, value: active }

# Negated match
{ field: stage, operator: not_eq, value: closed }

# Set membership
{ field: stage, operator: in, value: [closed_won, closed_lost] }

# Set exclusion
{ field: priority, operator: not_in, value: [low, trivial] }
```

### Numeric Comparison

These operators compare natively when both sides are the same comparable type (Numeric, Date, Time). Otherwise they fall back to `to_f` conversion for backward compatibility.

| Operator | Description | Value Type |
|----------|-------------|------------|
| `gt` | Greater than | number |
| `gte` | Greater than or equal to | number |
| `lt` | Less than | number |
| `lte` | Less than or equal to | number |

**Examples:**

```yaml
# Value above threshold
{ field: amount, operator: gt, value: 1000 }

# Value within range (use two conditions in record_rules)
{ field: quantity, operator: lte, value: 100 }
```

### String Pattern Matching

| Operator | Description | Value Type |
|----------|-------------|------------|
| `starts_with` | String prefix match | string |
| `ends_with` | String suffix match | string |
| `contains` | Case-insensitive substring match | string |
| `matches` | Matches regular expression | pattern (string) |
| `not_matches` | Does not match regular expression | pattern (string) |

**Examples:**

```yaml
# Name starts with prefix
{ field: name, operator: starts_with, value: "Project-" }

# Email ends with domain
{ field: email, operator: ends_with, value: "@company.com" }

# Title contains keyword (case-insensitive)
{ field: title, operator: contains, value: "urgent" }

# Email has a domain
{ field: email, operator: matches, value: "^[^@]+@" }

# Code is not a temporary prefix
{ field: code, operator: not_matches, value: "^TEMP" }
```

### Array Operators

These operators work on array fields (type `array`). The `contains` and `not_contains` operators are **polymorphic** — they perform array containment when the field value is an Array, and fall back to string substring matching for non-array fields.

| Operator | Description | Value Type |
|----------|-------------|------------|
| `contains` | Array: field contains ALL given values. String: case-insensitive substring match. | scalar or array |
| `not_contains` | Array: field does not contain ANY given value. String: does not contain substring. | scalar or array |
| `any_of` | Array field contains at least one of the given values | array |
| `empty` | Array field is empty (`[]`) | — |
| `not_empty` | Array field has at least one item | — |

**Examples:**

```yaml
# Array contains all specified values
{ field: tags, operator: contains, value: [ruby, rails] }

# Array does not contain any of the values
{ field: tags, operator: not_contains, value: [deprecated] }

# Array contains at least one of the values
{ field: tags, operator: any_of, value: [ruby, python] }

# Array is empty
{ field: tags, operator: empty }

# Array has items
{ field: tags, operator: not_empty }
```

> **Note:** `contains` on a string field still performs case-insensitive substring matching (e.g., `{ field: title, operator: contains, value: "urgent" }`). The operator detects the field type at runtime.

### Presence Checks

These operators ignore the `value` field. They also work on array fields (`[].blank?` is `true`, `[1].present?` is `true`).

| Operator | Description | Value Type |
|----------|-------------|------------|
| `present` | Field is present (not nil, not empty) | — |
| `blank` | Field is blank (nil, empty string, empty array, etc.) | — |

**Examples:**

```yaml
# Field has a value
{ field: assigned_to, operator: present }

# Field is empty
{ field: notes, operator: blank }
```

## Strict Evaluation

The evaluator enforces strict validation at runtime:

- **Unknown operator** — raises `LcpRuby::ConditionError`. There is no fallback to `eq`.
- **Missing field** — raises `LcpRuby::ConditionError` if the record does not respond to the specified field.
- **Missing `field` key** — raises `LcpRuby::ConditionError` (for field-value conditions).
- **Nil condition** — raises `ArgumentError`. Callers must guard against nil before invoking the evaluator.

All operators and field names are validated at boot time by `ConfigurationValidator`. Runtime errors indicate a bug (bypassed validation, DB-sourced definition with typo) and fail loudly rather than producing wrong results.

## Operator-Type Compatibility

The `ConfigurationValidator` checks operator-type compatibility at boot time:

| Operator group | Compatible field types |
|---------------|-----------------------|
| `eq`, `not_eq`/`neq`, `in`, `not_in` | all types |
| `gt`, `gte`, `lt`, `lte` | `integer`, `float`, `decimal`, `date`, `datetime` |
| `present`, `blank` | all types |
| `starts_with`, `ends_with` | `string`, `text` (including custom types with string/text base) |
| `contains`, `not_contains` | `string`, `text` (substring match), `array` (containment check) |
| `matches`, `not_matches` | `string`, `text` (including custom types with string/text base) |
| `any_of`, `empty`, `not_empty` | `array` |

For custom types (e.g., `email` with base type `string`), the validator resolves the base type before checking compatibility.

## Where Conditions Are Used

| Context | YAML Location | Documentation |
|---------|---------------|---------------|
| Action visibility | `actions.single[].visible_when` | [Presenters](presenters.md#action-visibility) |
| Action disable | `actions.single[].disable_when` | [Presenters](presenters.md#action-visibility) |
| Form field visibility | `form.sections[].fields[].visible_when` | [Presenters](presenters.md#field-visibility) |
| Form field disable | `form.sections[].fields[].disable_when` | [Presenters](presenters.md#field-visibility) |
| Form section visibility | `form.sections[].visible_when` | [Presenters](presenters.md#section-visibility) |
| Form section disable | `form.sections[].disable_when` | [Presenters](presenters.md#section-visibility) |
| Record rules | `record_rules[].condition` | [Permissions](permissions.md#record-rules) |
| Conditional validations | `fields[].validations[].when` | [Models](models.md#conditional-validations-when) |
| Event conditions | `events[].condition` | [Models](models.md#condition) |

## Compound Conditions

Combine multiple conditions with logical operators. Nesting is supported to arbitrary depth (max 20 levels).

### `all` — AND

```yaml
condition:
  all:
    - { field: title, operator: present }
    - { field: total_amount, operator: gt, value: 0 }
```

### `any` — OR

```yaml
condition:
  any:
    - { field: role, operator: eq, value: admin }
    - { field: stage, operator: eq, value: draft }
```

### `not` — Negation

```yaml
condition:
  not: { field: stage, operator: eq, value: closed }
```

### Nested

```yaml
condition:
  all:
    - { field: title, operator: present }
    - any:
      - { field: total_amount, operator: gt, value: 100000 }
      - { field: priority, operator: eq, value: high }
```

**Empty lists:** `all: []` returns true (vacuous truth, dev warning). `any: []` returns false.

## Dot-Path Fields

Reference fields on associated records using dot-path syntax. Only `belongs_to` / `has_one` chains are allowed.

```yaml
visible_when:
  field: "company.country.code"
  operator: eq
  value: "CZ"
```

Associations referenced in dot-paths must be included in the presenter's `includes` configuration to avoid N+1 queries on index pages.

## Dynamic Value References

The `value` side can be a typed reference hash that resolves at evaluation time.

### `field_ref` — another field on the same record

```yaml
condition:
  field: approved_amount
  operator: lte
  value: { field_ref: budget_limit }
```

Supports dot-paths: `{ field_ref: "company.credit_limit" }`.

### `current_user` — attribute of the authenticated user

```yaml
condition:
  field: author_id
  operator: eq
  value: { current_user: id }
```

### `date` — dynamic date/time

| Value | Resolves to |
|-------|-------------|
| `today` | `Date.current` |
| `now` | `Time.current` |

```yaml
condition:
  field: due_date
  operator: lt
  value: { date: today }
```

### `service` — value service (inside `value:`)

```yaml
condition:
  field: price
  operator: lt
  value:
    service: calculate_vat_threshold
    params:
      region: { field_ref: region }
```

### `lookup` — query another model

```yaml
condition:
  field: price
  operator: lt
  value:
    lookup: tax_limit        # target model name
    match: { key: vat_a }   # find_by criteria
    pick: threshold          # field to return from matched record
```

Match values support dynamic references:

```yaml
value:
  lookup: tax_limit
  match:
    key: { field_ref: tax_key }
  pick: threshold
```

**Constraints:**
- Target model must be defined in `config/lcp_ruby/models/`
- `match` must be a Hash, `pick` must be a string
- Nested lookups (lookup inside match values) are not supported
- Raises `ConditionError` if no record matches

## Collection Conditions

For conditions on `has_many` associations, use explicit quantifier syntax.

```yaml
# At least one approval is approved
condition:
  collection: "approvals"
  quantifier: any
  condition: { field: status, operator: eq, value: "approved" }
```

**Quantifiers:** `any` (at least one), `all` (every child), `none` (no child matches).

The referenced association must be included in the presenter's `includes` configuration.

## DSL Syntax

```ruby
condition = LcpRuby::Dsl::ConditionBuilder.build do
  all do
    field(:status).eq("active")
    field(:amount).gt(field_ref: "budget_limit")
    collection(:approvals, quantifier: :any) do
      field(:decision).eq("approved")
    end
  end
end
```

Lookup value reference:

```ruby
field(:price).lt(LcpRuby::Dsl::ConditionBuilder.lookup(:tax_limit, match: { key: "vat_a" }, pick: :threshold))
```

## Client-Side Evaluation

Simple field-value conditions with literal values (no dot-paths, no dynamic references) are evaluated client-side in JavaScript for instant UI reactivity.

Compound conditions, dot-path conditions, dynamic value references, collection conditions, and service conditions are evaluated server-side via AJAX.

Source: `lib/lcp_ruby/condition_evaluator.rb`
