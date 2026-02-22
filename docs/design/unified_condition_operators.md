# Unified Condition Operators — Design Document

> **Status: Implemented.** `ConditionError` added, `ConditionEvaluator` made strict (raises on unknown operator/missing field/nil), `matches_condition?` removed, `can_for_record?` alias bug fixed, operator-type validation added to `ConfigurationValidator`, custom fields skip added for condition validation.

## Overview

The platform has two independent implementations for evaluating field-value
conditions against records:

1. **`ConditionEvaluator.evaluate`** — used by `visible_when`/`disable_when`
   on presenter fields and actions. Supports 12 operators.
2. **`PermissionEvaluator#matches_condition?`** — used by `record_rules` in
   permission definitions. Supports only 5 operators.

Both use identical YAML syntax (`{ field, operator, value }`), but
`matches_condition?` silently falls through to `eq` for unsupported operators.
The JSON schema (`permission.json`) and `ConfigurationValidator` already
accept all 12 operators in `record_rules`, so invalid configurations pass
validation but produce wrong runtime behavior.

### Operator Support Matrix

| Operator | `ConditionEvaluator` | `matches_condition?` |
|----------|:-------------------:|:--------------------:|
| `eq` | yes | yes |
| `not_eq` / `neq` | yes | yes |
| `in` | yes | yes |
| `not_in` | yes | yes |
| `gt` | yes | **no** (falls to eq) |
| `gte` | yes | **no** (falls to eq) |
| `lt` | yes | **no** (falls to eq) |
| `lte` | yes | **no** (falls to eq) |
| `present` | yes | **no** (falls to eq) |
| `blank` | yes | **no** (falls to eq) |
| `matches` | yes | **no** (falls to eq) |
| `not_matches` | yes | **no** (falls to eq) |

### Concrete Failure Example

```yaml
# permissions/task.yml — passes schema validation, wrong at runtime
record_rules:
  - name: high_priority_locked
    condition: { field: priority, operator: gte, value: 3 }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

At runtime `gte` hits the `else` branch in `matches_condition?` and evaluates
as `priority.to_s == "3"` (string equality). A task with `priority: 5` would
NOT be denied because `"5" != "3"`.

---

## Current Code

### `ConditionEvaluator.evaluate` (`lib/lcp_ruby/condition_evaluator.rb:4-44`)

```ruby
def self.evaluate(record, condition)
  return true unless condition
  # ...
  return true unless field && record.respond_to?(field)  # ← returns TRUE
  actual = record.send(field)
  case operator
  when "eq"          then actual.to_s == value.to_s
  when "not_eq", ... then ...
  when "gt"          then actual.to_f > value.to_f
  when "present"     then actual.present?
  when "matches"     then actual.to_s.match?(safe_regexp(value))
  # ... all 12 operators
  end
end
```

### `PermissionEvaluator#matches_condition?` (`lib/lcp_ruby/authorization/permission_evaluator.rb:208-227`)

```ruby
def matches_condition?(record, condition)
  return true unless condition.is_a?(Hash)
  # ...
  return false unless field && record.respond_to?(field)  # ← returns FALSE
  actual = record.send(field)
  case operator
  when "eq"            then actual.to_s == value.to_s
  when "not_eq", "neq" then actual.to_s != value.to_s
  when "in"            then Array(value).map(&:to_s).include?(actual.to_s)
  when "not_in"        then !Array(value).map(&:to_s).include?(actual.to_s)
  else actual.to_s == value.to_s  # ← silent fallback
  end
end
```

### Problems with Current Behavior

Both implementations silently handle error conditions that should be caught:

| Scenario | Current behavior | Required behavior |
|----------|-----------------|-------------------|
| Unknown operator | Falls through to `eq` | **Raise exception** |
| Field missing on record | Returns true/false silently | **Raise exception** |
| Condition is nil/empty | Returns true silently | **Caller must not pass nil** |
| Action alias in `can_for_record?` | Not resolved (see below) | **Resolve before checking** |

The rake validator (`lcp_ruby:validate`) and JSON schema validate operators
and field names at boot time. If an invalid operator or missing field reaches
runtime, it indicates a bug (bypassed validation, DB-sourced definition with
typo) and must fail loudly rather than produce wrong results.

### Bug: Action Alias Not Resolved in `can_for_record?`

The current `can_for_record?` checks `denied.include?(action.to_s)` using the
**original** action string. `ACTION_ALIASES` maps `"edit"` → `"update"` and
`"new"` → `"create"`, but this mapping is only applied inside `can?`, not
when checking `deny_crud`.

