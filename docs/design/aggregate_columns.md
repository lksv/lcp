# Feature Specification: Aggregate & Computed Columns

**Status:** Proposed
**Date:** 2026-03-02

## Problem / Motivation

Index pages currently display only data stored directly on the record or reachable via dot-path association traversal (e.g., `company.name`). There is no way to show derived values that require SQL aggregation — counts, sums, minimums, maximums, or averages computed across associated records.

Real-world information systems routinely need these:

- **Issue tracker:** project index shows the number of open issues per project
- **CRM:** company index shows total revenue (SUM of completed orders)
- **Helpdesk:** ticket index shows time since last comment (MAX of `comments.created_at`)
- **Project management:** sprint index shows average task effort (AVG of `tasks.effort`)
- **Inventory:** warehouse index shows count of distinct product types

Without platform support, host apps must resort to counter caches, denormalized columns, or custom view overrides — all of which break the declarative YAML-driven model.

## User Scenarios

**As a platform user configuring a project tracker,** I want to define `issues_count` and `open_issues_count` on my `project` model so that the project index table shows these values in sortable columns, without writing any Ruby code.

**As a platform user building a CRM,** I want to show `last_activity_at` (MAX of `activities.created_at`) on the company index and show pages, rendered as a relative date ("3 days ago"), and I want to sort by it to find inactive companies.

**As a host app developer,** I want to define a complex `health_score` computed column using custom Ruby logic (e.g., combining multiple aggregates with business rules), and optionally provide a SQL expression for efficient sorting on the index page.

**As a platform user,** I want aggregate columns to respect soft delete — counting only active (non-discarded) child records by default.

## Configuration & Behavior

### Model YAML — new top-level `aggregates` key

Aggregates are defined on the model, alongside `fields` and `associations`. Each aggregate has a unique name and becomes a virtual attribute on the model class — referenceable in presenters just like a regular field.

```yaml
# config/lcp_ruby/models/project.yml
name: project
fields:
  - { name: name, type: string }
  - { name: status, type: enum, values: [active, archived] }

associations:
  - { type: has_many, name: issues, target_model: issue }
  - { type: has_many, name: comments, target_model: comment }
  - { type: has_many, name: orders, target_model: order }

aggregates:
  issues_count:
    function: count
    association: issues

  open_issues_count:
    function: count
    association: issues
    where: { status: open }

  last_comment_at:
    function: max
    association: comments
    source_field: created_at

  total_revenue:
    function: sum
    association: orders
    source_field: amount
    where: { status: completed }

  avg_order_value:
    function: avg
    association: orders
    source_field: amount
    default: 0

  weighted_score:
    sql: "SELECT SUM(r.score * r.weight) / NULLIF(SUM(r.weight), 0) FROM ratings r WHERE r.project_id = %{table}.id"
    type: float

  health_index:
    service: project_health
    type: float
```

### Aggregate definition schema

```yaml
aggregates:
  <name>:                        # unique name, becomes the virtual attribute name
    # --- Type 1: Declarative SQL aggregate ---
    function: count | sum | min | max | avg
    association: <has_many association name>
    source_field: <field on target model>   # required for sum/min/max/avg; optional for count
    where: { field: value, ... }            # optional equality conditions on target model
    distinct: true                          # optional, for COUNT(DISTINCT ...) or SUM(DISTINCT ...)
    default: <value>                        # optional, COALESCE wrap (count always defaults to 0)
    include_discarded: false                # optional, default false; when false, excludes soft-deleted records

    # --- Type 2: Custom SQL expression ---
    sql: "<SQL subquery returning a single value>"
    type: string | integer | float | decimal | boolean | date | datetime

    # --- Type 3: Service (custom code) ---
    service: <service_key>                  # looked up in app/lcp_services/aggregates/
    type: string | integer | float | decimal | boolean | date | datetime
    options: { ... }                        # optional hash passed to the service
```

**Type inference for declarative aggregates:**

| Function | Inferred type |
|----------|---------------|
| `count` | `integer` |
| `sum` | same as `source_field` type |
| `min` / `max` | same as `source_field` type |
| `avg` | `float` (or `decimal` if source is `decimal`) |

For `sql:` and `service:` types, `type` is required.

