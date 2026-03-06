# Feature Specification: Advanced Conditions

**Status:** Implemented
**Date:** 2026-03-06

## Problem / Motivation

The platform's condition system currently supports only simple field-value comparisons (`{ field, operator, value }`) and opaque service conditions (`{ service }`). This covers basic use cases, but professional information systems need more expressive conditions:

- **Multiple criteria at once** — "lock the record when status is closed AND value exceeds 10,000". Today, each `record_rule`, `visible_when`, or `disable_when` accepts a single condition. Users must create multiple rules and accept OR-like behavior, or fall back to custom condition services for every AND combination.
- **Comparing two fields on the same record** — "approved amount must not exceed budget limit". Today the `value` side is always a literal from YAML. There is no way to reference another field or the current user without writing a custom service.
- **Date-relative conditions** — "highlight overdue items where due_date < today". Today the value must be a hardcoded date string, making the condition stale immediately.
- **Dot-path traversal** — "show action only when company.country is CZ". Today conditions can only reference direct fields on the record, not associated objects.
- **Collection conditions** — "deal is approvable when at least one approval has status 'approved'". Today there is no way to express quantifiers over has_many associations.

These gaps force developers to write one-off condition services for common patterns, defeating the purpose of a declarative low-code platform.

## User Scenarios

**As a business analyst,** I want to define a record rule that locks editing when status is "closed" AND value exceeds 100,000, so I can express complex business rules in YAML without writing Ruby code.

**As a CRM administrator,** I want to disable the "submit" action when approved_amount exceeds the record's own budget_limit field, so the platform enforces the constraint declaratively.

**As a project manager,** I want overdue tasks (due_date < today) highlighted in the index, with "today" resolving dynamically rather than being a hardcoded date.

**As a platform developer,** I want to write `visible_when: { field: "company.industry", operator: eq, value: "finance" }` to control action visibility based on an associated record's field, without writing a condition service.

**As a workflow designer,** I want to gate a transition on "at least one approval is approved" using `collection: approvals, quantifier: any`, so approval logic is declarative.

**As a security officer,** I want record rules that check `author_id == current_user.id` to restrict editing to the record owner, without a custom service per model.

## Configuration & Behavior

### 1. Compound Conditions (all / any / not)

Combine multiple conditions with logical operators. Nesting is supported to arbitrary depth.

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
```

**Behavior:**
- `all` — returns true only if every child condition is true (empty list = true).
- `any` — returns true if at least one child condition is true (empty list = false).
- `not` — returns the boolean negation of its single child condition.
- The DSL builder produces the same hash structure as YAML. `field(:name)` returns a chainable object with operator methods (`.eq`, `.gt`, `.present`, etc.) that emit `{ field:, operator:, value: }` hashes.
- Since `PermissionEvaluator` delegates to `ConditionEvaluator`, compound conditions in `record_rules` work automatically.

**Usable in:** `record_rules.condition`, `visible_when`, `disable_when`, `item_classes.when`, row styling rules — anywhere the platform accepts a condition hash.

### 2. Dynamic Value References

The `value` side of a condition can be a typed reference hash that resolves at evaluation time instead of a literal.

| Key | Resolves to | Example |
|-----|-------------|---------|
| `field_ref` | Another field on the same record (supports dot-paths) | `{ field_ref: "company.credit_limit" }` |
| `current_user` | Attribute of the authenticated user | `{ current_user: id }` |
| `date` | Dynamic date/time constant | `{ date: today }` |
| `lookup` | Value from another model's record | `{ lookup: tax_limit, match: { key: vat_a }, pick: threshold }` |

Each reference type uses a **distinct top-level key** (not a polymorphic `{ ref: "..." }` string). This makes references JSON-schema validatable and self-documenting.

**YAML examples:**

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

# Only the record author can submit
condition:
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

No date arithmetic syntax (e.g., `today - 7.days`). Complex date computations use value services instead.

**`lookup` reference:**

Queries another model for a value. This is the primary mechanism for referencing codelists, system constants, and other reference data in conditions.

```yaml
# Price must be below the VAT threshold for the record's region
condition:
  field: price
  operator: lt
  value:
    lookup: tax_limit
    match: { region: vat_a }
    pick: threshold

