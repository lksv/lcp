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
| `sql` | Any SQL expression projected into SELECT | Yes (unless `function`+`association` or `service`) |
| `join` | SQL JOIN clause added to the outer scope | No |
| `group` | Whether GROUP BY parent_table.id is needed | No (default: false) |

The existing `function` + `association` + `where` declarative syntax is sugar that generates a correlated subquery internally. The `service` key delegates to a Ruby class. Everything else uses `sql` (optionally with `join` and `group`).

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

  # EXISTS check — raw sql, no special subtype needed
  has_approved_approval:
    sql: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"
    type: boolean

  # Derived boolean — inline expression on own table
  is_overdue:
    sql: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
    type: boolean

  # JOIN-based display column
  company_display:
    sql: "companies.name || ' (' || companies.country || ')'"
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"
    type: string

  # JOIN-based aggregate (needs GROUP BY)
  total_line_value:
    sql: "COALESCE(SUM(line_items.quantity * line_items.unit_price), 0)"
    join: "LEFT JOIN line_items ON line_items.order_id = %{table}.id"
    group: true
    type: decimal

  # Window function
  category_rank:
    sql: "ROW_NUMBER() OVER(PARTITION BY %{table}.category_id ORDER BY %{table}.created_at DESC)"
    type: integer

  # LATERAL JOIN (PostgreSQL) — top-N per group
  latest_comment_body:
    sql: "latest_comment.body"
    join: "LEFT JOIN LATERAL (SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1) AS latest_comment ON true"
    type: string

  # Service-based — unchanged from current aggregates syntax
  health_score:
    service: project_health
    type: integer

  # Complex correlated subquery with internal JOIN
  weighted_approval_score:
    sql: "(SELECT SUM(a.weight * al.priority) FROM approvals a JOIN approval_levels al ON al.id = a.level_id WHERE a.order_id = %{table}.id)"
    type: float
```

### DSL syntax

```ruby
define_model :order do
  # Declarative aggregate — old syntax still works
  aggregate :issues_count, function: :count, association: :issues

  # New unified syntax
  virtual_column :has_approved_approval, type: :boolean,
    sql: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"

  virtual_column :is_overdue, type: :boolean,
    sql: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"

  virtual_column :company_display, type: :string,
    sql: "companies.name || ' (' || companies.country || ')'",
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"

  virtual_column :category_rank, type: :integer,
    sql: "ROW_NUMBER() OVER(PARTITION BY %{table}.category_id ORDER BY %{table}.created_at DESC)"
end
```

### Default inclusion

Virtual columns are defined on the model but **not included in queries by default**. Each definition has an `auto_include` attribute (default: `false`). The presenter controls which virtual columns are added to the query scope.

```yaml
virtual_columns:
  # Always included when any presenter queries this model
  is_overdue:
    sql: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
    type: boolean
    auto_include: true

  # Only included when a presenter explicitly references it
  weighted_approval_score:
    sql: "(SELECT SUM(...) FROM ...)"
    type: float
    # auto_include: false (default)
```

The presenter adds virtual columns to the scope in two ways:

1. **Implicit** — referencing the virtual column name in `table_columns`, `tile_fields`, `item_classes.when`, or `layout` fields. The controller detects these references (same as it detects aggregate names today) and includes them in the query.
2. **Explicit** — listing additional virtual columns via `virtual_columns` key on the presenter's index/show config:

```yaml
# presenters/orders.yml
index:
  virtual_columns: [weighted_approval_score]  # add to query even if not in table_columns
  table_columns:
    - { field: title }
    - { field: is_overdue }   # auto-detected from table_columns
```

Virtual columns with `auto_include: true` are always added to the scope regardless of presenter configuration. Use this sparingly — only for columns needed across all presenters (e.g., a universal status flag used in permission scopes).

### Window Functions

Window functions work naturally with the `sql` key — no special subtype needed:

```yaml
virtual_columns:
  # Rank within category
  category_rank:
    sql: "ROW_NUMBER() OVER(PARTITION BY %{table}.category_id ORDER BY %{table}.created_at DESC)"
    type: integer

  # Running total
  cumulative_revenue:
    sql: "SUM(%{table}.amount) OVER(ORDER BY %{table}.created_at ROWS UNBOUNDED PRECEDING)"
    type: decimal

  # Percentile rank
  value_percentile:
    sql: "PERCENT_RANK() OVER(ORDER BY %{table}.value)"
    type: float