**The `where` clause** uses simple hash equality conditions — the same syntax as model scope `where`. Rails handles array values as `IN (...)` and `null` as `IS NULL`:

```yaml
where: { status: open }                      # WHERE status = 'open'
where: { status: [open, in_progress] }       # WHERE status IN ('open', 'in_progress')
where: { deleted_at: null }                  # WHERE deleted_at IS NULL
where: { status: active, priority: high }    # WHERE status = 'active' AND priority = 'high'
```

For anything more complex (operators, OR conditions, subqueries), use `sql:` or `service:`.

**The `%{table}` placeholder** in SQL expressions is replaced with the quoted table name of the parent model at query time. This avoids hardcoding table names.

### Model DSL

```ruby
define_model :project do
  field :name, :string
  field :status, :enum, values: %w[active archived]

  has_many :issues, model: :issue
  has_many :comments, model: :comment
  has_many :orders, model: :order

  # Declarative
  aggregate :issues_count, function: :count, association: :issues
  aggregate :open_issues_count, function: :count, association: :issues, where: { status: "open" }
  aggregate :last_comment_at, function: :max, association: :comments, source_field: :created_at
  aggregate :total_revenue, function: :sum, association: :orders, source_field: :amount,
            where: { status: "completed" }

  # Custom SQL
  aggregate :weighted_score,
            sql: "SELECT SUM(r.score * r.weight) / NULLIF(SUM(r.weight), 0) FROM ratings r WHERE r.project_id = %{table}.id",
            type: :float

  # Service
  aggregate :health_index, service: :project_health, type: :float
end
```

### Presenter YAML — aggregates referenced as regular fields

The presenter does not need special syntax for aggregate columns. Aggregate names are referenced in `table_columns` and `show.layout` just like any other field:

```yaml
# config/lcp_ruby/presenters/projects.yml
name: projects
model: project
slug: projects

index:
  table_columns:
    - { field: name, width: "25%", link_to: show, sortable: true }
    - { field: status, renderer: badge, sortable: true }
    - { field: issues_count, sortable: true }
    - { field: open_issues_count, sortable: true }
    - { field: last_comment_at, renderer: relative_date, sortable: true }
    - { field: total_revenue, renderer: currency, options: { currency: "EUR" }, sortable: true }
    - { field: health_index, renderer: progress_bar, sortable: false }

show:
  layout:
    - type: details
      title: Overview
      fields:
        - { field: name }
        - { field: status, renderer: badge }
    - type: details
      title: Statistics
      fields:
        - { field: issues_count }
        - { field: open_issues_count }
        - { field: last_comment_at, renderer: relative_date }
        - { field: total_revenue, renderer: currency, options: { currency: "EUR" } }
        - { field: health_index, renderer: progress_bar }
```

Renderers, labels, options, `link_to`, width — all work exactly as with regular fields. This is the key advantage of the model-level approach: the presenter treats aggregates as first-class fields.

### Sorting

Aggregate columns that are backed by SQL (declarative and `sql:` types) can have `sortable: true` in the presenter. The engine translates this to `ORDER BY <aggregate_alias>`.