# Match against a codelist value
condition:
  field: category_code
  operator: eq
  value:
    lookup: codelist_entry
    match: { codelist: product_categories, key: electronics }
    pick: value

# Dynamic match using field_ref
condition:
  field: discount_rate
  operator: lte
  value:
    lookup: discount_policy
    match: { tier: { field_ref: customer_tier } }
    pick: max_discount
```

- `lookup` — the model name (resolved via `LcpRuby.registry`).
- `match` — a hash of field-value pairs used as `WHERE` conditions. Values can be literals or typed references (`field_ref`, `current_user`).
- `pick` — the column name whose value is returned (like `ActiveRecord#pick`).
- If no record matches, raises `ConditionError`. If multiple records match, uses the first one (the model should define a unique constraint or the match should be specific enough).

**Impact on `evaluate` signature.** The evaluator gains an optional `context:` keyword argument to carry request-scoped data (current user, precomputed values):

```ruby
def self.evaluate(record, condition, context: {})
  # ...
  resolved_value = resolve_value(value, record, context)
  compare(actual, resolved_value, operator)
end
```

**Coercion change.** The current `gt`/`gte`/`lt`/`lte` branches use `.to_f` coercion. When `value` resolves to a native `Date`, `Time`, or `Numeric` via a reference, the evaluator should compare natively using `<=>` instead of `.to_f`. This avoids precision loss and works correctly for all comparable types.

### 3. Dot-Path Fields in Conditions

Conditions can reference fields on associated records using dot-path syntax (e.g., `company.industry`).

```yaml
visible_when:
  field: "company.country.code"
  operator: eq
  value: "CZ"
```

**Validation rules:**
- **`belongs_to` / `has_one` segments only.** Each segment resolves to exactly one record. `deal.company.country.code` is valid if every association segment is `belongs_to` or `has_one`.
- **`has_many` segment anywhere in the chain is invalid.** A `has_many` is ambiguous — the validator must walk the association chain, check each segment's type, and raise a validation error pointing the user to collection conditions as the correct alternative.

**Eager loading:** Dot-path conditions trigger association access at evaluation time. On index pages (row styling, record_rules), this causes N+1 queries if the association is not preloaded. The platform does **not** auto-preload associations from conditions — the configurator must explicitly declare them in the presenter's `includes` configuration. The `ConfigurationValidator` checks that all associations referenced in conditions are covered by `includes` / `eager_load` and reports a clear error with a fix suggestion if not (see [Eager Loading Validation](#eager-loading-validation) below).

Service conditions (`{ service: "..." }`) are opaque and cannot be statically analyzed. Manual `includes` / `eager_load` in presenter config remains the escape hatch for those.

### 4. Collection Conditions (has_many quantifiers)

For conditions on `has_many` associations, an explicit quantifier syntax removes ambiguity.

**YAML syntax:**

```yaml
# At least one comment is by john.smith
condition:
  collection: "comments"
  quantifier: any
  condition: { field: "author.name", operator: eq, value: "john.smith" }

# All line items must be approved
condition:
  collection: "line_items"
  quantifier: all
  condition: { field: status, operator: eq, value: "approved" }

# No rejection exists
condition:
  collection: "approvals"
  quantifier: none
  condition: { field: status, operator: eq, value: "rejected" }

# Nested inside compound conditions
condition:
  all:
    - { field: stage, operator: eq, value: review }
    - collection: "approvals"
      quantifier: any
      condition: { field: status, operator: eq, value: approved }
```

**DSL syntax:**

```ruby
condition do
  all do
    field(:stage).eq("review")
    collection(:approvals, quantifier: :any) do
      field(:status).eq("approved")
    end
  end
end
```

**Quantifier semantics:**

| Quantifier | SQL mapping | Meaning |
|------------|-------------|---------|
| `any` | `EXISTS (SELECT 1 FROM ... WHERE ...)` | At least one child matches |
| `all` | `NOT EXISTS (SELECT 1 FROM ... WHERE NOT ...)` | Every child matches |
| `none` | `NOT EXISTS (SELECT 1 FROM ... WHERE ...)` | No child matches |

