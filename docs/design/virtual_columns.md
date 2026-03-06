# Feature Specification: Virtual Columns (Generalized Query Extensions)

**Status:** Proposed
**Date:** 2026-03-05

## Problem / Motivation

The platform's `aggregates` mechanism allows defining virtual computed columns via SQL subqueries (COUNT, SUM, etc.) on has_many associations. This works well for its original purpose, but several use cases require similar SQL-level query extensions that don't fit the "aggregate function over association" pattern:

- **EXISTS checks for conditions** — "does this order have at least one approved approval?" needs `EXISTS(SELECT 1 FROM approvals WHERE ...)` as a virtual boolean column. Today this requires either preloading the entire has_many into memory (wasteful for large collections) or writing a condition service (boilerplate for a common pattern).
- **Cross-model JOIN columns** — "show company name on the order index" via a LEFT JOIN instead of eager loading. Today the platform uses dot-path + eager_load, which works but doesn't allow computed expressions across joined tables (e.g., `companies.name || ' (' || companies.country || ')'`).
- **Complex aggregations with JOINs** — "total line value = SUM(line_items.quantity * line_items.unit_price)" requires a JOIN and GROUP BY, which the current aggregate system cannot express — it only supports correlated subqueries over a single association.
- **Derived boolean/status columns** — "is_overdue = (due_date < CURRENT_DATE AND status != 'done')" as a computed SQL column, usable in sorting, filtering, and row styling conditions. Today this must be a Ruby method (no SQL sorting) or a raw SQL aggregate (which is conceptually wrong — it's not an aggregation).
- **Window functions** — "rank within category" or "running total" require `OVER(PARTITION BY ...)` which doesn't fit correlated subqueries.

The current `aggregates` key tries to serve some of these via the `sql:` escape hatch, but its naming, validation, and mental model are misleading — a developer writing `EXISTS(...)` or a CASE expression shouldn't have to think "this is an aggregate".

### What Works Today

| Need | Current mechanism | Limitation |
|------|-------------------|------------|
| COUNT/SUM/MIN/MAX/AVG over has_many | `aggregates` (declarative) | Only simple aggregate functions, single association, no JOINs |
| Arbitrary SQL subquery | `aggregates` with `sql:` key | Works, but naming is confusing ("aggregate" for a non-aggregate) |
| Service-computed value | `aggregates` with `service:` key | Works, but per-record evaluation — no SQL sorting |
| Associated field display | Dot-path + eager loading | No computed expressions, no SQL-level filtering |
| Boolean condition check | Condition service or preload + in-memory | No SQL column — can't sort, can't use in WHERE |

## User Scenarios

**As a platform configurator,** I want to define `has_approved_approval` as a virtual boolean column on my order model, so I can use it in row styling conditions (`item_classes`) and sort the index by approval status — all without writing Ruby code.

**As a CRM configurator,** I want to show `company_display` (a concatenation of company name and country) as a sortable column on the deals index, computed via a LEFT JOIN at the SQL level.

**As an advanced configurator,** I want to define `total_line_value` using a JOIN + SUM + GROUP that the current aggregate system can't express, without falling back to a service aggregate that can't be sorted.

**As a platform configurator,** I want `is_overdue` as a virtual boolean column derived from `due_date < CURRENT_DATE AND status != 'done'`, usable in conditions, sorting, and display — not hidden inside a condition service.

**As a host app developer,** I want to write a Ruby class that provides both a SQL expression (for sorting/filtering) and a fallback Ruby method (for complex logic), using Arel for DB portability.

## Configuration & Behavior

### Minimal key set

All virtual columns are expressible with just three keys beyond the existing `function` + `association` declarative sugar:

| Key | Purpose | Required |
|-----|---------|----------|
| `expression` | SQL expression projected into SELECT (aliased as the column name) | Yes (unless `function`+`association` or `service`) |
| `join` | SQL JOIN clause added to the outer scope | No |
| `group` | Whether GROUP BY parent_table.id is needed | No (default: false) |

The existing `function` + `association` + `where` declarative syntax is sugar that generates a correlated subquery internally. The `service` key delegates to a Ruby class. Everything else uses `expression` (optionally with `join` and `group`).

### YAML syntax

```yaml
virtual_columns:
  # Declarative aggregate — unchanged from current aggregates syntax
  issues_count:
    function: count
    association: issues

  open_issues_count:
    function: count
    association: issues
    where: { status: open }

  total_revenue:
    function: sum
    association: orders
    source_field: amount
    default: 0

  # EXISTS check — raw expression, no special subtype needed
  has_approved_approval:
    expression: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"
    type: boolean

  # Derived boolean — inline expression on own table
  is_overdue:
    expression: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
    type: boolean

  # JOIN-based display column
  company_display:
    expression: "companies.name || ' (' || companies.country || ')'"
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"
    type: string

  # JOIN-based aggregate (needs GROUP BY)
  total_line_value:
    expression: "COALESCE(SUM(line_items.quantity * line_items.unit_price), 0)"
    join: "LEFT JOIN line_items ON line_items.order_id = %{table}.id"
    group: true
    type: decimal

  # Window function
  category_rank:
    expression: "ROW_NUMBER() OVER(PARTITION BY %{table}.category_id ORDER BY %{table}.created_at DESC)"
    type: integer

  # LATERAL JOIN (PostgreSQL) — top-N per group
  latest_comment_body:
    expression: "latest_comment.body"
    join: "LEFT JOIN LATERAL (SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1) AS latest_comment ON true"
    type: string

  # Service-based — unchanged from current aggregates syntax
  health_score:
    service: project_health
    type: integer

  # Complex correlated subquery with internal JOIN
  weighted_approval_score:
    expression: "(SELECT SUM(a.weight * al.priority) FROM approvals a JOIN approval_levels al ON al.id = a.level_id WHERE a.order_id = %{table}.id)"
    type: float
```

### DSL syntax

```ruby
define_model :order do
  # Declarative aggregate — old syntax still works
  aggregate :issues_count, function: :count, association: :issues

  # New unified syntax
  virtual_column :has_approved_approval, type: :boolean,
    expression: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"

  virtual_column :is_overdue, type: :boolean,
    expression: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"

  virtual_column :company_display, type: :string,
    expression: "companies.name || ' (' || companies.country || ')'",
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"

  virtual_column :category_rank, type: :integer,
    expression: "ROW_NUMBER() OVER(PARTITION BY %{table}.category_id ORDER BY %{table}.created_at DESC)"
end
```

### Default inclusion

Virtual columns are defined on the model but **not included in queries by default**. Each definition has an `auto_include` attribute (default: `false`). The presenter controls which virtual columns are added to the query scope.

```yaml
virtual_columns:
  # Always included when any presenter queries this model
  is_overdue:
    expression: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
    type: boolean
    auto_include: true

  # Only included when a presenter explicitly references it
  weighted_approval_score:
    expression: "(SELECT SUM(...) FROM ...)"
    type: float
    # auto_include: false (default)
```

The controller collects virtual columns to include from multiple sources:

**Auto-detected (implicit)** — the controller scans YAML metadata for virtual column name references in:

| Source | Example |
|--------|---------|
| Presenter `table_columns` | `{ field: is_overdue }` |
| Presenter `tile_fields` | `{ field: is_overdue }` |
| Presenter `item_classes[].when` | `{ field: is_overdue, operator: eq, value: "true" }` |
| Presenter `layout` (show page fields) | field reference in section |
| Permission `scope` | `scope: { is_overdue: true }` |
| Permission `record_rules[].when` | `{ field: is_overdue, operator: eq, value: "true" }` |
| Ransack sort params (runtime) | `?q[s]=is_overdue+asc` |

**Explicit** — listing additional virtual columns via the `virtual_columns` key. This is needed when Ruby code (custom actions, condition services, event handlers) accesses a virtual column that can't be auto-detected from YAML:

```yaml
# presenters/orders.yml
index:
  virtual_columns: [weighted_approval_score]  # add to query even if not in table_columns
  table_columns:
    - { field: title }
    - { field: is_overdue }   # auto-detected from table_columns

# Actions can also declare virtual column dependencies
actions:
  - name: escalate
    type: custom
    virtual_columns: [health_score]  # action handler reads health_score from record

# Scopes can declare dependencies too
scopes:
  - name: critical
    virtual_columns: [health_score]  # scope filter uses health_score
```

**Always included** — virtual columns with `auto_include: true` are added to every query for that model, regardless of presenter configuration. Use this sparingly — only for columns needed across all presenters (e.g., a universal status flag used in permission scopes).

### Window Functions

Window functions work naturally with the `expression` key — no special subtype needed:

```yaml
virtual_columns:
  # Rank within category
  category_rank:
    expression: "ROW_NUMBER() OVER(PARTITION BY %{table}.category_id ORDER BY %{table}.created_at DESC)"
    type: integer

  # Running total
  cumulative_revenue:
    expression: "SUM(%{table}.amount) OVER(ORDER BY %{table}.created_at ROWS UNBOUNDED PRECEDING)"
    type: decimal

  # Percentile rank
  value_percentile:
    expression: "PERCENT_RANK() OVER(ORDER BY %{table}.value)"
    type: float
```

Window functions don't need `join` or `group` — they operate on the result set. They interact with pagination: window functions are computed over the **full** result set (after WHERE, before LIMIT/OFFSET). This means `ROW_NUMBER()` produces globally correct ranks — page 2 shows ranks 26–50, not 1–25. This is usually what the user wants (rank within the entire dataset). For rank within only the visible page, the configurator would need a wrapping subquery, but this is rarely useful.

### LATERAL JOIN (PostgreSQL)

PostgreSQL's `LATERAL` keyword enables powerful per-row subqueries that can reference columns from the outer query. This solves use cases that correlated subqueries handle awkwardly — especially fetching fields from the latest child record:

```yaml
virtual_columns:
  # Latest comment body for each order
  latest_comment_body:
    expression: "lc.body"
    join: "LEFT JOIN LATERAL (SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1) AS lc ON true"
    type: string

  # Most recent approval with multiple fields
  last_approver_name:
    expression: "la.approver_name"
    join: "LEFT JOIN LATERAL (SELECT a.approver_name FROM approvals a WHERE a.order_id = %{table}.id ORDER BY a.created_at DESC LIMIT 1) AS la ON true"
    type: string
```

LATERAL JOINs are PostgreSQL-specific. The platform does not abstract DB differences in raw SQL — the configurator is responsible for using DB-compatible syntax. For DB-portable logic, use service virtual columns with Arel (see [Service with Arel](#service-with-arel) below).

**Multiple LATERAL JOINs** referencing different subqueries compose cleanly — each is an independent per-row lookup, no cartesian product risk.

#### Multiple columns from one LATERAL JOIN

When multiple virtual columns reference the same child record (e.g., both body and title of the latest comment), they can share a single LATERAL JOIN using a YAML anchor:

```yaml
virtual_columns:
  latest_comment_body:
    expression: "lc.body"
    join: &latest_comment_join >-
      LEFT JOIN LATERAL (
        SELECT c.body, c.title, c.author_name FROM comments c
        WHERE c.order_id = %{table}.id
        ORDER BY c.created_at DESC LIMIT 1
      ) AS lc ON true
    type: string

  latest_comment_title:
    expression: "lc.title"
    join: *latest_comment_join
    type: string

  latest_comment_author:
    expression: "lc.author_name"
    join: *latest_comment_join
    type: string
```

The YAML anchor (`&latest_comment_join` / `*latest_comment_join`) avoids duplicating the JOIN string. The builder deduplicates identical JOIN strings — one JOIN in SQL, three SELECT aliases.

#### Top-N child records

Virtual columns are **scalar** — one value per parent row. A LATERAL JOIN with `LIMIT 2` would duplicate the parent row, breaking index pagination. For top-N, aggregate the results into a single value:

**JSON aggregation (recommended):**

```yaml
virtual_columns:
  latest_2_comments:
    expression: >-
      (SELECT json_agg(sub ORDER BY sub.created_at DESC)
       FROM (SELECT c.body, c.title, c.created_at
             FROM comments c
             WHERE c.order_id = %{table}.id
             ORDER BY c.created_at DESC LIMIT 2) sub)
    type: json
```

Result: `[{"body": "Great!", "title": "Review", "created_at": "2026-03-05"}, {"body": "...", ...}]` — one JSON array per row, renderable with a custom renderer.

**Array aggregation (PostgreSQL, single field):**

```yaml
virtual_columns:
  latest_comment_bodies:
    expression: "ARRAY(SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 2)"
    type: string
```

Result: `{"First comment","Second comment"}` — simpler, but limited to one field.

**Separate columns with OFFSET (small N only):**

```yaml
virtual_columns:
  latest_comment_1:
    expression: "(SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1 OFFSET 0)"
    type: string

  latest_comment_2:
    expression: "(SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1 OFFSET 1)"
    type: string
```

Two independent subqueries — simple but doesn't scale (top-5 = 5 subqueries).

### Service with Arel

For DB-portable virtual columns or complex Ruby logic, the `service` key delegates to a Ruby class. The service can use Arel to generate DB-agnostic SQL:

```ruby
# app/lcp_services/virtual_columns/is_overdue.rb
class IsOverdue
  # Per-record evaluation (show page, fallback)
  def self.call(record, options: {})
    record.due_date.present? && record.due_date < Date.current && record.status != "done"
  end

  # SQL expression for index queries (DB-portable via Arel)
  def self.sql_expression(model_class, options: {})
    t = model_class.arel_table
    condition = t[:due_date].lt(Arel::Nodes.build_quoted(Date.current))
      .and(t[:status].not_eq(Arel::Nodes.build_quoted("done")))
    # Wrap in CASE for boolean column
    Arel::Nodes::Case.new.when(condition).then(true).else(false).to_sql
  end
end
```

```yaml
virtual_columns:
  is_overdue:
    service: is_overdue
    type: boolean
```

The `service` approach is the recommended path for:
- DB-portable SQL (Arel abstracts PostgreSQL vs SQLite differences)
- Complex logic that benefits from Ruby (conditionals, external lookups)
- Columns where the SQL expression depends on runtime context (e.g., current user's timezone)

### Type Coercion

The `type:` key determines how the raw database value is cast on the Ruby side. ActiveRecord returns raw DB types for SELECT aliases — e.g., SQLite returns `0`/`1` for booleans, PostgreSQL returns `true`/`false`. The builder registers an `attribute` declaration on the model class for each virtual column, using ActiveRecord's type system:

```ruby
# Generated at boot for each virtual column
model_class.attribute :is_overdue, :boolean
model_class.attribute :total_line_value, :decimal
model_class.attribute :category_rank, :integer
```

This ensures consistent Ruby types regardless of the database adapter. The mapping from `type:` values to AR types:

| Virtual column `type` | AR attribute type | Ruby class |
|----------------------|-------------------|------------|
| `string` | `:string` | `String` |
| `integer` | `:integer` | `Integer` |
| `float` | `:float` | `Float` |
| `decimal` | `:decimal` | `BigDecimal` |
| `boolean` | `:boolean` | `TrueClass`/`FalseClass` |
| `date` | `:date` | `Date` |
| `datetime` | `:datetime` | `Time` |
| `json` | `:json` | `Hash`/`Array` |

For declarative virtual columns (`function` + `association`), the type is inferred: `count` → `integer`, `sum`/`avg` → inherits from `source_field` type, `min`/`max` → inherits from `source_field` type. This matches the current aggregate behavior.

### GROUP BY Handling

When any virtual column in the current query has `group: true`, the builder adds `GROUP BY <parent_table>.id` to the scope. This interacts with:

- **Pagination** — Kaminari's `count` query must handle GROUP BY. The standard approach is wrapping in a subquery for the count: `SELECT COUNT(*) FROM (SELECT ... GROUP BY ...) AS subquery`.
- **Other SELECT columns** — `SELECT parent_table.*` is compatible with `GROUP BY primary_key` on PostgreSQL (PG knows all columns are functionally dependent on the PK). SQLite is permissive by default.
- **Cartesian products** — multiple `join` + `group` columns can inflate row counts. See [Cartesian Product Prevention](#cartesian-product-prevention).

### Presenter Usage

Virtual columns are referenced exactly like aggregates are today — as regular fields:

```yaml
index:
  table_columns:
    - { field: title }
    - { field: is_overdue, renderer: boolean_icon, sortable: true }
    - { field: has_approved_approval, renderer: boolean_icon }
    - { field: total_line_value, renderer: currency, sortable: true }
    - { field: category_rank }
  item_classes:
    - class: "lcp-row-danger"
      when: { field: is_overdue, operator: eq, value: "true" }
    - class: "lcp-row-success"
      when: { field: has_approved_approval, operator: eq, value: "true" }
```

Virtual columns used in `item_classes.when` conditions are already part of the SELECT — no N+1 problem, no eager loading needed. The condition evaluator reads the value via `record.send(:is_overdue)` which returns the SQL-computed value.

### Show Page Query

On the index page, virtual columns are added to the collection scope's SELECT clause. On the **show page**, the controller must also build a query with virtual columns — a plain `Model.find(id)` would not include SELECT aliases, so `record.is_overdue` would return `nil`.

The controller builds the show query as:

```ruby
# Collect virtual columns needed for this presenter's show layout
scope = model_class.where(id: params[:id])
scope = VirtualColumnBuilder.apply(scope, requested_virtual_columns)
@record = scope.first!
```

This ensures virtual columns referenced in the show layout, `record_rules`, action conditions, or `item_classes` are available as attributes on the loaded record.

For `service:` virtual columns on show pages, the per-record `call(record)` method is used instead of the SQL expression — no need to add them to the SELECT. The controller defines a reader method on the record's singleton class so the field name resolves transparently:

```ruby
record.define_singleton_method(:health_score) { ServiceClass.call(self) }
```

### Interaction with Eager Loading

Virtual columns with `join:` add SQL JOINs to the scope. These must be deduplicated to avoid duplicate JOIN clauses. The builder deduplicates virtual column JOINs among themselves by exact string match (after `%{table}` expansion). For the first version, deduplication with `eager_load` JOINs is not handled — if a conflict arises, the configurator should use a correlated subquery instead of `join:` for that virtual column. A more sophisticated approach (inspecting `scope.arel.join_sources`) can be added later if needed.

For `expression:` columns without `join:` (correlated subqueries, inline expressions, window functions), there is no interaction with eager loading.

### Interaction with Soft Delete

When a virtual column's `expression:` contains correlated subqueries or JOINs referencing a soft-deletable model, the configurator is responsible for filtering out discarded records in the SQL (e.g., `AND discarded_at IS NULL`). The platform does not automatically inject soft-delete conditions into raw SQL expressions — the `expression:` string is used as-is. For declarative virtual columns (`function` + `association`), the existing soft-delete filtering continues to apply automatically.

### Virtual Columns in Forms

Virtual columns are **always read-only** — they are computed values, not stored fields. If a virtual column appears in a form layout section, it is rendered as a read-only display field (same as a field with `readonly: true`). The controller never includes virtual column names in `permitted_params`. No special validator rule is needed — the form simply renders them as non-editable.

### Interaction with Conditions (Advanced Conditions spec)

Virtual columns provide an efficient alternative to in-memory condition evaluation for index pages:

| Without virtual columns | With virtual columns |
|---|---|
| Preload `approvals` for all 50 rows → in-memory check | `EXISTS(...)` in SELECT → read boolean attribute |
| N+1 if configurator forgets `includes` | No association access at all |
| Can't sort by condition result | Sortable — it's a real SQL column |

The configurator can define a virtual column and reference it in `item_classes.when` as a simple `{ field: has_approved_approval, operator: eq, value: "true" }`. The condition evaluator treats it as a regular field — no special handling needed.

This does **not** replace the advanced conditions system (compound conditions, dynamic value references, etc.). It provides a performance-optimized path for specific index-page use cases where the condition result can be pre-computed in SQL.

### Interaction with Ransack

Virtual columns are **not** added to `ransackable_attributes`. They are SQL aliases, not real database columns — Ransack cannot use them in WHERE clauses (standard SQL does not allow WHERE on SELECT aliases without a wrapping subquery). Sorting by virtual columns works (ORDER BY can reference SELECT aliases), but filtering must go through the platform's own filter mechanisms or custom scopes.

### Security: SQL Injection

The `expression:` and `join:` values are defined in YAML/DSL by the platform configurator (who has access to the codebase). They are **not** user input. The same trust model applies as for the existing `aggregates.sql:` key.

The `%{table}` placeholder is resolved to a properly quoted table name. No user-supplied values are interpolated into these strings (the `:current_user` placeholder in `where:` uses `conn.quote`).

## Usage Examples

### EXISTS check for row styling

```yaml
# models/order.yml
virtual_columns:
  has_approved_approval:
    expression: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"
    type: boolean

# presenters/orders.yml
index:
  table_columns:
    - { field: title }
    - { field: has_approved_approval, renderer: boolean_icon }
  item_classes:
    - class: "lcp-row-success"
      when: { field: has_approved_approval, operator: eq, value: "true" }
```

### Derived boolean for overdue detection

```yaml
# models/task.yml
virtual_columns:
  is_overdue:
    expression: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
    type: boolean
    auto_include: true

# presenters/tasks.yml
index:
  table_columns:
    - { field: title }
    - { field: is_overdue, renderer: boolean_icon, sortable: true }
  item_classes:
    - class: "lcp-row-danger"
      when: { field: is_overdue, operator: eq, value: "true" }
```

### JOIN-based display column

```yaml
# models/deal.yml
virtual_columns:
  company_display:
    expression: "companies.name || ' (' || companies.country || ')'"
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"
    type: string

# presenters/deals.yml
index:
  table_columns:
    - { field: title }
    - { field: company_display, sortable: true }
```

### LATERAL JOIN — multiple fields from latest child (PostgreSQL)

```yaml
# models/order.yml
virtual_columns:
  latest_comment_body:
    expression: "lc.body"
    join: &latest_comment_join >-
      LEFT JOIN LATERAL (
        SELECT c.body, c.author_name FROM comments c
        WHERE c.order_id = %{table}.id
        ORDER BY c.created_at DESC LIMIT 1
      ) AS lc ON true
    type: string

  latest_comment_author:
    expression: "lc.author_name"
    join: *latest_comment_join
    type: string
```

### Top-N via JSON aggregation

```yaml
# models/order.yml
virtual_columns:
  latest_3_comments:
    expression: >-
      (SELECT json_agg(sub ORDER BY sub.created_at DESC)
       FROM (SELECT c.body, c.author_name, c.created_at
             FROM comments c
             WHERE c.order_id = %{table}.id
             ORDER BY c.created_at DESC LIMIT 3) sub)
    type: json

# presenters/orders.yml — use a custom renderer for the JSON array
index:
  table_columns:
    - { field: title }
    - { field: latest_3_comments, renderer: comment_list }
```

### Window function — rank and running total

```yaml
# models/deal.yml
virtual_columns:
  stage_rank:
    expression: "ROW_NUMBER() OVER(PARTITION BY %{table}.stage ORDER BY %{table}.value DESC)"
    type: integer

  cumulative_value:
    expression: "SUM(%{table}.value) OVER(ORDER BY %{table}.created_at ROWS UNBOUNDED PRECEDING)"
    type: decimal
```

### Service with Arel for DB portability

```yaml
# models/task.yml
virtual_columns:
  is_overdue:
    service: is_overdue
    type: boolean
```

```ruby
# app/lcp_services/virtual_columns/is_overdue.rb
class IsOverdue
  def self.call(record, options: {})
    record.due_date.present? && record.due_date < Date.current && record.status != "done"
  end

  def self.sql_expression(model_class, options: {})
    t = model_class.arel_table
    condition = t[:due_date].lt(Arel::Nodes.build_quoted(Date.current))
      .and(t[:status].not_eq(Arel::Nodes.build_quoted("done")))
    Arel::Nodes::Case.new.when(condition).then(true).else(false).to_sql
  end
end
```

### Complex correlated subquery with internal JOIN

```yaml
# models/order.yml
virtual_columns:
  weighted_approval_score:
    expression: >-
      (SELECT COALESCE(SUM(a.weight * al.priority), 0)
       FROM approvals a
       JOIN approval_levels al ON al.id = a.level_id
       WHERE a.order_id = %{table}.id)
    type: float
```

No `join:` needed — the JOIN is inside the correlated subquery, not in the outer scope.

## General Implementation Approach

### Configuration key design

The minimal configuration surface is:

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `expression` | string | Yes (unless declarative/service) | SQL expression projected into SELECT (aliased as the column name). `%{table}` placeholder for parent table. |
| `join` | string | No | SQL JOIN clause added to outer scope. `%{table}` placeholder supported. |
| `group` | boolean | No (default: false) | Whether `GROUP BY parent_table.id` is needed. |
| `type` | string | Yes (unless declarative) | Result type: string, integer, float, decimal, boolean, date, datetime. |
| `default` | any | No | COALESCE default value. |
| `auto_include` | boolean | No (default: false) | Include in every query, regardless of presenter references. |
| `function` | string | Declarative only | Aggregate function (count, sum, min, max, avg). |
| `association` | string | Declarative only | Target has_many association. |
| `source_field` | string | Declarative only | Field on target model. |
| `where` | hash | Declarative only | Equality conditions on target model. |
| `service` | string | Service only | Service class key. |

All "subtypes" from the original design (`exists`, `expression+join`, `function+join`, window functions) are covered by `expression` + `join` + `group`. No special detection logic — the builder reads the keys that are present.

### Naming: `virtual_columns` with `aggregates` alias

Rename the concept from `aggregates` to `virtual_columns`. Keep `aggregates` as an alias during YAML loading — both keys map to the same internal representation. The platform is pre-production, so no migration cost.

- `AggregateDefinition` is renamed to `VirtualColumnDefinition` (or aliased).
- `ModelDefinition` accepts both `aggregates:` and `virtual_columns:` in YAML, merges into one hash.
- `aggregate` DSL method stays as alias for `virtual_column`.

### Query builder

Extend `QueryBuilder` with:
- `build_expression` — expands `%{table}`, wraps with COALESCE if `default` is set. Covers all `expression:` columns (EXISTS, inline expressions, window functions, correlated subqueries).
- JOIN collection — collects `join:` strings from all requested virtual columns, deduplicates by exact string match after `%{table}` expansion, applies once via `scope.joins(Arel.sql(...))`.
- GROUP BY — if any requested column has `group: true`, adds `.group("#{parent_table}.id")`.
- Existing `build_declarative_subquery` and `build_service_subquery` remain unchanged.

### Cartesian product prevention

When `join` + `group` are both present and multiple such columns exist, cartesian products can inflate row counts:

```sql
-- WRONG: 3 line_items x 2 payments = 6 rows per order
SELECT SUM(li.quantity * li.unit_price), SUM(p.amount)
FROM orders
LEFT JOIN line_items li ON ...
LEFT JOIN payments p ON ...
GROUP BY orders.id
```

**Recommendation for configurators:** When aggregating over a joined table, prefer a correlated subquery in `expression:` instead of `join:` + `group:`:

```yaml
# GOOD: independent correlated subqueries, no cartesian product
total_line_value:
  expression: "(SELECT COALESCE(SUM(li.quantity * li.unit_price), 0) FROM line_items li WHERE li.order_id = %{table}.id)"
  type: decimal

total_payments:
  expression: "(SELECT COALESCE(SUM(p.amount), 0) FROM payments p WHERE p.order_id = %{table}.id)"
  type: decimal

# AVOID: two joins with group = cartesian risk
# total_line_value:
#   expression: "SUM(li.quantity * li.unit_price)"
#   join: "LEFT JOIN line_items li ON ..."
#   group: true
```

Reserve `join:` + `group: true` for cases where a single JOIN + GROUP is genuinely needed (e.g., one aggregation over one table). When multiple aggregations are needed, correlated subqueries are safer.

The `ConfigurationValidator` should emit a **warning** (not error) when multiple virtual columns on the same model combine `join:` + `group: true`, alerting the configurator to the cartesian product risk.

### Default inclusion and presenter control

The controller collects virtual column names to include from three sources (in priority order):

1. **Always included** — virtual columns with `auto_include: true` on the model definition.
2. **Auto-detected** — names referenced in presenter's `table_columns`, `tile_fields`, `item_classes[].when` conditions, show `layout` fields, permission `scope`, `record_rules[].when` conditions, and Ransack sort params at runtime.
3. **Explicitly declared** — names listed in presenter's `index.virtual_columns` or `show.virtual_columns`, action-level `virtual_columns`, or scope-level `virtual_columns`.

This extends the detection logic used for aggregates today with the `auto_include` flag, permission-aware detection, and explicit declarations at multiple levels (presenter, action, scope).

### ConfigurationValidator

The validator is extended to:
- Accept both `aggregates` and `virtual_columns` keys.
- Validate `expression` and `join` are strings when present.
- Validate `type` is required for `expression` and `service` subtypes.
- Validate `group` is boolean when present.
- Validate virtual column names don't collide with field names, association names, or scope names on the same model.
- Validate virtual column names don't collide with reserved ActiveRecord method names (`save`, `valid?`, `destroy`, `type`, `id`, `new_record?`, etc.) — maintain a small denylist of critical AR methods.
- **Warning** when multiple `join` + `group` columns exist on the same model.

## Decisions

1. **Minimal key set: `expression`, `join`, `group`.** No `exists` or `window` subtypes. All non-declarative, non-service virtual columns are expressed as a SQL expression (projected into SELECT). This keeps the configuration surface small and avoids subtype detection logic. The configurator writes the SQL expression they need.

2. **Approach C: unified `virtual_columns` with `aggregates` alias.** One concept, one key, one builder. The platform is pre-production, so renaming is costless.

3. **Aggregate + join columns use correlated subqueries by convention.** The platform does not prevent `join` + `group`, but the validator warns about cartesian product risk when multiple such columns exist. Documentation recommends correlated subqueries for multiple aggregations.

4. **Virtual columns are defined on the model, with `auto_include` flag.** By default, virtual columns are only included in the query when a presenter references them (via `table_columns`, `item_classes`, etc.) or explicitly lists them in `index.virtual_columns`. Setting `auto_include: true` includes the column in every query for that model. This gives the configurator control: define once on the model, activate per presenter.

5. **Virtual columns are not added to Ransack's `ransackable_attributes`.** SQL aliases cannot be used in WHERE clauses without a wrapping subquery. Sorting works (ORDER BY accepts aliases). Filtering must use the platform's own mechanisms or custom scopes.

6. **`%{table}` is the only placeholder in `expression`/`join` strings.** User values use the `where:` hash with `conn.quote`. No string interpolation of user input.

7. **Service lookup path.** Services are looked up in `app/lcp_services/virtual_columns/` (new) or `app/lcp_services/aggregates/` (backward compatible). The registry checks both paths.

8. **DB portability is the configurator's responsibility for `expression:` strings.** For DB-portable logic, use service virtual columns with Arel. The platform does not abstract raw SQL differences between PostgreSQL and SQLite.

9. **No `where:` on `expression:` columns.** The `where:` clause is only for declarative virtual columns (`function` + `association`). Expression columns embed their own WHERE conditions directly in the SQL string. Mixing raw SQL with structured conditions would make the builder unnecessarily complex.

10. **No SQL parsing in `ConfigurationValidator`.** The validator does not parse `expression:` or `join:` strings to detect table references or syntax errors. Parsing SQL is fragile and DB-specific. Errors surface at query time. The configurator is trusted.

11. **`join:` is a single string, not an array.** A virtual column that needs multiple JOINs concatenates them in one string (`"LEFT JOIN companies ON ... LEFT JOIN industries ON ..."`). An array form would add parsing complexity for minimal benefit.

12. **Type coercion via `model_class.attribute`.** Virtual columns register an AR `attribute` declaration at boot, ensuring consistent Ruby types regardless of database adapter (e.g., boolean is `true`/`false` on both PostgreSQL and SQLite).

13. **Show page loads virtual columns via scoped query.** The controller builds `Model.where(id:).select(...)` instead of `Model.find(id)` to include virtual column expressions. Service virtual columns use `call(record)` on the show page instead.

14. **Virtual columns are always read-only in forms.** If referenced in a form layout, they render as read-only display fields. No validator error — just silent read-only rendering.

15. **Soft delete filtering is the configurator's responsibility in `expression:` strings.** The platform does not inject `AND discarded_at IS NULL` into raw SQL. Declarative virtual columns (`function` + `association`) continue to apply soft-delete filtering automatically.

16. **JOIN deduplication is string-based for v1.** Virtual column JOINs are deduplicated among themselves by exact string match. Deduplication with `eager_load` JOINs is not handled in v1 — configurators should use correlated subqueries if a conflict arises.

17. **Name collision validation.** Virtual column names are checked against field names, association names, scope names, and a denylist of critical ActiveRecord methods.

## Open Questions

(none — all questions resolved)
