# Feature Specification: Virtual Columns (Generalized Query Extensions)

**Status:** Implemented
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
  # EXISTS always returns TRUE/FALSE (never NULL), so no default: needed
  has_approved_approval:
    expression: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"
    type: boolean

  # Derived boolean — inline expression on own table
  is_overdue:
    expression: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
    type: boolean
    default: false

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

  virtual_column :is_overdue, type: :boolean, default: false,
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
    default: false
    auto_include: true

  # Only included when a presenter explicitly references it
  weighted_approval_score:
    expression: "(SELECT SUM(...) FROM ...)"
    type: float
    # auto_include: false (default)
```

The controller collects virtual columns to include from multiple sources:

**Auto-detected (implicit)** — the collector recursively walks YAML metadata trees (including compound conditions with `all`/`any`/`not` nesting) to extract virtual column name references from:

| Source | Example |
|--------|---------|
| Presenter `table_columns` | `{ field: is_overdue }` |
| Presenter `tile_fields` | `{ field: is_overdue }` |
| Presenter `item_classes[].when` | `{ field: is_overdue, operator: eq, value: "true" }` (recursive walk through compound conditions) |
| Action `visible_when` / `disable_when` | `{ field: health_score, operator: gt, value: "50" }` (all action types: single, collection, batch) |
| Presenter `layout` (show page fields) | field reference in section |
| Permission `record_rules[].when` | `{ field: is_overdue, operator: eq, value: "true" }` (recursive walk, all roles) |
| Sort params (runtime) | `?sort=is_overdue&direction=asc` |

Note: `record_rules` auto-detection scans all roles' record rules (not just the current user's role) to collect virtual column names. This is a boot-time-safe superset — including a virtual column in SELECT that turns out unused is harmless, while missing one would cause a `ConditionError` at runtime.

**DB-sourced permissions caveat:** When `permission_source: :model`, permissions can change at runtime via the DB permission editor. The boot-time scan only covers the YAML-defined permissions. If a DB-sourced `record_rule` is added that references a virtual column not detected at boot, the virtual column will be missing from SELECT and the `ConditionEvaluator` will raise `ConditionError`. **Mitigation:** When using DB-sourced permissions, any virtual columns referenced in `record_rules` must also be listed explicitly in the presenter's `virtual_columns` key. Alternatively, the `VirtualColumns::Collector` can re-scan on permission cache invalidation (via the existing `Permissions::ChangeHandler`), but this adds complexity — the explicit listing is simpler and recommended for v1.

**Not supported:** Permission `scope` (`type: where`, `type: field_match`) **cannot** reference virtual column names. SQL aliases are not real columns — `WHERE is_overdue = TRUE` would fail with "column does not exist." To filter by a virtual column expression in a permission scope, use `type: custom` with a named scope that embeds the SQL expression directly.

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

**Always included** — virtual columns with `auto_include: true` are added to every controller query for that model, regardless of presenter configuration. Use this sparingly — only for columns needed across all presenters (e.g., a universal status flag used in row styling). Note: `auto_include` only affects controller queries, not direct `Model.find`/`Model.where` calls from custom code. Combining `auto_include: true` with `group: true` is prohibited (see [GROUP BY Handling](#group-by-handling)).

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

**Show page limitation:** Window functions compute values relative to the result set. On a show page query (`WHERE id = 123`), the result set contains one row, so `ROW_NUMBER()` always returns 1, `PERCENT_RANK()` always returns 0, etc. The values are meaningless. The `VirtualColumns::Collector` includes window function columns on show pages if referenced in the layout (for consistency), but configurators should be aware that the values are only meaningful on index pages.

**Sorting by window functions:** Sorting by a window function column (e.g., `?sort=category_rank`) orders the entire result set by the pre-computed window function output. Window functions are computed after WHERE but before ORDER BY in SQL, so `ORDER BY category_rank` sorts by the rank computed over the full filtered dataset — this is correct and expected behavior. However, it may surprise configurators who expect the rank to change with the sort order.

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

**JSON aggregation (recommended, PostgreSQL-only):**

`json_agg()` is PostgreSQL-specific. SQLite does not support `json_agg` — for DB-portable JSON aggregation, use a service virtual column with Arel or `json_group_array()` on SQLite.

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

**Array aggregation (PostgreSQL-only, single field):**

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

The builder passes `current_user:` to `sql_expression` (same as it passes to declarative `where:` conditions). The service can ignore it if not needed (keyword argument with `nil` default). This enables user-dependent SQL expressions (e.g., `CASE WHEN %{table}.owner_id = <user.id> THEN ...`).

The `service` approach is the recommended path for:
- DB-portable SQL (Arel abstracts PostgreSQL vs SQLite differences)
- Complex logic that benefits from Ruby (conditionals, external lookups)
- Columns where the SQL expression depends on runtime context (e.g., current user's timezone, ownership checks)

### Type Coercion

The `type:` key determines how the raw database value is cast on the Ruby side. ActiveRecord returns raw DB types for SELECT aliases — e.g., SQLite returns `0`/`1` for booleans, PostgreSQL returns `true`/`false`. Without type coercion, a condition like `{ field: is_overdue, operator: eq, value: "true" }` would fail on SQLite (`"1" != "true"`).

The builder registers an `attribute` declaration on the model class for each virtual column at boot time, using ActiveRecord's type system:

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

#### Loaded-tracking guard

Boot-time `attribute` declarations have a side effect: `record.respond_to?(:is_overdue)` returns `true` even when the virtual column was NOT included in the query's SELECT. In that case `record.is_overdue` silently returns `nil` instead of raising `NoMethodError`. This differs from the current aggregate behavior (no `attribute` declaration → `respond_to?` returns `false` → `ConditionEvaluator` raises `ConditionError`).

Silent `nil` is dangerous: a condition `{ field: is_overdue, operator: eq, value: "true" }` evaluates to `false` instead of raising — the configurator sees no error, just "row styling doesn't work." To preserve the loud-failure safety net while keeping type coercion, the tracking uses a **builder-level thread-local stack** instead of record-level introspection.

**Why not `attributes.keys`?** After `model_class.attribute :is_overdue, :boolean` is declared at boot, `attributes.keys` **always** includes `"is_overdue"` — even for records loaded without the virtual column in SELECT. The `attribute` declaration registers the name with a `nil` default in ActiveRecord's `AttributeSet`, so the key is always present. An intersection of `attributes.keys` with virtual column names would match all of them every time, making the guard non-functional.

**Thread-local tracking approach:** `VirtualColumns::Builder.apply` knows exactly which virtual column names it adds to the SELECT. The challenge is timing: `apply` returns a **lazy** `ActiveRecord::Relation` — the SQL hasn't executed yet. Setting a thread-local in `apply` and clearing it "after" doesn't work because records are materialized later (when `.each`, `.to_a`, `.page()` is called). Between `apply` and actual SQL execution, other code in the same request might load the same model class (e.g., `Model.find(id)` in an event handler) and see a stale thread-local.

**Solution: `scope.extending` wraps actual query execution.** The builder attaches a relation extension module that sets/clears a thread-local **stack** around `exec_queries` — the ActiveRecord method that actually runs SQL and instantiates records:

```ruby
# At boot, VirtualColumnApplicator installs on the model class:
model_class.thread_mattr_accessor :_virtual_columns_stack  # Array of Sets, not a single Set
model_class.after_initialize :_track_loaded_virtual_columns