```ruby
# Current code — bug on line 38
def can_for_record?(action, record)
  return false unless can?(action)              # ← resolves "edit" → "update"
  permission_definition.record_rules.each do |rule|
    # ...
    if denied.include?(action.to_s) ...         # ← checks "edit", not "update"
```

**Example:** A record rule with `deny_crud: [update]` does NOT deny the
`"edit"` action because `"edit" != "update"`. This is fixed in the proposed
`can_for_record?` below by resolving the alias before the loop.

---

## Proposed Solution

### Error Class

Add `ConditionError` to the existing hierarchy in `lib/lcp_ruby.rb`:

```ruby
module LcpRuby
  class Error < StandardError; end
  class MetadataError < Error; end
  class SchemaError < Error; end
  class ServiceError < Error; end
  class ConditionError < Error; end   # ← new
end
```

`ConditionError` inherits directly from `LcpRuby::Error` (not `MetadataError`)
because condition evaluation is a runtime concern, not a metadata-loading
concern. `MetadataError` signals problems during YAML parsing and definition
building; `ConditionError` signals that a validated condition encountered an
impossible state at evaluation time (unknown operator, missing field).

### Full Unification: Eliminate `matches_condition?`

Since both unknown operators and missing fields should raise exceptions,
there is no behavioral difference left between `matches_condition?` and
`ConditionEvaluator.evaluate`. The `matches_condition?` wrapper becomes
unnecessary — `PermissionEvaluator` should call `ConditionEvaluator.evaluate`
directly.

**Changes to `ConditionEvaluator.evaluate`:**

```ruby
def self.evaluate(record, condition)
  raise ArgumentError, "condition is required" unless condition.is_a?(Hash)

  condition = condition.transform_keys(&:to_s)
  field = condition["field"]
  operator = condition["operator"]&.to_s
  value = condition["value"]

  unless field && record.respond_to?(field)
    raise ConditionError,
      "Record #{record.class} does not respond to '#{field}'"
  end

  actual = record.send(field)

  case operator
  when "eq"                then actual.to_s == value.to_s
  when "not_eq", "neq"     then actual.to_s != value.to_s
  when "in"                then Array(value).map(&:to_s).include?(actual.to_s)
  when "not_in"            then !Array(value).map(&:to_s).include?(actual.to_s)
  when "gt"                then actual.to_f > value.to_f
  when "gte"               then actual.to_f >= value.to_f
  when "lt"                then actual.to_f < value.to_f
  when "lte"               then actual.to_f <= value.to_f
  when "present"           then actual.present?
  when "blank"             then actual.blank?
  when "matches"           then actual.to_s.match?(safe_regexp(value.to_s))
  when "not_matches"       then !actual.to_s.match?(safe_regexp(value.to_s))
  else
    raise ConditionError,
      "Unknown condition operator '#{operator}'"
  end
end
```

**Changes to `PermissionEvaluator`:**

Remove `matches_condition?` entirely. In `can_for_record?`, call
`ConditionEvaluator.evaluate` directly:

```ruby
def can_for_record?(action, record)
  resolved = ACTION_ALIASES[action.to_s] || action.to_s
  return false unless can?(action)

  permission_definition.record_rules.each do |rule|
    rule = rule.transform_keys(&:to_s) if rule.is_a?(Hash)
    condition = rule["condition"]
    next unless ConditionEvaluator.evaluate(record, condition)

    denied = (rule.dig("effect", "deny_crud") || []).map(&:to_s)
    except_roles = (rule.dig("effect", "except_roles") || []).map(&:to_s)

    if denied.include?(resolved) && (roles & except_roles).empty?
      return false
    end
  end

  true
end
```

### Condition is Required — Uniform Contract

All three entry points require a non-nil condition:

| Method | Input | nil/non-Hash |
|--------|-------|-------------|
| `evaluate(record, condition)` | field-value Hash | raises `ArgumentError` |
| `evaluate_service(record, condition)` | service Hash | raises `ArgumentError` |
| `evaluate_any(record, condition)` | any condition Hash | raises `ArgumentError` |

**Changes to `evaluate_any` and `evaluate_service`:**