**Eager loading:** Collection conditions are evaluated in-memory against preloaded associations. The configurator must explicitly include the referenced has_many association (and any nested dot-path associations within the inner condition) in the presenter's `includes`. The `ConfigurationValidator` enforces this — see [Eager Loading Validation](#eager-loading-validation) below.

**Nested dot-paths within collection conditions** follow the same rules as standalone dot-paths: `belongs_to` / `has_one` chains only. The `field` inside a collection is resolved relative to the collection's target model.

### 5. Value Services (Parameterized)

Value services provide a **computed value** for the `value` side of a condition. They differ from condition services (which replace the entire condition and return a boolean).

```yaml
# Condition service (replaces entire condition, returns boolean)
visible_when: { service: "credit_check" }

# Value service (provides the comparison value)
condition:
  field: price
  operator: lt
  value:
    service: calculate_vat_threshold
    params:
      region: { field_ref: region }
      country: { current_user: country }
```

**Distinguishing the two:** Position in YAML determines the role. Top-level `{ service: "X" }` is a condition service (boolean). Inside `value:` key `{ service: "X", params: {...} }` is a value service (returns a comparable value).

**Service contract:**

```ruby
# app/lcp_services/conditions/calculate_vat_threshold.rb
class CalculateVatThreshold
  # @param record [ActiveRecord::Base]
  # @param params [Hash] resolved parameters from YAML config
  # @return [Object] a comparable value (not boolean)
  def self.call(record, **params)
    TaxLimit.where(region: params[:region]).pick(:vat_threshold)
  end
end
```

The `params:` hash supports typed value references (`field_ref`, `current_user`, etc.) — the evaluator resolves all references before calling the service.

**Caching:** The evaluator does not cache service results. The service is responsible for its own caching (class-level memoization, `RequestStore`, or pre-resolved context passed via `context:`).

### 6. Additional Operators

New string operators to reduce the need for `matches` / regex:

| Operator | Description | Compatible types |
|----------|-------------|-----------------|
| `starts_with` | String prefix match | string, text, email, phone, url, color |
| `ends_with` | String suffix match | string, text, email, phone, url, color |
| `contains` | Case-insensitive substring match | string, text, email, phone, url, color |

These are additive — new `when` branches in the existing `case` statement. No architectural changes needed. `ConfigurationValidator` operator-type rules must be updated to include these in the text-compatible group.

## Usage Examples

### Complex record rule with compound conditions

```yaml
# permissions/deals.yml
record_rules:
  - name: high_value_closed_locked
    condition:
      all:
        - { field: stage, operator: in, value: [closed_won, closed_lost] }
        - { field: value, operator: gt, value: 10000 }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

### Owner-only editing

```yaml
record_rules:
  - name: owner_only_edit
    condition:
      not:
        field: author_id
        operator: eq
        value: { current_user: id }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin, manager]
```

### Conditional visibility based on associated record

```yaml
# presenters/deals.yml
actions:
  - name: submit_for_review
    type: custom
    on: single
    visible_when:
      all:
        - { field: stage, operator: eq, value: draft }
        - { field: "company.verified", operator: eq, value: true }
```

### Collection-based workflow gate

```yaml
# presenters/purchase_orders.yml
actions:
  - name: finalize
    type: custom
    on: single
    visible_when:
      all:
        - { field: status, operator: eq, value: pending_approval }
        - collection: "approvals"
          quantifier: any
          condition: { field: decision, operator: eq, value: approved }
    disable_when:
      collection: "line_items"
      quantifier: any
      condition: { field: price, operator: lte, value: 0 }
```

### Dynamic date comparison in row styling

```yaml
# presenters/tasks.yml
index:
  item_classes:
    - class: "lcp-row-danger"
      when:
        all:
          - { field: status, operator: not_eq, value: done }
          - { field: due_date, operator: lt, value: { date: today } }