model_class.define_method(:_track_loaded_virtual_columns) do
  return unless persisted?  # New records can't have computed values
  stack = self.class._virtual_columns_stack
  @_loaded_virtual_columns = stack&.last&.dup || Set.new
end

# VirtualColumns::Builder.apply wraps the scope with an extending module:
vc_names = Set.new(applied_vc_names)
scope = scope.extending(Module.new do
  define_method(:exec_queries) do
    klass._virtual_columns_stack ||= []
    klass._virtual_columns_stack.push(vc_names)
    begin
      super()
    ensure
      klass._virtual_columns_stack.pop
    end
  end
end)
```

**Why a stack, not a single value?** During `exec_queries`, an `after_initialize` callback (or any code triggered during record instantiation) could query the same model class — e.g., a `before_save` callback, a condition service, or a custom action loading related records of the same type. A single thread-local would be overwritten by the inner query and lost for the outer one. A stack ensures each `exec_queries` invocation pushes its own set and pops it on completion, so nested queries on the same model class don't corrupt each other's tracking.

The stack's top element is only set during the exact window when `exec_queries` runs (when `after_initialize` callbacks fire). Before and after, the stack is empty. This prevents stale values from leaking to unrelated model loads in the same request.

**Guard location:** The loaded-tracking guard is checked in `FieldValueResolver` and `ConditionEvaluator`, **not** in the attribute getter. Putting the check in the getter would break `to_json`, `serializable_hash`, `inspect`, and other code that reads all attributes — any serialization of a record loaded without virtual columns would raise. Instead, only the code paths that evaluate conditions and resolve display values perform the check:

```ruby
# In FieldValueResolver.resolve_virtual_column and ConditionEvaluator.resolve_field_path:
value = record.send(field_name)
if value.nil? && record.persisted? && model_definition.virtual_column(field_name)
  loaded = record.instance_variable_get(:@_loaded_virtual_columns)
  unless loaded&.include?(field_name.to_s)
    raise ConditionError,
      "virtual column '#{field_name}' not loaded in query SELECT — " \
      "add it to presenter virtual_columns or check VirtualColumns::Collector detection"
  end
end
```

This requires `ConditionEvaluator` to receive the `model_definition` (via `context` parameter) so it can check whether a field is a virtual column. `FieldValueResolver` already has access to `model_definition`.

This means:
- **Virtual column in SELECT, SQL returns NULL** (e.g., LEFT JOIN with no match) → `nil`, no error. Correct.
- **Virtual column NOT in SELECT** (configuration bug) → `ConditionError`. Loud failure in all environments.
- **Record loaded outside `VirtualColumns::Builder`** (e.g., `Model.find(id)`) → `@_loaded_virtual_columns` is empty set → any virtual column access via ConditionEvaluator/FieldValueResolver raises. Correct — the code should use `VirtualColumns::Builder.apply` if it needs virtual columns. Direct `record.is_overdue` access returns `nil` (the AR attribute default) without raising — this is acceptable because only condition/display paths need strict checking.
- **New record** (`record.persisted?` is false) → callback is skipped, `@_loaded_virtual_columns` is `nil`, guard is skipped. Expected.
- **`after_initialize` overhead** is minimal: one `persisted?` check (skips new records entirely) and one `Set#dup` for persisted records. Rails uses `after_initialize` routinely (e.g., `has_secure_password`).
- **Thread safety** — `thread_mattr_accessor` ensures each thread/request has its own stack. The `exec_queries` wrapper with `push`/`pop` (in `ensure`) guarantees cleanup even if an exception occurs during query execution. No cross-request leaks. Nested `exec_queries` on the same model class (e.g., triggered by `after_initialize` callbacks) each push/pop their own set, so they don't corrupt each other.

**Public API:** `VirtualColumnApplicator` installs a `virtual_column_loaded?(name)` method on every model with virtual columns. This is the public interface for checking whether a specific VC was included in the query. `ConditionEvaluator` and `FieldValueResolver` both use this method instead of accessing the internal `@_loaded_virtual_columns` ivar directly. Custom code that accesses virtual columns outside the controller pipeline can also use this method to guard against unloaded VCs.

**`find_each` / `find_in_batches` compatibility:** These methods execute multiple SQL queries internally (one per batch). Each batch call goes through `exec_queries`, so the extending module correctly pushes/pops the stack per batch. Virtual columns work with `find_each` transparently.