```ruby
def self.evaluate_any(record, condition)
  raise ArgumentError, "condition is required" unless condition.is_a?(Hash)

  case condition_type(condition)
  when :field_value
    evaluate(record, condition)
  when :service
    evaluate_service(record, condition)
  else
    raise ConditionError,
      "Condition must contain 'field' or 'service' key"
  end
end

def self.evaluate_service(record, condition)
  raise ArgumentError, "condition is required" unless condition.is_a?(Hash)

  normalized = condition.transform_keys(&:to_s)
  service_key = normalized["service"]
  service = ConditionServiceRegistry.lookup(service_key)

  unless service
    raise ConditionError,
      "Condition service '#{service_key}' not registered"
  end

  !!service.call(record)
end
```

The previous `evaluate_any` returned `true` for nil and for unrecognized
condition shapes. This was lenient to avoid breaking callers that pass
optional conditions through. But all existing callers already guard against
nil before calling:

- `ActionSet#action_visible_for_record?` — `return true unless visible_when`
- `ActionSet#action_disabled_for_record?` — `return false unless disable_when`
- `CallbackApplicator` — `if condition.is_a?(Hash)`
- `ValidationApplicator` — `if when_condition` / `next unless ...`

Making `evaluate_any` strict doesn't break any existing caller. The
`condition_helper.rb#condition_met?` wrapper is the only call site without
a nil guard — it must be updated to guard nil:

```ruby
def condition_met?(record, condition)
  return true unless condition
  ConditionEvaluator.evaluate_any(record, condition)
end
```

The `condition` key is already required in the JSON schema for record_rules:

```json
"record_rule": {
  "required": ["name", "condition", "effect"]
}
```

For contexts where the condition key is optional in YAML (e.g.,
`visible_when` on an action — omitting it means "always visible"), the
**caller** decides the default before invoking the evaluator:

```ruby
# ActionSet — visible_when is optional
def action_visible_for_record?(action, record)
  visible_when = action["visible_when"]
  return true unless visible_when  # ← caller handles nil, not evaluator
  ConditionEvaluator.evaluate_any(record, visible_when)
end
```

### DSL Syntax

The Ruby DSL equivalent for conditions follows the existing DSL patterns
in the platform (model DSL, presenter DSL):

```ruby
# Simple condition
condition field: :status, operator: :eq, value: "archived"

# In record_rules context
record_rule :archived_readonly do
  condition field: :status, operator: :eq, value: "archived"
  deny_crud :update, :destroy
  except_roles :admin
end

# In presenter action context
action :close_won, type: :custom, on: :single,
  visible_when: { field: :stage, operator: :not_in, value: [:closed_won, :closed_lost] },
  disable_when: { field: :value, operator: :blank }
```

The DSL produces the same hash structure as YAML — no separate evaluation
path. The `field`, `operator`, and `value` keys map 1:1.

---

## Operator–Type Validation in `ConfigurationValidator`

The current `ConfigurationValidator` checks that the operator name is valid
and that the field exists on the model. It does **not** check whether the
operator is semantically compatible with the field's type. This means
configurations like `{ field: name, operator: gt, value: 3 }` (where `name`
is a `string` field) pass validation but produce nonsensical results at
runtime (`"Alice".to_f` → `0.0 > 3.0`).

### Operator–Type Compatibility Rules

| Operator group | Compatible field types | Incompatible |
|---------------|-----------------------|--------------|
| `eq`, `not_eq`/`neq` | all types | — |
| `in`, `not_in` | all types | — |
| `gt`, `gte`, `lt`, `lte` | `integer`, `float`, `decimal`, `date`, `datetime` | `string`, `text`, `boolean`, `enum`, `file`, `rich_text`, `json`, `uuid`, `attachment` |
| `present`, `blank` | all types | — |
| `matches`, `not_matches` | `string`, `text`, `email`, `phone`, `url`, `color` | `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`, `file`, `rich_text`, `json`, `uuid`, `attachment` |

### Implementation

This is a small extension to the existing `validate_condition` and
`validate_permission_record_rules` methods. The validator already calls
`model_field_names(model_name)` which returns string names. To get the
field type, it needs the `FieldDefinition` object instead:

```ruby
# New helper (ConfigurationValidator)
NUMERIC_OPERATORS = %w[gt gte lt lte].freeze
REGEX_OPERATORS = %w[matches not_matches].freeze
NUMERIC_TYPES = %w[integer float decimal date datetime].freeze
TEXT_TYPES = %w[string text].freeze

def model_field_definition(model_name, field_name)
  definition = loader.model_definitions[model_name]
  return nil unless definition

  definition.fields.find { |f| f.name == field_name.to_s }
end

# In validate_condition / validate_permission_record_rules:
if field_name && operator
  field_def = model_field_definition(model_name, field_name)
  if field_def
    resolved_type = field_def.type_definition&.base_type || field_def.type

    if NUMERIC_OPERATORS.include?(operator.to_s) && !NUMERIC_TYPES.include?(resolved_type)
      @errors << "#{context}: operator '#{operator}' requires a numeric/date " \
                 "field, but '#{field_name}' is '#{resolved_type}'"
    end

    if REGEX_OPERATORS.include?(operator.to_s) && !TEXT_TYPES.include?(resolved_type)
      @errors << "#{context}: operator '#{operator}' requires a text " \
                 "field, but '#{field_name}' is '#{resolved_type}'"
    end
  end
end
```

This resolves custom types through `type_definition.base_type` — a field
with type `email` (base type `string`) is compatible with `matches`. The
change is additive (new validation checks, no changes to existing logic)
and catches misconfiguration at boot time.

**Note:** `date` and `datetime` fields are included in `NUMERIC_TYPES`
because their `to_f` produces a Unix timestamp, making `gt`/`lt` comparisons
meaningful (e.g., "created after date X").

### Custom Fields in Conditions

Custom fields (DB-defined via `custom_field_definition`) work with
conditions at runtime without any special handling:

1. `Applicator` installs getter methods via `define_method`
   (`custom_fields/applicator.rb:77`), so `record.respond_to?(field_name)`
   returns `true` and `record.send(field_name)` returns the value.
2. Custom field values are stored as JSON in the `custom_data` column. All
   values pass through `to_s`/`to_f` coercion in the evaluator, which
   handles the fact that JSON stores everything the form sends (typically
   strings). For example, a custom field with `custom_type: "integer"` and
   stored value `"5"` evaluates correctly: `"5".to_f > 3.to_f` → `true`.

**Boot-time validation limitations:**

Custom field definitions live in the database, not in YAML. The
`ConfigurationValidator` runs at boot time against YAML metadata and cannot
validate custom field names or types.

The `model_field_definition` helper returns `nil` for custom field names,
so operator–type validation is silently skipped. This is correct behavior —
custom fields are dynamic and cannot be statically validated at boot time.
Runtime evaluation handles them through the standard coercion path.

**Pre-existing bug: false-positive validation errors for custom fields in
conditions.** Two validation methods report custom field names as "unknown
field" on models with `custom_fields_enabled?`:

- `validate_condition` (presenter `visible_when`/`disable_when`)
  — line 567: no `has_custom_fields` skip
- `validate_permission_record_rules` (permission `record_rules`)
  — line 696: no `has_custom_fields` skip

Other validators (`validate_permission_fields` line 654,
`validate_permission_field_overrides` line 673) already skip unknown fields
when the model has custom fields enabled. The two condition validators must
follow the same pattern:

```ruby
# In validate_condition:
if field_name
  valid_fields = model_field_names(presenter.model)
  model_def = loader.model_definitions[presenter.model]
  has_custom_fields = model_def&.custom_fields_enabled?

  unless valid_fields.include?(field_name.to_s) || has_custom_fields
    @errors << "..."
  end
end

# Same pattern in validate_permission_record_rules
```

This fix is part of this task — it unblocks using custom fields in
`visible_when`, `disable_when`, and `record_rules` conditions.

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/lcp_ruby.rb` | Add `ConditionError < Error` |
| `lib/lcp_ruby/condition_evaluator.rb` | Strict `evaluate`: raise on unknown operator, missing field, nil condition. Strict `evaluate_any`: raise on nil, raise on unrecognized shape. Strict `evaluate_service`: raise on nil, raise on unregistered service. |
| `lib/lcp_ruby/authorization/permission_evaluator.rb` | Remove `matches_condition?`. Fix alias resolution in `can_for_record?`. Call `ConditionEvaluator.evaluate` directly. |
| `app/helpers/lcp_ruby/condition_helper.rb` | Add nil guard in `condition_met?` |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | Add operator–type compatibility checks. Fix custom field skip in `validate_condition` and `validate_permission_record_rules`. |
| `spec/lib/lcp_ruby/condition_evaluator_spec.rb` | Update tests: unknown operator → `ConditionError`, missing field → `ConditionError`, nil condition → `ArgumentError`. Add `evaluate_any` strict tests, `evaluate_service` strict tests. |
| `spec/lib/lcp_ruby/authorization/permission_evaluator_spec.rb` | Add tests for extended operators in record_rules, add alias resolution test, remove `matches_condition?` tests |
| `spec/lib/lcp_ruby/metadata/configuration_validator_spec.rb` | Add tests for operator–type validation errors. Add test: custom field name in condition on `custom_fields_enabled` model → no error. |

## Test Plan

### ConditionEvaluator

Update existing tests to expect strict behavior:

1. **Unknown operator**: `{ field: status, operator: "foo", value: "x" }` → raises `ConditionError`
2. **Missing field**: record without `status` method + condition on `status` → raises `ConditionError`
3. **Nil condition**: `evaluate(record, nil)` → raises `ArgumentError`
4. **`evaluate_any` with nil**: raises `ArgumentError`
5. **`evaluate_any` with unrecognized Hash** (no `field` or `service` key): raises `ConditionError`
6. **`evaluate_service` with nil**: raises `ArgumentError`
7. **`evaluate_service` with unregistered service**: raises `ConditionError`
8. All 12 existing operator tests remain unchanged.

### PermissionEvaluator

Add within `#can_for_record?`:

1. **Extended operators**: record_rule with `gt`, `gte`, `lt`, `lte`, `present`, `blank`, `matches`, `not_matches` — verify correct denial behavior.
2. **Alias resolution**: `can_for_record?("edit", archived_record)` denied when `deny_crud: [update]`.

### ConfigurationValidator

1. **`gt` on string field**: error reported.
2. **`matches` on integer field**: error reported.
3. **`gt` on decimal field**: no error.
4. **`matches` on custom type with `string` base type**: no error.
5. **`eq`, `present`, `blank` on any type**: no error (universally valid).
6. **Custom field name in condition** (model with `custom_fields_enabled`): no error (cannot statically validate DB-defined fields).
7. **Unknown field name in condition** (model without custom fields): error reported (unchanged behavior).

### Backward Compatibility

All callers that currently pass nil conditions (`visible_when` not set,
`disable_when` not set) must handle nil **before** calling the evaluator.
This is already the pattern in `ActionSet` (`return true unless visible_when`)
and other consumers. The change makes implicit contracts explicit.

```bash
bundle exec rspec spec/lib/lcp_ruby/condition_evaluator_spec.rb
bundle exec rspec spec/lib/lcp_ruby/authorization/permission_evaluator_spec.rb
bundle exec rspec spec/lib/lcp_ruby/metadata/configuration_validator_spec.rb
bundle exec rspec
```

---

## Forward Compatibility

This section documents architectural requirements for future extensions. The
proposed unification must remain compatible with these directions.

### Compound Conditions (all/any/not)

The workflow design doc (`docs/design/workflow_and_approvals.md`, section 4.1)
proposes compound conditions. When added, `ConditionEvaluator.evaluate` will
be extended to handle `all`/`any`/`not` recursively. Since
`PermissionEvaluator` now delegates fully to `ConditionEvaluator`, compound
conditions in record_rules work automatically — no changes to permission
evaluation needed.

**YAML syntax:**

```yaml
# AND — all conditions must be true
condition:
  all:
    - { field: title, operator: present }
    - { field: total_amount, operator: gt, value: 0 }

# OR — at least one condition must be true
condition:
  any:
    - { field: role, operator: eq, value: admin }
    - { field: stage, operator: eq, value: draft }

# NOT — condition must be false
condition:
  not: { field: stage, operator: eq, value: closed }

# Nested — arbitrary depth
condition:
  all:
    - { field: title, operator: present }
    - any:
      - { field: total_amount, operator: gt, value: 100000 }
      - all:
        - { field: priority, operator: eq, value: high }
        - { field: "company.industry", operator: eq, value: finance }
```

**DSL syntax:**

```ruby
# Simple condition (unchanged)
condition field: :status, operator: :eq, value: "active"

# Compound conditions with builder blocks
condition do
  all do
    field(:status).eq("active")
    field(:amount).gt(0)
    any do
      field(:role).eq("admin")
      field("company.industry").eq("finance")
    end
  end
end

# NOT
condition do
  not_condition do
    field(:stage).eq("closed")
  end
end

# In record_rules context
record_rule :complex_lock do
  condition do
    all do
      field(:stage).in(%w[closed_won closed_lost])
      field(:value).gt(10000)
    end
  end
  deny_crud :update, :destroy
  except_roles :admin
end
```