```

## General Implementation Approach

### ConditionEvaluator extension

The evaluator's `evaluate` method is extended to detect compound keys (`all`, `any`, `not`) and recurse:

1. Normalize the condition hash keys to strings.
2. If the hash has an `all` key, evaluate each child and return true only if all are true.
3. If the hash has an `any` key, evaluate each child and return true if at least one is true.
4. If the hash has a `not` key, evaluate the single child and negate.
5. If the hash has a `collection` key, delegate to collection evaluation (EXISTS subquery or in-memory iteration depending on context).
6. If the hash has a `field` key, proceed with the existing field-value evaluation.
7. If the hash has a `service` key, proceed with service evaluation.
8. Otherwise, raise `ConditionError`.

The `evaluate_any` entry point becomes the recursive dispatcher. A new `resolve_value` private method handles value references before comparison:
- `field_ref` — calls `record.send` (or dot-path traversal via `resolve_dot_path`) to get the other field's value. Supports dot-paths like `"company.credit_limit"`.
- `current_user` — reads the attribute from `context[:current_user]`.
- `date` — resolves `today` / `now` to `Date.current` / `Time.current`.
- `lookup` — resolves `match` values (which may contain references), queries the target model via `registry.model_for(name).where(resolved_match).pick(column)`.
- `service` (inside value) — resolves params, calls the value service.
- Plain literal — used as-is.

### Dot-path field resolution

When `field` contains a dot, the evaluator traverses the association chain: `"company.country.code"` becomes `record.company.country.code` via successive `send` calls. Each intermediate `nil` raises `ConditionError` (or returns a configurable default for `blank` / `present` operators).

### Collection evaluation

For `collection` conditions, the evaluator iterates the already-loaded association in memory and applies the quantifier:
- `any` — `collection.any? { |r| evaluate(r, inner_condition) }`
- `all` — `collection.all? { |r| evaluate(r, inner_condition) }`
- `none` — `collection.none? { |r| evaluate(r, inner_condition) }`

This requires that the association is preloaded via `includes` in the presenter. The `ConfigurationValidator` enforces this at boot time (see below). A SQL-based `EXISTS` path is a possible future optimization but is not part of this specification.

### ConfigurationValidator

The validator is extended to:
- Recognize `all`, `any`, `not` keys and recursively validate child conditions.
- Validate dot-path fields by walking the association chain and rejecting `has_many` segments.
- Validate `collection` conditions: check that the named association exists and is `has_many`.
- Validate value references (`field_ref`, `current_user`, `date`) — check that referenced fields exist.
- Add `starts_with`, `ends_with`, `contains` to the text-compatible operator group.
- Validate eager loading coverage for conditions (see below).

### Eager Loading Validation

The platform does **not** auto-preload associations referenced in conditions. Instead, the `ConfigurationValidator` analyzes all conditions in a presenter context (`item_classes[].when`, `visible_when`, `disable_when`, `record_rules[].condition`) and checks that every referenced association is covered by the presenter's `includes` or `eager_load` configuration.

**What the validator checks:**
1. **Dot-path fields** — extracts association segments from `field: "company.country.code"` → requires `company` (or `{ company: :country }`) in `includes`.
2. **Collection conditions** — `collection: "approvals"` → requires `approvals` in `includes`.
3. **Nested dot-paths inside collections** — `collection: "comments"` with inner `field: "author.name"` → requires `{ comments: :author }` in `includes`.
4. **Value references with dot-paths** — `value: { field_ref: "company.credit_limit" }` → requires `company` in `includes`.

**Error messages guide the configurator to the fix:**

```
Presenter 'tasks' index: item_classes condition references 'company.verified'
(association :company) but index.includes does not contain :company.
Add 'includes: [company]' to the index configuration to avoid N+1 queries.
```

```
Presenter 'orders' index: item_classes collection condition references
'approvals' but index.includes does not contain :approvals.
Add 'includes: [approvals]' to the index configuration.
```

```
Presenter 'orders' index: item_classes collection 'comments' inner condition
references 'author.name' (association :author on comment model) but
index.includes does not contain { comments: :author }.
Add 'includes: [{ comments: :author }]' to the index configuration.
```

**Why explicit over automatic:**
- The configurator sees exactly what is being loaded — no hidden queries or unexpected JOINs.
- `strict_loading: :development` serves as a runtime safety net catching any missed associations.
- Different presenters over the same model can have different eager loading needs — only the presenter with dot-path/collection conditions pays the cost.
- Auto-preloading would hide performance implications and make debugging harder.

**Scope:** This validation applies only to index-context conditions (`item_classes`, `record_rules` evaluated per-row, action `visible_when` / `disable_when` on index). Show-page conditions evaluate against a single record where lazy loading is acceptable.

### context: propagation

All callers that invoke `ConditionEvaluator` must pass the evaluation context. The controller builds the context hash (containing `current_user` at minimum) and threads it through `PermissionEvaluator`, `ActionSet`, `condition_helper`, and view slot rendering. This is the main integration surface area.

## Decisions

1. **Distinct keys for value references** (`field_ref`, `current_user`, `date`) rather than a polymorphic `{ ref: "type:path" }` string. Rationale: JSON-schema validatable, no regex parsing, self-documenting in YAML.

2. **No date arithmetic syntax.** `today - 7.days` requires a parser and introduces security/edge-case risks. Complex date computations use value services.

3. **`has_many` in dot-paths is always invalid.** Even as the last segment, a `has_many` is ambiguous. Users must use the `collection` / `quantifier` syntax instead.

4. **Value services are responsible for their own caching.** The evaluator does not cache service results. Recommended patterns: class-level memoization, `RequestStore`, or pre-resolved context.

5. **In-memory collection evaluation only.** Collections are preloaded via explicit `includes` and evaluated in-memory. SQL `EXISTS` subqueries are a possible future optimization but not part of this specification. This keeps the implementation simple — one evaluation path for all condition types.

6. **The `not` key accepts a single condition, not an array.** For negating multiple conditions, use `not: { all: [...] }` or `not: { any: [...] }`.

7. **No auto-preloading of associations from conditions.** The configurator must explicitly declare `includes` for associations referenced in conditions. The `ConfigurationValidator` emits warnings at boot time with actionable fix suggestions. `DependencyCollector` auto-includes associations at runtime as a safety net. Rationale: explicit is better than implicit — the configurator sees what is loaded, different presenters over the same model have different needs, and `strict_loading: :development` provides an additional runtime safety net.

8. **`lookup` value reference implemented.** Syntax: `{ lookup: tax_limit, match: { key: vat_a }, pick: threshold }`. Resolves by calling `find_by` on the target model. Match values support dynamic references (`field_ref`, `current_user`, `date`) but NOT nested lookups. The `ConfigurationValidator` validates that the target model, match keys, and pick field all exist. The DSL provides `ConditionBuilder.lookup(model, match:, pick:)` helper.

8. **`all` with an empty list returns true (vacuous truth).** Mathematically correct and consistent with Ruby's `[].all?`. The `ConfigurationValidator` emits a warning for empty `all` / `any` lists since they likely indicate a configuration mistake.

9. **Collection condition performance deferred to virtual columns.** Large has_many associations loaded into memory for boolean checks are a known concern. This is addressed by the [Virtual Columns](virtual_columns.md) specification, which provides SQL-level aggregation as an alternative to in-memory evaluation for performance-critical paths.

10. **`field_ref` supports dot-paths.** `{ field_ref: "company.credit_limit" }` is supported. The added complexity is minimal — `resolve_value` delegates to the same `resolve_dot_path` helper already used for `field` dot-path resolution. The `ConfigurationValidator` already walks association chains for `field` dot-paths and needs only one additional call site (~5-10 lines) to also validate `field_ref` values. Eager loading validation for `field_ref` dot-paths is already covered in the spec (see Eager Loading Validation, item 4).

11. **`lookup` value reference included in initial implementation.** The `lookup` key (`{ lookup: tax_limit, match: { key: vat_a }, pick: threshold }`) queries another model for a comparison value. This is essential for codelists and system-defined constants — without it, every codelist comparison requires a custom value service. This is the primary mechanism for referencing platform-managed reference data in conditions.

12. **QueryLanguageParser integration deferred.** Compound conditions (`all` / `any` / `not`) do not have a QL text representation in this version. The QL parser continues to work with simple field-value conditions. A future version may extend the QL syntax to support `AND` / `OR` / `NOT` operators and serialize compound condition trees.

## Open Questions

None at this time — all questions have been resolved (see Decisions 8–12).