Service-based aggregates can also be sortable if the service provides a `sql_expression` class method (see [Service Extension Point](#service-extension-point)). Without `sql_expression`, sorting is not possible — `ConfigurationValidator` emits an error if `sortable: true` is set on a service aggregate that lacks it.

### Permissions

Aggregate columns are visible to any role that can see the presenter. They do not participate in field-level `readable`/`writable` permission checks — aggregates are read-only derived values, not model fields.

If a future need arises to restrict aggregate visibility by role, a `readable_aggregates` key could be added to the permission YAML. For now, YAGNI.

### Soft delete interaction

When the target model uses soft delete (`soft_delete: true`), declarative aggregate subqueries automatically add `AND <target_table>.discarded_at IS NULL` to exclude discarded records. Set `include_discarded: true` on the aggregate to override this behavior.

For `sql:` and `service:` types, soft delete filtering is the author's responsibility.

## Usage Examples

### Basic: issue count on project index

```yaml
# models/project.yml
aggregates:
  issues_count:
    function: count
    association: issues

# presenters/projects.yml
index:
  table_columns:
    - { field: name, link_to: show, sortable: true }
    - { field: issues_count, sortable: true }
```

Generated SQL:
```sql
SELECT projects.*,
  (SELECT COUNT(*) FROM issues WHERE issues.project_id = projects.id) AS issues_count
FROM projects
ORDER BY issues_count DESC
LIMIT 25 OFFSET 0
```

### Conditional: count only open issues

```yaml
aggregates:
  open_issues_count:
    function: count
    association: issues
    where: { status: open }
```

Generated SQL:
```sql
(SELECT COUNT(*) FROM issues
 WHERE issues.project_id = projects.id AND issues.status = 'open') AS open_issues_count
```

### Distinct count: unique commenters

```yaml
aggregates:
  unique_commenters:
    function: count
    association: comments
    source_field: user_id
    distinct: true
```

Generated SQL:
```sql
(SELECT COUNT(DISTINCT comments.user_id) FROM comments
 WHERE comments.project_id = projects.id) AS unique_commenters
```

### SUM with default: total revenue

```yaml
aggregates:
  total_revenue:
    function: sum
    association: orders
    source_field: amount
    where: { status: completed }
    default: 0
```

Generated SQL:
```sql
(SELECT COALESCE(SUM(orders.amount), 0) FROM orders
 WHERE orders.project_id = projects.id AND orders.status = 'completed') AS total_revenue
```

### Custom SQL: weighted average

```yaml
aggregates:
  weighted_score:
    sql: "SELECT SUM(r.score * r.weight) / NULLIF(SUM(r.weight), 0) FROM ratings r WHERE r.project_id = %{table}.id"
    type: float
    default: 0
```

Generated SQL (after `%{table}` expansion and COALESCE wrap):
```sql
(SELECT COALESCE(
  (SELECT SUM(r.score * r.weight) / NULLIF(SUM(r.weight), 0)
   FROM ratings r WHERE r.project_id = "projects".id),
  0)) AS weighted_score
```

### Custom service: health index

```yaml
# models/project.yml
aggregates:
  health_index:
    service: project_health
    type: float
    options:
      weight_open: 2
      weight_stale: 3
```

```ruby
# app/lcp_services/aggregates/project_health.rb
module LcpRuby
  module HostServices
    module Aggregates
      class ProjectHealth
        # Required: compute for a single record
        def self.call(record, options: {})
          open = record.issues.where(status: "open").count
          total = record.issues.count
          return 0.0 if total.zero?
          ((total - open).to_f / total * 100).round(1)
        end

        # Optional: SQL expression for efficient index queries + sorting
        def self.sql_expression(model_class, options: {})
          t = model_class.table_name
          <<~SQL.squish
            SELECT ROUND(CAST(
              CASE WHEN COUNT(*) = 0 THEN 0.0
              ELSE (COUNT(*) - SUM(CASE WHEN issues.status = 'open' THEN 1 ELSE 0 END))::float
                   / COUNT(*) * 100
              END AS numeric), 1)
            FROM issues WHERE issues.project_id = #{t}.id
          SQL
        end
      end
    end
  end
end
```

When `sql_expression` is provided, the index page uses it for efficient query + sorting. The `call` method is used on the show page and as a fallback. Both methods receive the same `options` hash from the YAML definition.

### Show page display

Aggregates on the show page work identically to regular fields in a `details` section:

```yaml
show:
  layout:
    - type: details
      title: Statistics
      fields:
        - { field: issues_count }
        - { field: open_issues_count }
        - { field: last_comment_at, renderer: relative_date }
```

On the show page, the controller loads a single record. For SQL-based aggregates, the record is loaded with the subquery SELECTs. For service aggregates, `service.call(record, options:)` is called directly.

## Service Extension Point

Custom aggregate services follow the standard LCP Ruby service discovery pattern.

### Discovery

| Concern | Value |
|---------|-------|
| Directory | `app/lcp_services/aggregates/` |
| Namespace | `LcpRuby::HostServices::Aggregates::` |
| Category | `aggregates` (added to `Services::Registry::VALID_CATEGORIES`) |
| Base class | None required (duck typing) |

### Interface

```ruby
module LcpRuby::HostServices::Aggregates
  class MyComputation
    # Required: compute value for a single record.
    # Called on show pages and as fallback on index pages when sql_expression is absent.
    #
    # @param record [ActiveRecord::Base] the loaded record
    # @param options [Hash] the options hash from the YAML definition
    # @return [Object] the computed value (must match the declared `type`)
    def self.call(record, options: {})
      # ...
    end

    # Optional: return a SQL subquery string for efficient index page queries.
    # When present, the engine injects this as a SELECT subquery instead of
    # calling `call` per record. Also enables `sortable: true` in the presenter.
    #
    # The returned SQL must be a valid subquery that returns a single value.
    # It should NOT include the outer parentheses or AS alias — the engine adds those.
    #
    # @param model_class [Class] the ActiveRecord model class (use for table_name, etc.)
    # @param options [Hash] the options hash from the YAML definition
    # @return [String] SQL subquery string
    def self.sql_expression(model_class, options: {})
      # ...
    end
  end
end
```

**When `sql_expression` is provided:**
- Index page: injected as `(SELECT ...) AS <name>` — one query, no N+1
- Show page: `call(record)` is used (simpler, no need for subquery on a single record)
- Sorting: allowed (`sortable: true` valid in presenter)

**When `sql_expression` is absent:**
- Index page: `call(record)` invoked per loaded record — acceptable for small page sizes but can cause N+1; the host developer is responsible for efficiency
- Show page: `call(record)` as above
- Sorting: not possible; `ConfigurationValidator` rejects `sortable: true`

## General Implementation Approach

### SQL strategy: correlated subqueries in SELECT

Each declarative or SQL aggregate becomes a correlated subquery in the SELECT clause:

```sql
SELECT projects.*,
  (SELECT COUNT(*) FROM issues WHERE issues.project_id = projects.id) AS issues_count,
  (SELECT MAX(comments.created_at) FROM comments WHERE comments.project_id = projects.id) AS last_comment_at
FROM projects
ORDER BY issues_count DESC
LIMIT 25 OFFSET 0
```

**Why not JOIN + GROUP BY:**
- Multiple `has_many` JOINs cause cartesian products (incorrect counts)
- GROUP BY breaks pagination (Kaminari) and eager loading
- Each aggregate is independent — no interference between them

**Why correlated subqueries work well:**
- No interaction with existing query pipeline (no GROUP BY)
- Pagination works unchanged
- Eager loading works unchanged
- Sorting by alias works in all major databases
- Databases optimize correlated subqueries efficiently (usually into a hash join or index scan)

### Lazy inclusion — aggregates are injected only when needed

Aggregate subqueries add overhead. They should only be included when the current presenter actually references them:

1. **Index page:** `ColumnSet` collects names of referenced aggregates from `visible_table_columns`. Only those aggregates get injected into the query via `.select("#{table}.*", *subqueries)`.
2. **Show page:** `LayoutBuilder` collects referenced aggregate names from show sections. The single-record query includes only those subqueries. For service aggregates, `call` is invoked directly (no query modification).
3. **No presenter reference → zero overhead.**

### Association resolution for subqueries

The engine resolves the `association` name to a concrete SQL subquery by reading the `AssociationDefinition`:

1. Find the association on the model: `model_definition.associations.find { |a| a.name == aggregate.association }`
2. Resolve the target table: `target_model.table_name`
3. Resolve the foreign key: `association.foreign_key` (for `belongs_to` on the target, or `has_many` FK convention)
4. Build the WHERE clause: `target_table.fk = parent_table.id`
5. For polymorphic `has_many` (with `as:`): add `AND target_table.type = 'LcpRuby::Dynamic::ParentModel'`
6. For soft-deleted target models (unless `include_discarded`): add `AND target_table.discarded_at IS NULL`
7. Apply `where` conditions: `AND target_table.field = value` for each entry
8. Apply function: `COUNT(*)`, `SUM(target_table.source_field)`, etc.
9. Apply `distinct` if present: `COUNT(DISTINCT target_table.source_field)`
10. Apply `default` via COALESCE wrapper if present (count always gets COALESCE to 0)

### Value resolution flow

**Index page:**
1. Controller detects referenced aggregates from `ColumnSet`
2. `AggregateQueryBuilder.apply(scope, model_definition, aggregate_names)` adds `.select(...)` with subqueries for SQL-based aggregates
3. Records are loaded — aggregate values available as `record.read_attribute("issues_count")`
4. `FieldValueResolver` detects aggregate field → reads the virtual attribute
5. For service aggregates without `sql_expression` → calls `service.call(record, options:)` per record
6. Renderer formats the value

**Show page:**
1. `LayoutBuilder` identifies aggregate fields in show sections
2. For SQL-based aggregates: record loaded with subquery SELECTs (same builder)
3. For service aggregates: `service.call(record, options:)` called directly
4. `FieldValueResolver` resolves, renderer displays

### Sorting by aggregate columns

`apply_sort` in `ApplicationController` already handles simple fields and dot-path fields. A new branch detects aggregate field names:

1. Check if `sort_field` matches a known aggregate name on the model
2. Verify the aggregate is SQL-based (declarative, `sql:`, or service with `sql_expression`)
3. Apply `scope.order(Arel.sql("#{aggregate_alias} #{direction}"))` — the alias is already in SELECT

### Interaction with existing features

**Eager loading (IncludesResolver):** Aggregate columns need no eager loading — they are subqueries, not association traversals. `DependencyCollector` ignores aggregate field names.

**Quick search:** Aggregates are not included in quick search (`?qs=`) — they are derived values, not searchable text fields.

**Ransack:** Aggregate aliases are not added to `ransackable_attributes`. Filtering by aggregate values is a v2 feature.

**Record rules / visible_when / disable_when:** Aggregate names could be referenced in conditions (e.g., `visible_when: { issues_count: { gt: 0 } }`). This requires the aggregate value to be loaded on the record — which happens naturally when the aggregate is in the presenter. Implementation detail: `ConditionEvaluator` would read the virtual attribute. This is a natural extension but can be deferred.

**Custom fields:** Aggregates and custom fields are orthogonal. No interaction.

**Auditing:** Aggregates are not persisted, so not audited. No interaction.

## Decisions

1. **Model-level, not presenter-level.** Aggregates are data concepts, not presentation concepts. Defining them on the model enables reuse across presenters and in show pages. The presenter references them by name, like any field.

2. **Correlated subqueries, not JOIN + GROUP BY.** Subqueries are independent, don't break pagination or eager loading, and scale to multiple aggregates without cartesian product issues.

3. **Three aggregate types — declarative, SQL, service.** Declarative covers 80% of cases (no code needed). SQL covers complex expressions. Service covers arbitrary Ruby logic and provides the full escape hatch.

4. **Service interface: `call` required, `sql_expression` optional.** This lets host developers start with simple Ruby code and add the SQL optimization later when needed.

5. **Permissions: visible to all roles.** Aggregates are derived read-only values. Fine-grained per-role aggregate visibility is YAGNI for now.

6. **Soft delete respected by default.** Declarative aggregates automatically exclude discarded records on soft-deleted target models. Explicit opt-out via `include_discarded: true`.

7. **Show page: yes.** Aggregates are usable in show page sections, not just index columns.

## Open Questions / Future (v2)

1. **Filtering by aggregate values** — Enabling `?f[issues_count_gteq]=5` on the index page would require wrapping the query in a CTE or using HAVING. Deferred to v2.

2. **Counter cache optimization** — For high-traffic COUNT columns, a `cache: true` option could generate a Rails `counter_cache` column with automatic increment/decrement. Deferred to v2.

3. **Through associations** — `project → sprints → tasks` (count of tasks through sprints) would require a JOIN in the subquery. Possible extension:
   ```yaml
   task_count:
     function: count
     association: tasks
     through: sprints
   ```
   Deferred to v2 — for now, use `sql:` or `service:` for multi-hop aggregates.

4. **Extended `where` operators** — The current `where` supports only hash equality. Supporting the platform's condition operators (`gt`, `lt`, `in`, `contains`, etc.) in aggregate conditions could be useful:
   ```yaml
   where:
     - { field: created_at, operator: gte, value: "2024-01-01" }
   ```
   Deferred to v2 — use `sql:` or `service:` for complex conditions.

5. **Aggregate in `record_rules` / `visible_when`** — Using aggregate values in conditions (e.g., hide edit button when `issues_count > 100`). Natural extension once aggregate values are loaded on records.

6. **Dashboard / summary aggregates** — Aggregates over the entire filtered result set (not per-record), e.g., "Total revenue across all visible projects: $1.2M". Related to the existing `summary` column feature (`sum`, `avg`, `count` in table footer). Could share configuration.