The DSL builder produces the same hash structure as YAML. Each `field(:name)`
returns a chainable object with operator methods (`.eq`, `.gt`, `.present`,
etc.) that emit `{ field:, operator:, value: }` hashes. `all`/`any`/`not_condition`
blocks collect child conditions into the corresponding compound structure.

### Additional Operators

Future operators to consider:

| Operator | Description | Use case |
|----------|-------------|----------|
| `starts_with` | String prefix match | Code prefixes (`TEMP-*`), categorized identifiers |
| `ends_with` | String suffix match | File extensions, domain matching |
| `contains` | Substring match (case-insensitive) | Fulltext-like checks without regex overhead |

These are additive — new `when` branches in the `case` statement. No
architectural changes needed.

### Dot-Path Fields in Conditions and Eager Loading

When conditions gain dot-path support (e.g., `{ field: "company.industry",
operator: eq, value: finance }`), associations referenced in conditions must
be preloaded to avoid N+1 queries.

**Dot-path validation rules:** The validator must check each segment of a
dot-path against model definitions and enforce these rules:

1. **`belongs_to`/`has_one` segments — valid.** Each segment resolves to
   exactly one record. `deal.company.country.code` is valid if every segment
   is `belongs_to` or `has_one`.

2. **`has_many` segment anywhere in the chain — invalid.** A `has_many`
   segment is ambiguous regardless of its position in the path:
   - `post.comments.author.name` — `comments` is `has_many`, ambiguous
   - `post.comments.body` — also invalid, even as the last association
   - `category.posts.title` — invalid, `posts` is `has_many`

   The validator must walk the association chain, check each segment's type,
   and raise a validation error if any segment is `has_many`. The error
   message should point the user to the collection condition syntax
   (`collection`/`quantifier`) as the correct way to express conditions on
   `has_many` associations.

### Collection Conditions (has_many quantifiers)

For conditions on `has_many` associations, an explicit quantifier syntax
removes ambiguity:

**YAML syntax:**

```yaml
# At least one comment is by john.smith
condition:
  collection: "comments"
  quantifier: any
  condition: { field: "author.name", operator: eq, value: "john.smith" }

# All comments must be by john.smith
condition:
  collection: "comments"
  quantifier: all
  condition: { field: "author.name", operator: eq, value: "john.smith" }

# No comment is by john.smith
condition:
  collection: "comments"
  quantifier: none
  condition: { field: "author.name", operator: eq, value: "john.smith" }

# Nested: collection condition inside compound condition
condition:
  all:
    - { field: stage, operator: eq, value: review }
    - collection: "approvals"
      quantifier: any
      condition: { field: status, operator: eq, value: approved }
```

**DSL syntax:**

```ruby
# At least one comment by john.smith
condition do
  collection(:comments, quantifier: :any) do
    field("author.name").eq("john.smith")
  end
end

# Combined with compound conditions
condition do
  all do
    field(:stage).eq("review")
    collection(:approvals, quantifier: :any) do
      field(:status).eq("approved")
    end
  end
end
```

**Quantifier values:**

| Quantifier | SQL mapping | Meaning |
|------------|-------------|---------|
| `any` | `EXISTS (SELECT 1 FROM ... WHERE ...)` | At least one child matches |
| `all` | `NOT EXISTS (SELECT 1 FROM ... WHERE NOT ...)` | Every child matches |
| `none` | `NOT EXISTS (SELECT 1 FROM ... WHERE ...)` | No child matches |

**Nested dot-paths within collection conditions** follow the same rules:
`belongs_to`/`has_one` chains only. The `field` inside a collection condition
is resolved relative to the collection's target model. So
`field: "author.name"` in a `comments` collection means
`comment.author.name` — valid if `author` is `belongs_to` on the comment
model.

**Eager loading:** Collection conditions with `any`/`none` quantifiers map
to `EXISTS` subqueries, which do NOT require eager loading — the database
handles the filtering. The `all` quantifier uses `NOT EXISTS` with negated
conditions, also a subquery. The `DependencyCollector` does not need to add
these associations to the includes list.

The existing `DependencyCollector` (`includes_resolver/dependency_collector.rb`)
already has the infrastructure for eager loading dot-paths —
`collect_dot_path_dep` (line 171) parses `"company.country.code"` into
`{ company: :country }` and adds it as a dependency. What's missing is just
an input source: a `from_conditions` method that walks condition trees
(recursively for compound conditions), extracts all `field` values with dots,
and feeds them into the existing `collect_dot_path_dep`. No new
infrastructure needed — just a new caller into the existing mechanism.