```

Window functions don't need `join` or `group` — they operate on the result set. They interact with pagination: the window is computed over the **paginated** result set (after WHERE, before LIMIT), which is usually what the user wants (rank within the visible page). For rank within the entire dataset, the configurator must use a correlated subquery instead.

### LATERAL JOIN (PostgreSQL)

PostgreSQL's `LATERAL` keyword enables powerful per-row subqueries that can reference columns from the outer query. This solves use cases that correlated subqueries handle awkwardly — especially fetching fields from the latest child record:

```yaml
virtual_columns:
  # Latest comment body for each order
  latest_comment_body:
    sql: "lc.body"
    join: "LEFT JOIN LATERAL (SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1) AS lc ON true"
    type: string

  # Most recent approval with multiple fields
  last_approver_name:
    sql: "la.approver_name"
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
    sql: "lc.body"
    join: &latest_comment_join >-
      LEFT JOIN LATERAL (
        SELECT c.body, c.title, c.author_name FROM comments c
        WHERE c.order_id = %{table}.id
        ORDER BY c.created_at DESC LIMIT 1
      ) AS lc ON true
    type: string

  latest_comment_title:
    sql: "lc.title"
    join: *latest_comment_join
    type: string

  latest_comment_author:
    sql: "lc.author_name"
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
    sql: >-
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
    sql: "ARRAY(SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 2)"
    type: string
```

Result: `{"First comment","Second comment"}` — simpler, but limited to one field.

**Separate columns with OFFSET (small N only):**

```yaml
virtual_columns:
  latest_comment_1:
    sql: "(SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1 OFFSET 0)"
    type: string

  latest_comment_2:
    sql: "(SELECT c.body FROM comments c WHERE c.order_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1 OFFSET 1)"
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

### Interaction with Eager Loading

Virtual columns with `join:` add SQL JOINs to the scope. These must be deduplicated with JOINs from `includes` / `eager_load`. The builder should check existing joins on the scope to avoid duplicate JOIN clauses.

For `sql:` columns without `join:` (correlated subqueries, inline expressions, window functions), there is no interaction with eager loading.

### Interaction with Conditions (Advanced Conditions spec)

Virtual columns provide an efficient alternative to in-memory condition evaluation for index pages:

| Without virtual columns | With virtual columns |
|---|---|
| Preload `approvals` for all 50 rows -> in-memory check | `EXISTS(...)` in SELECT -> read boolean attribute |
| N+1 if configurator forgets `includes` | No association access at all |
| Can't sort by condition result | Sortable — it's a real SQL column |

The configurator can define a virtual column and reference it in `item_classes.when` as a simple `{ field: has_approved_approval, operator: eq, value: "true" }`. The condition evaluator treats it as a regular field — no special handling needed.

This does **not** replace the advanced conditions system (compound conditions, dynamic value references, etc.). It provides a performance-optimized path for specific index-page use cases where the condition result can be pre-computed in SQL.

### Interaction with Ransack

Virtual columns are **not** added to `ransackable_attributes`. They are SQL aliases, not real database columns — Ransack cannot use them in WHERE clauses (standard SQL does not allow WHERE on SELECT aliases without a wrapping subquery). Sorting by virtual columns works (ORDER BY can reference SELECT aliases), but filtering must go through the platform's own filter mechanisms or custom scopes.

### Security: SQL Injection

The `sql:` and `join:` values are defined in YAML/DSL by the platform configurator (who has access to the codebase). They are **not** user input. The same trust model applies as for the existing `aggregates.sql:` key.

The `%{table}` placeholder is resolved to a properly quoted table name. No user-supplied values are interpolated into these strings (the `:current_user` placeholder in `where:` uses `conn.quote`).

## Usage Examples

### EXISTS check for row styling

```yaml
# models/order.yml
virtual_columns:
  has_approved_approval:
    sql: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"
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
    sql: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
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
    sql: "companies.name || ' (' || companies.country || ')'"
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
    sql: "lc.body"
    join: &latest_comment_join >-
      LEFT JOIN LATERAL (
        SELECT c.body, c.author_name FROM comments c
        WHERE c.order_id = %{table}.id
        ORDER BY c.created_at DESC LIMIT 1
      ) AS lc ON true
    type: string

  latest_comment_author:
    sql: "lc.author_name"
    join: *latest_comment_join
    type: string
```

### Top-N via JSON aggregation

```yaml
# models/order.yml
virtual_columns:
  latest_3_comments:
    sql: >-
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
    sql: "ROW_NUMBER() OVER(PARTITION BY %{table}.stage ORDER BY %{table}.value DESC)"
    type: integer

  cumulative_value:
    sql: "SUM(%{table}.value) OVER(ORDER BY %{table}.created_at ROWS UNBOUNDED PRECEDING)"
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
    sql: >-
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
| `sql` | string | Yes (unless declarative/service) | SQL expression for SELECT. `%{table}` placeholder for parent table. |
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

All "subtypes" from the original design (`exists`, `expression`, `expression+join`, `function+join`, window functions) are covered by `sql` + `join` + `group`. No special detection logic — the builder reads the keys that are present.

### Naming: `virtual_columns` with `aggregates` alias

Rename the concept from `aggregates` to `virtual_columns`. Keep `aggregates` as an alias during YAML loading — both keys map to the same internal representation. The platform is pre-production, so no migration cost.

- `AggregateDefinition` is renamed to `VirtualColumnDefinition` (or aliased).
- `ModelDefinition` accepts both `aggregates:` and `virtual_columns:` in YAML, merges into one hash.
- `aggregate` DSL method stays as alias for `virtual_column`.

### Query builder

Extend `QueryBuilder` with:
- `build_raw_sql` — expands `%{table}`, wraps with COALESCE if `default` is set. Covers all `sql:` columns (EXISTS, expressions, window functions, correlated subqueries).
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

**Recommendation for configurators:** When aggregating over a joined table, prefer a correlated subquery in `sql:` instead of `join:` + `group:`:

```yaml
# GOOD: independent correlated subqueries, no cartesian product
total_line_value:
  sql: "(SELECT COALESCE(SUM(li.quantity * li.unit_price), 0) FROM line_items li WHERE li.order_id = %{table}.id)"
  type: decimal

