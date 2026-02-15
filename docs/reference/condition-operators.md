# Condition Operators Reference

Conditions are used in [action visibility](presenters.md#action-visibility) (`visible_when`), [record rules](permissions.md#record-rules) (`condition`), and [event conditions](models.md#condition) (`condition`). They all share the same operator syntax.

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
| Record rules | `record_rules[].condition` | [Permissions](permissions.md#record-rules) |

Source: `lib/lcp_ruby/condition_evaluator.rb`