Service conditions (`{ service: "..." }`) are opaque and can't be statically
analyzed. For those, manual `includes`/`eager_load` in the presenter config
remains the escape hatch.

### Dynamic Value References

The workflow design doc (`docs/design/workflow_and_approvals.md`, section 4.3)
proposes dynamic value references. The `value` field in a condition can be a
literal or a typed reference hash that resolves at evaluation time.

Each reference type uses a **distinct top-level key** instead of a single
polymorphic `{ ref: "..." }` string. This makes references JSON-schema
validatable, avoids regex parsing, and is self-documenting in YAML.

**Planned reference types:**

| Key | Resolves to | Example |
|-----|-------------|---------|
| `field_ref` | Another field on the same record | `{ field_ref: budget_limit }` |
| `current_user` | Attribute of authenticated user | `{ current_user: id }` |
| `date` | Date/time constant | `{ date: today }` |
| `lookup` | Record in another model (future) | `{ lookup: tax_limit, match: {...}, pick: threshold }` |
| `service` | Value computed by host service | `{ service: calculate_threshold, params: {...} }` |

The `field_ref` key name matches the existing `field_ref` in comparison
validations (`validation_applicator.rb`), keeping the naming consistent
across the platform.

```yaml
# Field-to-field comparison: approved amount must not exceed budget
condition:
  field: approved_amount
  operator: lte
  value: { field_ref: budget_limit }

# Dot-path field reference
condition:
  field: deal_value
  operator: gt
  value: { field_ref: "company.credit_limit" }

# Only the author can submit
guard:
  field: author_id
  operator: eq
  value: { current_user: id }

# Deadline must be in the future
condition:
  field: deadline
  operator: gt
  value: { date: today }
```

**`date` reference values:**

| Value | Resolves to |
|-------|-------------|
| `today` | `Date.current` |
| `now` | `Time.current` |

No date arithmetic syntax (e.g., `today - 7.days`). Expressions like that
require a parser and introduce security/edge-case risks. Complex date
computations use **value services** instead (see below).

**Lookup into another model (codelist-like).** There is no dedicated codelist
infrastructure — any dynamic model (e.g., `tax_limit` with `key`/`value`
fields) serves as a lookup table. For now, this is handled via value
services (the service does `TaxLimit.find_by(key: :vat_a).value` internally).

A dedicated `lookup` syntax may be added later if the pattern becomes
frequent enough to justify it:

```yaml
# Future lookup syntax (not in current scope)
value:
  lookup: tax_limit                    # model name
  match: { key: vat_threshold_a }      # find_by conditions (can be multi-key)
  pick: threshold                      # which field to return from the found record
```

This maps to `TaxLimit.find_by(key: "vat_threshold_a").threshold`. The
`match` hash can contain multiple keys for compound lookups
(`match: { region: cz, type: vat }`). The `pick` key names the return
field — inspired by Rails' `ActiveRecord#pick` method.

**Impact on `evaluate` signature.** The evaluator gains an optional `context:`
keyword argument to carry request-scoped data (current user, precomputed
values):

```ruby
def self.evaluate(record, condition, context: {})
  # ...
  resolved_value = resolve_value(value, record, context)
  actual = record.send(field)
  compare(actual, resolved_value, operator)
end

def self.resolve_value(value, record, context)
  return value unless value.is_a?(Hash)

  normalized = value.transform_keys(&:to_s)

  if normalized.key?("field_ref")
    resolve_dot_path(record, normalized["field_ref"])
  elsif normalized.key?("current_user")
    context[:current_user]&.send(normalized["current_user"])
  elsif normalized.key?("date")
    resolve_date(normalized["date"])
  elsif normalized.key?("service")
    resolve_service_value(record, normalized, context)
  elsif normalized.key?("lookup")
    resolve_lookup(normalized)
  else
    value  # literal Hash (e.g., JSON value)
  end
end

def self.resolve_date(name)
  case name.to_s
  when "today" then Date.current
  when "now"   then Time.current
  else raise ConditionError, "Unknown date reference '#{name}'"
  end
end
```

**Coercion note.** The current `gt`/`gte`/`lt`/`lte` branches use `.to_f`
coercion. This works for numeric fields and for date/datetime literals from
YAML (strings like `"2025-06-01"` need parsing first). But when `value`
resolves to a native `Date`, `Time`, or `Numeric` via a reference, the
evaluator should compare natively using `<=>` instead of `.to_f`. This
avoids precision loss and works correctly for all comparable types. The
change is backward-compatible: `<=>` works for Numeric, Date, Time, and
String.