**`reload` caveat:** Calling `record.reload` re-reads the record from the database using a plain SELECT (without virtual column expressions) but does **not** trigger `after_initialize`. The `@_loaded_virtual_columns` instance variable retains its old value, but the actual attribute values are reset to `nil` (the AR attribute defaults). The guard would incorrectly believe the columns are loaded. **Mitigation:** `VirtualColumnApplicator` overrides `reload` on virtual-column-enabled models to clear `@_loaded_virtual_columns`:

```ruby
model_class.define_method(:reload) do |*args|
  result = super(*args)
  @_loaded_virtual_columns = Set.new
  result
end
```

After `reload`, any virtual column access through ConditionEvaluator (raises `ConditionError`) or FieldValueResolver (raises `LcpRuby::Error`) will fail — the caller must re-load via `VirtualColumns::Builder.apply` if virtual columns are needed.

### GROUP BY Handling

When any virtual column in the current query has `group: true`, the builder adds `GROUP BY <parent_table>.id` to the scope. This interacts with:

- **Pagination** — Kaminari's `.count` on a grouped scope returns a `Hash { id => count }` instead of an `Integer`, which breaks pagination. The controller handles this by computing the total count on a clean scope: `total = scope.except(:select, :group, :joins).distinct.count(:id)`. Using `.except(:joins)` removes the virtual column JOINs that could inflate row counts via duplicate parent rows. Using `.distinct.count(:id)` ensures each parent record is counted exactly once even if other JOINs remain (e.g., from permission scopes or Ransack). The total is injected into Kaminari via `@records = scope.page(n).per(m); @records.define_singleton_method(:total_count) { total }`. This is localized to the controller (no global `.count` override on the model class) and safe because each grouped row corresponds to exactly one parent record.
- **Other SELECT columns** — `SELECT parent_table.*` is compatible with `GROUP BY primary_key` on PostgreSQL (PG knows all columns are functionally dependent on the PK). SQLite is permissive by default.
- **Cartesian products** — multiple `join` + `group` columns can inflate row counts. See [Cartesian Product Prevention](#cartesian-product-prevention).
- **Window functions** — if both a window function column and a `group: true` column are active in the same query, the window function operates on the post-GROUP BY result set (grouped rows, not original rows). This is valid SQL but may produce unexpected results. The `ConfigurationValidator` emits a warning when a model has both `group: true` and window function virtual columns.
- **`auto_include` constraint** — combining `auto_include: true` with `group: true` is **prohibited** by the validator. An always-included GROUP BY would break all non-controller queries on the model (`Model.count`, `Model.exists?`, `Model.pluck`, etc.). If a grouped virtual column is needed across all presenters, list it explicitly in each presenter's `virtual_columns` instead.

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
scope, service_only = VirtualColumns::Builder.apply(
  scope, model_definition, requested_virtual_column_names, current_user: current_user
)
# Returns: [modified_scope, Array<String> of service-only names]
@record = scope.first!
```

This ensures virtual columns referenced in the show layout, `record_rules`, action conditions, or `item_classes` are available as attributes on the loaded record.

For `service:` virtual columns on show pages, the per-record `call(record)` method is preferred over the SQL expression — no need to add them to the SELECT. The controller defines a reader method on the record's singleton class so the field name resolves transparently:

```ruby
record.define_singleton_method(:health_score) { ServiceClass.call(self) }
```

If the service only defines `sql_expression` without a `call` method, the show page falls back to the SQL query path (loading the record via scoped query with the expression in SELECT, same as non-service virtual columns). Services that define both methods get the benefit of `call` on show pages (avoids SQL overhead for a single record) and `sql_expression` on index pages (batch SQL). Services that only define one method work in both contexts — just with different performance characteristics.

### Interaction with Eager Loading

Virtual columns with `join:` add SQL JOINs to the scope. These must be deduplicated to avoid duplicate JOIN clauses. The builder deduplicates virtual column JOINs among themselves by normalized string match (after `%{table}` expansion, `.gsub(/\s+/, " ").strip.downcase` normalization to collapse all whitespace variants — tabs, newlines from YAML literal block scalars (`|`), folded block scalars (`>-`) — into single spaces, and to handle SQL keyword case differences). The original-case string is used in the generated SQL — downcasing is only for comparison. For the first version, deduplication with `eager_load` JOINs is not handled — if a conflict arises, the configurator should use a correlated subquery instead of `join:` for that virtual column. A more sophisticated approach (inspecting `scope.arel.join_sources`) can be added later if needed.

**`select()` + `eager_load` conflict:** The QueryBuilder calls `scope.select("table.*", *subqueries)`. An explicit `.select()` replaces ActiveRecord's auto-generated SELECT, which means `eager_load` associations' columns are no longer selected — association attributes will be `nil`. This already exists with aggregates. The mitigation is:
- Use `.preload()` instead of `.includes()` when virtual columns are present. Unlike `includes`, `.preload()` **always** uses separate queries (never falls back to LEFT JOIN), so it is unaffected by the custom `.select()`. The `IncludesResolver` should detect the presence of virtual columns and emit `.preload()` calls instead of `.includes()` for `:display`-reason dependencies. Note: `includes` can silently fall back to `eager_load` when there's a `.where` or `.order` clause referencing an association table — using `.preload()` explicitly prevents this.
- When `eager_load` is unavoidable (e.g., sorting by an associated field requires a JOIN), the `IncludesResolver` merges the eager_loaded table's columns into the existing SELECT (see Pipeline ordering below).

**Pipeline ordering:** In the controller, `VirtualColumns::Builder.apply` runs **before** `IncludesResolver.resolve` (the same order as today's `apply_aggregates` → `strategy.apply`). This means the builder doesn't know at call time which associations will be eager_loaded. The `eager_load` SELECT merge is therefore handled by the `IncludesResolver` itself: when `StrategyResolver` detects that the scope already has a custom `.select()` (from virtual columns) **and** it needs to emit `.eager_load()`, it appends the eager_loaded table's columns to the existing SELECT via `scope.select("assoc_table.*")` before applying `.eager_load()`. This keeps the responsibility in one place — the resolver knows which associations it's loading and which tables need their columns in SELECT.

For `expression:` columns without `join:` (correlated subqueries, inline expressions, window functions), there is no interaction with eager loading.

### Interaction with `distinct`

If a permission scope, search, or other mechanism adds `.distinct` to the scope, and a virtual column uses `join:` without `group:`, the JOIN is assumed to produce **at most one row per parent** (e.g., a LEFT JOIN on a belongs_to FK). If a `join:` produces multiple rows per parent (e.g., a LEFT JOIN on a has_many FK without aggregation), `.distinct` alone may not collapse them correctly — DISTINCT deduplicates by ALL selected columns including the virtual column alias, so rows with different joined values would remain. For such cases, use `group: true` or a correlated subquery instead of `join:`.

**Window functions + `distinct`:** If `.distinct` is applied to a scope that has a window function in SELECT (e.g., `ROW_NUMBER() OVER(...)`), each row gets a unique window function value, so DISTINCT cannot remove any duplicates — it becomes a no-op. This is valid SQL but semantically useless. Configurators should be aware that `.distinct` does not interact meaningfully with window function columns. If deduplication is needed on a scope with window functions, apply DISTINCT to a wrapping subquery (not the window function scope) or use `group: true` instead.

### Interaction with Soft Delete

When a virtual column's `expression:` contains correlated subqueries or JOINs referencing a soft-deletable model, the configurator is responsible for filtering out discarded records in the SQL (e.g., `AND discarded_at IS NULL`). The platform does not automatically inject soft-delete conditions into raw SQL expressions — the `expression:` string is used as-is. For declarative virtual columns (`function` + `association`), the existing soft-delete filtering continues to apply automatically.

### Virtual Columns in Forms

Virtual columns are **always read-only** — they are computed values, not stored fields. If a virtual column appears in a form layout section, it is rendered as a read-only display field (same as a field with `readonly: true`). The controller never includes virtual column names in `permitted_params`. No special validator rule is needed — the form simply renders them as non-editable.

**`visible_when` / `disable_when` edge case:** If a `visible_when` or `disable_when` condition on a form field references a virtual column (e.g., `{ field: is_overdue, operator: eq, value: "true" }`), the condition evaluator calls `record.is_overdue`. On **edit** pages the controller must load virtual columns — the current `set_record` loads the record via `scope.find(params[:id])` which does not include virtual column SELECT aliases. The `edit` action must call `load_virtual_columns` (a new method analogous to `load_show_aggregates`) after `set_record` to re-load the record with virtual column expressions. This is the same scoped-query approach used for show pages.

**`update` validation failure:** When `update` fails validation and re-renders the edit form, the record is dirty (it has the user's unsaved input). Re-loading the record via a scoped query would discard those changes. Instead, the `update` action resolves virtual columns by defining singleton reader methods on the existing dirty record — loading a **separate** clean record with virtual column expressions and copying the values:

```ruby
# In update action, after validation failure and before re-rendering edit:
if form_needs_virtual_columns?
  clean = model_class.where(id: @record.id)
  clean, service_only = VirtualColumns::Builder.apply(clean, model_def, vc_names, current_user: current_user)
  clean_record = clean.first
  vc_names.each do |name|
    value = clean_record&.send(name)
    @record.define_singleton_method(name) { value }
  end
  resolve_service_aggregates(@record, service_only)
end
```

This preserves the user's dirty attributes while making virtual column values available for `visible_when`/`disable_when` evaluation.

On **new** pages the record has no persisted data, so the virtual column attribute returns `nil` (the AR attribute default) — conditions referencing virtual columns evaluate to falsy. This is the expected behavior: a new record cannot be "overdue" or have approval status before it exists.

### Interaction with Conditions (Advanced Conditions spec)

Virtual columns provide an efficient alternative to in-memory condition evaluation for index pages:

| Without virtual columns | With virtual columns |
|---|---|
| Preload `approvals` for all 50 rows → in-memory check | `EXISTS(...)` in SELECT → read boolean attribute |
| N+1 if configurator forgets `includes` | No association access at all |
| Can't sort by condition result | Sortable — it's a real SQL column |

The configurator can define a virtual column and reference it in `item_classes.when` as a simple `{ field: has_approved_approval, operator: eq, value: "true" }`. The condition evaluator treats it as a regular field — no special handling needed.

This does **not** replace the advanced conditions system (compound conditions, dynamic value references, etc.). It provides a performance-optimized path for specific index-page use cases where the condition result can be pre-computed in SQL.

### Interaction with Summary Bar and Column Summaries

Virtual columns are **not supported** in `summary_bar` fields or column-level `summary` aggregations. Both mechanisms (`compute_summary_bar` and `compute_summaries`) operate on real database columns via `scope.sum(field)`, `scope.average(field)`, etc. — these ActiveRecord aggregation methods require real column names, not SQL aliases. Virtual column names would be silently skipped (the methods filter by `@model_class.column_names`).

For summary statistics over virtual column expressions, use a custom action or a dedicated dashboard presenter with its own SQL.

### Interaction with Ransack and Sorting

Virtual columns are **not** added to `ransackable_attributes`. They are SQL aliases, not real database columns — Ransack cannot use them in WHERE clauses (standard SQL does not allow WHERE on SELECT aliases without a wrapping subquery). Filtering by virtual columns must go through the platform's own mechanisms (custom scopes, condition services).

**Sorting** by virtual columns works because the platform uses its own `apply_sort` mechanism (not Ransack) for ORDER BY. The controller's `apply_sort` already detects aggregate names via `current_model_definition.aggregate(field)` and generates `ORDER BY alias_name ASC/DESC` via `Arel.sql(conn.quote_column_name(field))`. After the rename, the detection uses `current_model_definition.virtual_column(field)` (the accessor for the merged `virtual_columns` hash). The alias is always quoted via `quote_column_name` to prevent SQL injection through the `?sort=` parameter (defense in depth — even though field names are checked against known virtual column names). If the sort field matches a virtual column name, the controller orders by the SQL alias. No Ransack involvement in sorting.

**Pipeline order note:** In the controller, `apply_sort` runs before `VirtualColumns::Builder.apply` (which adds the SELECT aliases). This is correct — both methods add clauses to the same `ActiveRecord::Relation`, and the final SQL is composed from all accumulated clauses regardless of the Ruby call order. The `ORDER BY is_overdue` clause and the `SELECT ..., (expression) AS is_overdue` clause end up in the same SQL statement. SQL engines resolve ORDER BY aliases from the SELECT clause.

**Advanced filter (visual filter builder):** Virtual columns do **not** appear in the `FilterMetadataBuilder` output. The visual filter builder uses Ransack predicates, and since virtual columns are not in `ransackable_attributes`, they cannot be used as filter fields in the UI.

**Saved filters** store Ransack-based condition trees and therefore **cannot** include virtual column fields. For pre-filtered views based on virtual column expressions, use parameterized scopes with `type: custom`.

### Virtual Columns vs. Computed Fields

The platform has two distinct concepts for derived values — virtual columns and computed fields. They serve different purposes:

| | Virtual Columns | Computed Fields |
|---|---|---|
| **Storage** | No DB column — SQL alias in SELECT | Real DB column, persisted |
| **Calculation** | On every query (SQL expression) | On every save (`before_save` callback, Ruby) |
| **Sortable** | Yes (ORDER BY SQL alias) | Yes (real column, Ransack-compatible) |
| **Filterable (Ransack)** | No (SQL alias, not a real column) | Yes (real column) |
| **Data source** | Associations, cross-table JOINs, window functions | Same-record fields or service logic |
| **Use case** | `is_overdue`, `issues_count`, `company_display` | `full_name = "{first_name} {last_name}"`, `total = price * qty` |

**Rule of thumb:** If the value depends only on the record's own fields and should be filterable, use a computed field. If it depends on associated data (counts, EXISTS, JOINs) or needs to reflect the current state at query time (e.g., `CURRENT_DATE`), use a virtual column.

### Security: SQL Injection

The `expression:` and `join:` values are defined in YAML/DSL by the platform configurator (who has access to the codebase). They are **not** user input. The same trust model applies as for the existing `aggregates.sql:` key.

The `%{table}` placeholder is resolved to a properly quoted table name. No user-supplied values are interpolated into these strings (the `:current_user` placeholder in `where:` uses `conn.quote`).

## Usage Examples

### EXISTS check for row styling

```yaml
# models/order.yml
# EXISTS always returns TRUE/FALSE (never NULL), so default: is not needed.
# Compare with is_overdue below, which uses default: false because
# boolean arithmetic (AND/OR) with NULL operands returns NULL.
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
    default: false
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
| `type` | string | Yes (unless declarative) | Result type: string, integer, float, decimal, boolean, date, datetime, json. |
| `default` | any | No | COALESCE default value. |
| `auto_include` | boolean | No (default: false) | Include in every controller query, regardless of presenter references. Cannot combine with `group: true`. |
| `function` | string | Declarative only | Aggregate function (count, sum, min, max, avg). |
| `association` | string | Declarative only | Target has_many association. |
| `source_field` | string | Declarative only | Field on target model. |
| `where` | hash | Declarative only | Equality conditions on target model. Supports `:current_user` placeholder (resolves to `current_user.id`). |
| `distinct` | boolean | Declarative only (default: false) | Enables `COUNT(DISTINCT ...)` or `SUM(DISTINCT ...)`. |
| `include_discarded` | boolean | Declarative only (default: false) | Includes soft-deleted records in the subquery. |
| `service` | string | Service only | Service class key. |
| `options` | hash | Service only (default: {}) | Arbitrary options hash passed to `service.call` and `service.sql_expression`. |

All "subtypes" from the original design (`exists`, `expression+join`, `function+join`, window functions) are covered by `expression` + `join` + `group`. No special detection logic — the builder reads the keys that are present.

### Naming: `virtual_columns` with `aggregates` alias

Rename the concept from `aggregates` to `virtual_columns`. Keep `aggregates` as an alias during YAML loading — both keys map to the same internal representation. The platform is pre-production, so no migration cost.

- `AggregateDefinition` is renamed to `VirtualColumnDefinition` (or aliased).
- `ModelDefinition` accepts both `aggregates:` and `virtual_columns:` in YAML, merges into one hash. If the same name appears in both keys (e.g., `aggregates.foo` and `virtual_columns.foo`), the validator raises an error (ambiguous definition).
- `aggregate` DSL method stays as alias for `virtual_column`.

**`sql:` → `expression:` key migration:** The existing `sql:` key on aggregates becomes `expression:` in the new `VirtualColumnDefinition`. Both keys are accepted during YAML loading for backward compatibility — `sql:` is mapped to `expression:` internally. If both `sql:` and `expression:` are present on the same definition, the validator raises an error (ambiguous). New definitions should use `expression:`.

**Cached aggregates interaction:** The [cached aggregates spec](cached_aggregates.md) extends virtual column definitions with a `cache: true` option that converts a query-time virtual column into a persisted, auto-maintained column. This is orthogonal — the `cache:` key will be specified separately. After implementation, `cache: true` will apply to declarative virtual columns (`function` + `association`) within the `virtual_columns` block.

### Query builder

Extend `QueryBuilder` with:
- `build_expression` — expands `%{table}`, wraps with COALESCE if `default` is set. Covers all `expression:` columns (EXISTS, inline expressions, window functions, correlated subqueries). For `expression:` columns, the `default` key adds a COALESCE wrapper around the expression. Configurators should use either `default:` or inline `COALESCE(...)` in the expression — not both (the builder does not detect double-wrapping, but `COALESCE(COALESCE(x, 0), 0)` is functionally harmless).
- JOIN collection — collects `join:` strings from all requested virtual columns, deduplicates by normalized string match after `%{table}` expansion (`.gsub(/\s+/, " ").strip.downcase` before comparison to collapse all whitespace variants — tabs, newlines from YAML `|` vs `>-` — into single spaces, and to handle SQL keyword case differences), applies once via `scope.joins(Arel.sql(...))`. The original-case string is used in the SQL (not the downcased version) — downcasing is only for deduplication comparison.
- GROUP BY — if any requested column has `group: true`, adds `.group("#{parent_table}.id")`. The controller handles Kaminari pagination by pre-computing `total_count` via `scope.except(:select, :group, :joins).distinct.count(:id)` and injecting it into the paginated collection (see [GROUP BY Handling](#group-by-handling)).
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

1. **Always included** — virtual columns with `auto_include: true` on the model definition (except `group: true` columns — see [GROUP BY Handling](#group-by-handling)).
2. **Auto-detected** — names referenced in presenter's `table_columns`, `tile_fields`, `item_classes[].when` conditions (recursive walk through compound `all`/`any`/`not`), action `visible_when`/`disable_when` conditions (all action types: single, collection, batch), show `layout` fields, `record_rules[].when` conditions (recursive walk, scanned across all roles at boot time as a safe superset), and sort params at runtime (`?sort=field_name`).
3. **Explicitly declared** — names listed in presenter's `index.virtual_columns` or `show.virtual_columns`, action-level `virtual_columns`, or scope-level `virtual_columns`.

This is a significant expansion of the detection logic used for aggregates today (which only checks `table_columns` and `tile_fields`). The implementation introduces a `VirtualColumns::Collector` that scans all metadata sources in one pass. The collector receives both the `PresenterDefinition` and the `PermissionDefinition` (all roles — needed for `record_rules` scanning). The `auto_include` flag and explicit declarations at multiple levels (presenter, action, scope) are new capabilities.

**Computation:** The `VirtualColumns::Collector` scan result (the set of virtual column names) is computed per request via `VirtualColumns::Collector.collect(presenter_def:, model_def:, context:)`. The scan is lightweight — it traverses in-memory metadata objects, not YAML files — and returns a `Set<String>` of needed VC names for the given context.

**Scope-level and action-level `virtual_columns` application timing:** Both are included in the boot-time superset scan. The collector merges all `virtual_columns` declarations from all actions and all scopes into the per-presenter set. This means a virtual column declared on a single action (e.g., `escalate.virtual_columns: [health_score]`) is included in every index query for that presenter — not just when the action is executed. This is the same superset approach used for `record_rules`: including an unused virtual column in SELECT is harmless, while missing one at runtime would cause errors. If a virtual column is expensive and only needed for one rarely-used action, the configurator can move it to a separate presenter instead of declaring it action-level.

**Service-only virtual columns on index pages:** Service virtual columns without `sql_expression` are **not supported on index pages**. They are marked as `service_only` by the builder and skipped in the SELECT clause. On show/edit pages, they are resolved per-record via `define_singleton_method`. On index pages, the attribute returns `nil` (the AR attribute default). If a service-only virtual column is referenced in `table_columns` or `item_classes.when` on an index page, the value will be nil — conditions will evaluate incorrectly, and display will be empty. The `ConfigurationValidator` emits a **warning** when a service-only virtual column (no `sql_expression`) is referenced in a presenter's index-context metadata (table_columns, tile_fields, item_classes). To use a virtual column on index pages, the service must implement `sql_expression`.

**Scope limitation:** `auto_include: true` only affects queries that go through the controller pipeline. Direct model queries from custom actions, event handlers, or other Ruby code (`Model.find(id)`, `Model.where(...)`) do **not** include virtual columns. To access a virtual column outside the controller, the code must explicitly build the query with `VirtualColumns::Builder.apply`.

### ConfigurationValidator

The validator is extended to:
- Accept both `aggregates` and `virtual_columns` keys.
- Validate `expression` and `join` are strings when present.
- Validate `type` is required for `expression` and `service` subtypes.
- Validate `group` is boolean when present.
- **Error** if both `sql` and `expression` keys are present on the same definition.
- **Error** if `auto_include: true` combined with `group: true` (would break non-controller queries).
- **Error** if the same virtual column name appears in both `aggregates:` and `virtual_columns:` keys on the same model (ambiguous definition).
- Validate virtual column names don't collide with field names, association names, or scope names on the same model.
- Validate virtual column names don't collide with reserved method names. Concrete denylist: `id`, `type`, `class`, `save`, `save!`, `destroy`, `destroy!`, `delete`, `update`, `update!`, `create`, `valid?`, `invalid?`, `errors`, `new_record?`, `persisted?`, `frozen?`, `hash`, `object_id`, `send`, `respond_to?`, `freeze`, `dup`, `clone`, `inspect`, `to_s`, `to_param`, `to_model`, `model_name`, `reload`, `assign_attributes`, `becomes`, `attributes`, `read_attribute`, `write_attribute`, `attribute_names`, `changed?`, `changes`, `serializable_hash`.
- **Warning** when multiple `join` + `group` columns exist on the same model (cartesian product risk).
- **Warning** when a model has both `group: true` and window function virtual columns (window operates on grouped rows, which may surprise configurators).
- **Warning** when `auto_include: true` combined with `join:` (performance impact: every controller query — including show, edit, update — gets a JOIN). Recommend `auto_include: true` only for lightweight, join-free expressions (inline or correlated subquery).
- **Warning** when `auto_include: true` combined with a `service:` virtual column that has no `sql_expression` method (service-only virtual columns are not resolved on index pages — the value will be nil).
- **Warning** when a `service:` virtual column without `sql_expression` is referenced in a presenter's index-context metadata (`table_columns`, `tile_fields`, `item_classes`) — the value will be nil on index pages.
- **Warning** when duplicate service keys exist across `app/lcp_services/virtual_columns/` and `app/lcp_services/aggregates/` directories.

## Decisions

1. **Minimal key set: `expression`, `join`, `group`.** No `exists` or `window` subtypes. All non-declarative, non-service virtual columns are expressed as a SQL expression (projected into SELECT). This keeps the configuration surface small and avoids subtype detection logic. The configurator writes the SQL expression they need.

2. **Approach C: unified `virtual_columns` with `aggregates` alias.** One concept, one key, one builder. The platform is pre-production, so renaming is costless.

3. **Aggregate + join columns use correlated subqueries by convention.** The platform does not prevent `join` + `group`, but the validator warns about cartesian product risk when multiple such columns exist. Documentation recommends correlated subqueries for multiple aggregations.

4. **Virtual columns are defined on the model, with `auto_include` flag.** By default, virtual columns are only included in the query when a presenter references them (via `table_columns`, `item_classes`, etc.) or explicitly lists them in `index.virtual_columns`. Setting `auto_include: true` includes the column in every query for that model. This gives the configurator control: define once on the model, activate per presenter.

5. **Virtual columns are not added to Ransack's `ransackable_attributes`.** SQL aliases cannot be used in WHERE clauses without a wrapping subquery. Sorting uses the platform's custom `apply_sort` mechanism (not Ransack), which already detects aggregate/virtual column names and generates `ORDER BY alias`. Filtering must use the platform's own mechanisms or custom scopes.

6. **`%{table}` is the only placeholder in `expression`/`join` strings.** User values use the `where:` hash with `conn.quote`. No string interpolation of user input.

7. **Service lookup path.** The `Services::Registry` gains a new category `"virtual_columns"` with discovery in `app/lcp_services/virtual_columns/`. For backward compatibility, the builder looks up a service key in category `"virtual_columns"` first, then falls back to `"aggregates"`. If both directories contain a service with the same key, `"virtual_columns"` takes priority. The `ConfigurationValidator` warns on duplicate service keys across the two directories.

8. **DB portability is the configurator's responsibility for `expression:` strings.** For DB-portable logic, use service virtual columns with Arel. The platform does not abstract raw SQL differences between PostgreSQL and SQLite.

9. **No `where:` on `expression:` columns.** The `where:` clause is only for declarative virtual columns (`function` + `association`). Expression columns embed their own WHERE conditions directly in the SQL string. Mixing raw SQL with structured conditions would make the builder unnecessarily complex.

10. **No SQL parsing in `ConfigurationValidator`.** The validator does not parse `expression:` or `join:` strings to detect table references or syntax errors. Parsing SQL is fragile and DB-specific. Errors surface at query time. The configurator is trusted.

11. **`join:` is a single string, not an array.** A virtual column that needs multiple JOINs concatenates them in one string (`"LEFT JOIN companies ON ... LEFT JOIN industries ON ..."`). An array form would add parsing complexity for minimal benefit.

12. **Type coercion via `model_class.attribute` with loaded-tracking guard.** Virtual columns register an AR `attribute` declaration at boot, ensuring consistent Ruby types regardless of database adapter (e.g., boolean is `true`/`false` on both PostgreSQL and SQLite). Tracking which virtual columns were actually loaded uses a **thread-local stack** (array of Sets) on the model class, pushed/popped around actual SQL execution via `scope.extending` (wrapping `exec_queries`). A stack is used instead of a single value because `exec_queries` can nest (e.g., an `after_initialize` callback queries the same model class) — each invocation pushes its own set and pops on completion, preventing inner queries from corrupting outer tracking. The `after_initialize` callback copies the stack's top element onto each loaded record. The guard is checked in `ConditionEvaluator` and `FieldValueResolver` via the public method `record.virtual_column_loaded?(name)` (not in the attribute getter — to avoid breaking `to_json`/`serializable_hash`). If a virtual column returns `nil` on a persisted record and is not in the loaded set, `ConditionEvaluator` raises `ConditionError` and `FieldValueResolver` raises `LcpRuby::Error` instead of silently evaluating with `nil`. Note: `attributes.keys` cannot be used for tracking because the boot-time `attribute` declaration causes all virtual column names to appear in `attributes.keys` regardless of whether they were in the query's SELECT. See [Type Coercion — Loaded-tracking guard](#loaded-tracking-guard).

13. **Show page loads virtual columns via scoped query.** The controller builds `Model.where(id:).select(...)` instead of `Model.find(id)` to include virtual column expressions. Service virtual columns prefer `call(record)` on the show page when available; if the service only defines `sql_expression`, the show page falls back to the SQL query path.

14. **Virtual columns are always read-only in forms.** If referenced in a form layout, they render as read-only display fields. No validator error — just silent read-only rendering.

15. **Soft delete filtering is the configurator's responsibility in `expression:` strings.** The platform does not inject `AND discarded_at IS NULL` into raw SQL. Declarative virtual columns (`function` + `association`) continue to apply soft-delete filtering automatically.

16. **JOIN deduplication is normalized-string-based for v1.** Virtual column JOINs are deduplicated among themselves by normalized string match (`.gsub(/\s+/, " ").strip.downcase` after `%{table}` expansion) to collapse all whitespace variants (tabs, newlines from YAML `|` vs `>-` block scalars) and handle SQL keyword case differences. The original-case string is used in the generated SQL — downcasing is only for comparison. Deduplication with `eager_load` JOINs is not handled in v1 — configurators should use correlated subqueries if a conflict arises.

17. **Name collision validation.** Virtual column names are checked against field names, association names, scope names, and a concrete denylist of critical ActiveRecord/Ruby methods (see [ConfigurationValidator](#configurationvalidator)).

18. **`sql:` backward compatibility.** The existing `sql:` key is accepted as an alias for `expression:` during YAML loading. Both `sql:` and `expression:` map to the same internal field. If both are present on the same definition, the validator raises an error. New definitions should use `expression:`.

19. **`auto_include: true` + `group: true` is prohibited.** An always-included GROUP BY would break non-controller queries (`Model.count`, `Model.exists?`, etc.). The validator raises an error for this combination.

20. **`auto_include` only affects controller queries.** Direct `Model.find`, `Model.where` calls from custom actions, event handlers, or other Ruby code do not include virtual columns. Code outside the controller must use `VirtualColumns::Builder.apply` explicitly.

21. **Permission scopes cannot reference virtual column names.** `ScopeBuilder`'s `where` and `field_match` types use `.where()` which requires real columns. Virtual column names in WHERE would cause "column does not exist" errors. To filter by a virtual column expression in a permission scope, use `type: custom` with a named scope.

22. **`eager_load` conflict mitigation.** When virtual columns are present, `IncludesResolver` should emit `.preload()` instead of `.includes()` for `:display`-reason dependencies. Unlike `includes`, `.preload()` always uses separate queries and never silently falls back to LEFT JOIN — so the custom `.select()` from virtual columns cannot break it. When `eager_load` is unavoidable (`:query`-reason dependencies, e.g., sorting by an associated field), the `IncludesResolver` (not the virtual column builder) is responsible for merging eager_load table columns into the existing SELECT: `scope.select("assoc_table.*")`. This is because the builder runs before the resolver in the controller pipeline and doesn't know which associations will be eager_loaded. The resolver detects an existing custom `.select()` on the scope and appends the needed table columns before applying `.eager_load()`. Note: this conflict already exists with the current aggregates `QueryBuilder.apply` (which calls `scope.select()`), so the mitigation benefits both aggregates and virtual columns.

23. **Loaded-tracking via `scope.extending` + thread-local stack + `after_initialize`.** `VirtualColumns::Builder.apply` attaches a `scope.extending(Module)` that pushes/pops a `thread_mattr_accessor` **stack** around `exec_queries` (the AR method that runs SQL and instantiates records). A stack (not a single value) is used because `exec_queries` can nest — e.g., an `after_initialize` callback or condition service queries the same model class. Each invocation pushes its own set of virtual column names and pops on completion, so nested queries don't corrupt outer tracking. The stack's top element is only set during the exact window when `after_initialize` callbacks fire — not during the gap between the lazy `apply` call and actual SQL execution. The `after_initialize` callback copies the top element onto each loaded record (skipping new records via `persisted?` early return). `VirtualColumnApplicator` overrides `reload` to clear `@_loaded_virtual_columns`, preventing stale tracking after a re-read. This approach works transparently with `find_each` / `find_in_batches` (each batch goes through `exec_queries`). See [Type Coercion — Loaded-tracking guard](#loaded-tracking-guard).

24. **`auto_include: true` + service-only virtual columns.** The validator warns when `auto_include: true` is combined with a `service:` virtual column that has no `sql_expression` method. Service-only virtual columns are not resolved on index pages (see Decision 27), so `auto_include` would mark the column for inclusion but the value would be `nil` on every index query. The configurator should either add `sql_expression` to the service or remove `auto_include`.

25. **`VirtualColumns::Builder.apply` public API.** The builder exposes `apply(scope, model_definition, virtual_column_names, current_user: nil)` returning `[modified_scope, service_only_names, needs_group_by]`. This is the entry point for both controller queries and custom code that needs virtual columns outside the controller pipeline. The `current_user:` is passed through to declarative `where:` conditions (`:current_user` placeholder). The third return value (`needs_group_by`) is `true` when any applied VC has `group: true`, used by the controller to fix Kaminari pagination.

26. **Saved filters cannot reference virtual columns.** Saved filters store Ransack-based condition trees. Since virtual columns are not in `ransackable_attributes`, they cannot appear in saved filter conditions. For pre-filtered views, use parameterized scopes.

27. **Service-only virtual columns are not resolved on index pages.** Service virtual columns without `sql_expression` are skipped in the SELECT clause. On show/edit pages they are resolved per-record via `define_singleton_method`. On index pages, the attribute returns `nil`. The validator warns when such columns are referenced in index-context metadata.

28. **Boolean expressions need `default: false` for NULL safety.** SQL boolean expressions like `(due_date < CURRENT_DATE AND status != 'done')` return NULL (not FALSE) when any operand is NULL (e.g., `due_date` is NULL). After AR's boolean type coercion, `nil` ≠ `false` — a condition `{ operator: eq, value: "false" }` would not match `nil`. Configurators should use `default: false` on boolean virtual columns that use arithmetic/comparison operators. Exception: `EXISTS(...)` always returns TRUE/FALSE (never NULL), so `default:` is not needed for EXISTS expressions.

29. **`VirtualColumns::Collector` results are computed per request.** The scan of presenter metadata (table_columns, tile_fields, item_classes, record_rules, actions, scopes) is computed per request via `VirtualColumns::Collector.collect`. The scan is lightweight (in-memory metadata traversal) and produces a `Set<String>` of needed VC names for the given context (`:index`, `:show`, `:edit`). Scope-level and action-level `virtual_columns` declarations are merged into the result for all contexts.

30. **Same name in both `aggregates:` and `virtual_columns:` is an error.** When YAML loading merges the two keys, name collisions are caught by the validator and reported as an error (ambiguous definition).

## Open Questions

(none — all questions resolved)
