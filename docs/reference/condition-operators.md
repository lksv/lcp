# Condition Operators Reference

Conditions are used in [action visibility](presenters.md#action-visibility) (`visible_when`/`disable_when`), [form field visibility](presenters.md#field-visibility) (`visible_when`/`disable_when`), [form section visibility](presenters.md#section-visibility) (`visible_when`/`disable_when`), [record rules](permissions.md#record-rules) (`condition`), and [event conditions](models.md#condition) (`condition`). They all share the same operator syntax.

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

These operators convert both sides to floats via `to_f` before comparing.

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

### Regular Expression Matching

These operators test the field value against a regular expression pattern.

| Operator | Description | Value Type |
|----------|-------------|------------|
| `matches` | Matches regular expression | pattern (string) |
| `not_matches` | Does not match regular expression | pattern (string) |

**Examples:**

```yaml
# Email has a domain
{ field: email, operator: matches, value: "^[^@]+@" }

# Code is not a temporary prefix
{ field: code, operator: not_matches, value: "^TEMP" }

# Name contains digits
{ field: name, operator: matches, value: "[0-9]" }
```

### Presence Checks

These operators ignore the `value` field.

| Operator | Description | Value Type |
|----------|-------------|------------|
| `present` | Field is present (not nil, not empty) | — |
| `blank` | Field is blank (nil, empty string, etc.) | — |

**Examples:**

```yaml
# Field has a value
{ field: assigned_to, operator: present }

# Field is empty
{ field: notes, operator: blank }
```

## Default Behavior

When `operator` is omitted or unrecognized, the evaluator falls back to `eq` (string equality via `to_s`).

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

## Client-Side Evaluation

All field-value operators (`eq`, `not_eq`, `in`, `not_in`, `gt`, `gte`, `lt`, `lte`, `present`, `blank`, `matches`, `not_matches`) are evaluated client-side in JavaScript for instant UI reactivity when used in form field/section `visible_when` and `disable_when` conditions.

Conditions that use the `service:` key instead of `field:` are evaluated server-side via AJAX, as they require backend logic or data not available in the browser.

Source: `lib/lcp_ruby/condition_evaluator.rb`