### Value Services (Parameterized)

The existing condition service contract is `def self.call(record) -> boolean`
— it replaces the **entire condition** and returns a boolean. Value services
are different: they provide a **value** for the `value` side of a condition,
while the operator is still applied by the evaluator.

```yaml
# Current: condition service (replaces entire condition, returns boolean)
visible_when: { service: "credit_check" }

# Future: value service (provides the comparison value)
condition:
  field: price
  operator: lt
  value:
    service: calculate_vat_threshold
    params:
      region: { field_ref: region }       # resolved from record before calling service
      country: { current_user: country }  # resolved from context
```

**Distinguishing condition services from value services.** The position in
the YAML determines the role:
- Top-level `{ service: "X" }` (replaces entire condition) → condition
  service, returns boolean
- Inside `value:` key `{ service: "X", params: {...} }` → value service,
  returns a comparable value

**Service contract:**

```ruby
# app/lcp_services/conditions/calculate_vat_threshold.rb
class CalculateVatThreshold
  # @param record [ActiveRecord::Base] the record being evaluated
  # @param params [Hash] resolved parameters from YAML config
  # @return [Object] a comparable value (not boolean)
  def self.call(record, **params)
    region = params[:region] || record.region
    TaxLimit.where(region: region).pick(:vat_threshold)
  end
end
```

The `params:` hash supports typed value references (`{ field_ref: X }`,
`{ current_user: X }`, etc.) — the evaluator resolves all references in
`params` before calling the service. Services receive already-resolved Ruby
values, not reference hashes.

**Caching.** Value services that don't depend on the record (e.g., looking
up a tax threshold by region where region is a literal, not a per-record
field) return the same value for every record in a list. The evaluator does
not cache service results — the **service is responsible for its own
caching**. Recommended patterns:

1. **Class-level memoization** for values that don't change within a request:
   ```ruby
   class VatThreshold
     def self.call(record, **params)
       @cache ||= {}
       @cache[params[:region]] ||= TaxLimit.where(region: params[:region]).pick(:vat_threshold)
     end

     def self.clear_cache!
       @cache = nil
     end
   end
   ```

2. **`RequestStore`** for per-request caching in concurrent environments
   (Puma):
   ```ruby
   def self.call(record, **params)
     RequestStore.store[:vat_thresholds] ||= {}
     RequestStore.store[:vat_thresholds][params[:region]] ||= ...
   end
   ```

3. **Pre-resolved context.** For permission evaluation on index pages (many
   records), the controller can pre-resolve value services once and pass
   results via `context:`:
   ```ruby
   # In controller:
   ctx = { vat_threshold: TaxLimit.pick(:vat_threshold) }
   evaluator.can_for_record?(action, record, context: ctx)
   ```
   This is an optimization for hot paths, not a requirement. Services work
   without it.

### Compatibility with External Filter Engines (Ransack)

The eager loading architecture works independently of any external filter
engine. Key reasons:

1. **ActiveRecord merges duplicate JOINs.** `IncludesResolver` produces
   `includes`, `eager_load`, and `joins` lists. Ransack generates its own
   JOINs for WHERE conditions. When both add `.joins(:company)`, AR
   deduplicates them.

2. **Reason-based strategy handles has_many correctly.** `StrategyResolver`
   distinguishes `:display` (preload) from `:query` (JOIN for WHERE/ORDER).
   For `has_many` with `:query`, it chooses `joins` + `includes` instead of
   `eager_load`, avoiding cartesian product issues with pagination. Ransack
   does the same — `joins` for filtering. The two chain cleanly on the scope.

3. **Controller scope chain is additive.** Today:
   ```ruby
   scope = policy_scope(@model_class)   # WHERE from permissions
   scope = apply_search(scope)           # WHERE from search
   scope = strategy.apply(scope)         # includes/eager_load/joins
   scope = scope.page(...)               # pagination
   ```
   An external filter engine slots in as another `.where`/`.joins` step —
   `IncludesResolver` neither depends on it nor interferes with it.

4. **Permission-aware whitelisting.** Ransack requires `ransackable_attributes`
   and `ransackable_associations`. These should be derived from permission
   metadata (`PermissionEvaluator.readable_fields` and model associations) so
   that users can only search fields they have permission to read.