total_payments:
  sql: "(SELECT COALESCE(SUM(p.amount), 0) FROM payments p WHERE p.order_id = %{table}.id)"
  type: decimal

# AVOID: two joins with group = cartesian risk
# total_line_value:
#   sql: "SUM(li.quantity * li.unit_price)"
#   join: "LEFT JOIN line_items li ON ..."
#   group: true
```

Reserve `join:` + `group: true` for cases where a single JOIN + GROUP is genuinely needed (e.g., one aggregation over one table). When multiple aggregations are needed, correlated subqueries are safer.

The `ConfigurationValidator` should emit a **warning** (not error) when multiple virtual columns on the same model combine `join:` + `group: true`, alerting the configurator to the cartesian product risk.

### Default inclusion and presenter control

The controller collects virtual column names to include from:
1. Virtual columns with `auto_include: true` — always included.
2. Names referenced in presenter's `table_columns`, `tile_fields`, `item_classes[].when` conditions, show `layout` fields.
3. Names explicitly listed in presenter's `index.virtual_columns` or `show.virtual_columns`.

This is the same detection logic used for aggregates today, extended with the `auto_include` flag and explicit presenter list.

### ConfigurationValidator

The validator is extended to:
- Accept both `aggregates` and `virtual_columns` keys.
- Validate `sql` and `join` are strings when present.
- Validate `type` is required for `sql` and `service` subtypes.
- Validate `group` is boolean when present.
- Validate virtual column names don't collide with field names.
- **Warning** when multiple `join` + `group` columns exist on the same model.

## Decisions

1. **Minimal key set: `sql`, `join`, `group`.** No `exists`, `expression`, or `window` subtypes. All non-declarative, non-service virtual columns are expressed as raw SQL. This keeps the configuration surface small and avoids subtype detection logic. The configurator writes the SQL they need.

2. **Approach C: unified `virtual_columns` with `aggregates` alias.** One concept, one key, one builder. The platform is pre-production, so renaming is costless.

3. **Aggregate + join columns use correlated subqueries by convention.** The platform does not prevent `join` + `group`, but the validator warns about cartesian product risk when multiple such columns exist. Documentation recommends correlated subqueries for multiple aggregations.

4. **Virtual columns are defined on the model, with `auto_include` flag.** By default, virtual columns are only included in the query when a presenter references them (via `table_columns`, `item_classes`, etc.) or explicitly lists them in `index.virtual_columns`. Setting `auto_include: true` includes the column in every query for that model. This gives the configurator control: define once on the model, activate per presenter.

5. **Virtual columns are not added to Ransack's `ransackable_attributes`.** SQL aliases cannot be used in WHERE clauses without a wrapping subquery. Sorting works (ORDER BY accepts aliases). Filtering must use the platform's own mechanisms or custom scopes.

6. **`%{table}` is the only placeholder in SQL strings.** User values use the `where:` hash with `conn.quote`. No string interpolation of user input.

7. **Service lookup path.** Services are looked up in `app/lcp_services/virtual_columns/` (new) or `app/lcp_services/aggregates/` (backward compatible). The registry checks both paths.

8. **DB portability is the configurator's responsibility for `sql:` strings.** For DB-portable logic, use service virtual columns with Arel. The platform does not abstract raw SQL differences between PostgreSQL and SQLite.

## Open Questions

1. **Should the `where:` clause from declarative aggregates be available on `sql:` columns?** Today `where:` is only for declarative aggregates (`function` + `association`). It could be useful for `sql:` columns too — e.g., `where: { status: active }` appended to the correlated subquery. But this mixes raw SQL with structured conditions, making the builder more complex. Current answer: no — `sql:` columns embed their own WHERE conditions in the SQL string.

2. **Should the `ConfigurationValidator` parse SQL strings to detect table references?** This could enable automatic validation that `join:` columns reference tables that actually exist. But parsing SQL is fragile and DB-specific. Current answer: no — trust the configurator. Errors surface at query time.

3. **Should `join:` support array of strings for multiple JOINs?** E.g., a virtual column that needs both `companies` and `industries` joined. Current answer: use a single string with multiple JOIN clauses (`"LEFT JOIN companies ON ... LEFT JOIN industries ON ..."`). An array would add parsing complexity for minimal benefit.
