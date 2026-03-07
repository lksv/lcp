# Virtual Columns Guide

Virtual columns are computed values that exist only at query time — they are not stored in the database. The engine injects them into SQL SELECT statements as subqueries, expressions, or JOINed values. They can be displayed in table columns, show pages, used for sorting, and referenced in conditional rendering (`visible_when`, `item_classes`).

Virtual columns are the unified successor to the older `aggregates` system. All existing aggregate definitions continue to work unchanged.

## Quick Start

### Count child records (declarative aggregate)

**YAML:**

```yaml
model:
  name: project
  fields:
    - { name: name, type: string }
  associations:
    - { type: has_many, name: tasks, target_model: task, foreign_key: project_id }
  virtual_columns:
    tasks_count:
      function: count
      association: tasks
```

**DSL:**

```ruby
define_model :project do
  field :name, :string
  has_many :tasks, model: :task, foreign_key: :project_id
  virtual_column :tasks_count, function: :count, association: :tasks
end
```

### Derived boolean expression

```yaml
virtual_columns:
  is_overdue:
    expression: "CASE WHEN %{table}.due_date < CURRENT_DATE AND %{table}.status != 'completed' THEN 1 ELSE 0 END"
    type: boolean
```

### JOIN-based column (pull data from another table)

```yaml
virtual_columns:
  company_name:
    expression: "companies.name"
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"
    type: string
```

### GROUP BY aggregate (sum over joined rows)

```yaml
virtual_columns:
  total_value:
    expression: "COALESCE(SUM(line_items.quantity * line_items.unit_price), 0)"
    join: "LEFT JOIN line_items ON line_items.order_id = %{table}.id"
    group: true
    type: decimal
```

## How It Works

The virtual columns pipeline has three stages:

1. **Boot time** — `VirtualColumnApplicator` declares ActiveRecord `attribute` for each virtual column, enabling type coercion (e.g., `1`/`0` to `true`/`false` for booleans). It also validates that service-based VCs reference registered services.

2. **Request time (collection)** — `Collector` scans the presenter metadata (table columns, tile fields, `item_classes`, `visible_when`, show layout, explicit `virtual_columns` lists) to determine which virtual columns are needed for the current page context. Only referenced columns are loaded.

3. **Query time** — `Builder` takes the scope and the collected VC names, injects SQL into the SELECT clause, appends any JOINs (deduplicated), adds GROUP BY if needed, and returns the augmented scope plus a list of service-only VCs for post-query evaluation.

## Four Virtual Column Types

### 1. Declarative Aggregates

SQL aggregate functions over a `has_many` association, built as correlated subqueries. This is the original `aggregates` functionality.

```yaml
virtual_columns:
  tasks_count:
    function: count
    association: tasks

  open_tasks_count:
    function: count
    association: tasks
    where: { status: open }

  total_hours:
    function: sum
    association: time_entries
    source_field: hours
    default: 0

  earliest_task:
    function: min
    association: tasks
    source_field: due_date

  unique_status_count:
    function: count
    association: tasks
    source_field: status
    distinct: true          # COUNT(DISTINCT status)
```

**Available functions:** `count`, `sum`, `min`, `max`, `avg`

**Key attributes:**
- `function` — the SQL aggregate function
- `association` — name of a `has_many` association
- `source_field` — field to aggregate (required for sum/min/max/avg, optional for count)
- `where` — equality filter conditions on the target table
- `distinct` — use DISTINCT in the function (default: `false`)
- `default` — COALESCE default value (`count` always defaults to `0`)
- `include_discarded` — include soft-deleted records (default: `false`)

**Type inference:** Declarative aggregates infer their type automatically — `count` is always `integer`, `sum`/`min`/`max` match the source field type, `avg` returns `float` (or `decimal` if source is `decimal`).

### 2. Expression Columns

Inline SQL expressions injected directly into the SELECT clause. Use `%{table}` to reference the parent model's table.

```yaml
virtual_columns:
  is_overdue:
    expression: "CASE WHEN %{table}.due_date < CURRENT_DATE THEN 1 ELSE 0 END"
    type: boolean

  days_until_due:
    expression: "JULIANDAY(%{table}.due_date) - JULIANDAY('now')"
    type: integer

  full_label:
    expression: "%{table}.code || ' - ' || %{table}.name"
    type: string
    default: ""
```

Expression columns require an explicit `type`.

### 3. Expression + JOIN Columns

When the expression references another table, add a `join` clause. Multiple VCs can reference the same JOIN — duplicates are automatically deduplicated.

```yaml
virtual_columns:
  company_name:
    expression: "companies.name"
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"
    type: string

  company_country:
    expression: "companies.country"
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id"
    type: string

  # Both columns above produce a single JOIN in the query
```

When the expression uses an aggregate function over the joined rows, set `group: true` to add `GROUP BY parent_table.id`:

```yaml
virtual_columns:
  total_value:
    expression: "COALESCE(SUM(line_items.quantity * line_items.unit_price), 0)"
    join: "LEFT JOIN line_items ON line_items.order_id = %{table}.id"
    group: true
    type: decimal

  items_total_quantity:
    expression: "COALESCE(SUM(line_items.quantity), 0)"
    join: "LEFT JOIN line_items ON line_items.order_id = %{table}.id"
    group: true
    type: integer
```

**Caution:** Multiple JOINs combined with `group: true` can produce cartesian products. If you need aggregates over different tables, prefer declarative subqueries for each.

### 4. Service Columns

Ruby service classes for complex logic that can't be expressed in SQL. Services are evaluated per-record after the query.

```yaml
virtual_columns:
  health_score:
    service: project_health
    type: integer
    options:
      weight_factor: 1.5
```

**Service class** in `app/lcp_services/virtual_columns/project_health.rb`:

```ruby
module LcpRuby
  module HostServices
    module VirtualColumns
      class ProjectHealth
        def self.call(record, options:)
          # Complex business logic
          base = record.tasks_count.to_i
          factor = options[:weight_factor] || 1.0
          (base * factor * completion_ratio(record)).round
        end

        def self.sql_expression(model_class, options:)
          # Optional: return SQL for sorting support
          "(SELECT COUNT(*) FROM tasks WHERE tasks.project_id = #{model_class.table_name}.id)"
        end

        private_class_method def self.completion_ratio(record)
          total = record.tasks.count
          return 0.0 if total.zero?
          record.tasks.where(status: "completed").count.to_f / total
        end
      end
    end
  end
end
```

**Contract:**
- Must implement `self.call(record, options:)` — returns the computed value
- Optionally implement `self.sql_expression(model_class, options:)` — returns a SQL string for sorting support (avoids per-record evaluation)

**`options` hash:** The `options` key passes an arbitrary hash to both `call` and `sql_expression`. Use it for configurable services — e.g., a single service class that computes different scores based on `weight_factor`, `threshold`, etc.

**Service directory:** Services are discovered from `app/lcp_services/virtual_columns/`. For backward compatibility, `app/lcp_services/aggregates/` is also searched as a fallback.

## Auto-Include

Columns with `auto_include: true` are loaded in every query context (index, show, edit) regardless of whether the presenter explicitly references them. This is useful for columns needed by conditional rendering or business logic that applies everywhere.

```yaml
virtual_columns:
  priority_score:
    expression: "(%{table}.urgency * 10 + %{table}.impact * 5)"
    type: integer
    auto_include: true
```

**Restriction:** `auto_include: true` cannot be combined with `group: true` on the same column, because GROUP BY columns alter the query structure and should only be included when explicitly needed.

## Displaying Virtual Columns

### Index Page — Table Columns

```yaml
presenter:
  name: projects
  model: project
  slug: projects
  index:
    table_columns:
      - { field: name, link_to: show }
      - { field: tasks_count, sortable: true }
      - { field: total_value, renderer: currency, sortable: true }
      - { field: is_overdue }
      - { field: company_name }
```

Virtual columns support sorting — the engine orders by the SQL expression or subquery directly.

### Index Page — Tiles

```yaml
index:
  layout: tiles
  tile:
    title_field: name
    fields:
      - { field: tasks_count }
      - { field: total_value, renderer: currency }
```

### Show Page

```yaml
show:
  layout:
    - title: "Overview"
      fields:
        - { field: name }
        - { field: status }
    - title: "Statistics"
      fields:
        - { field: tasks_count }
        - { field: total_value, renderer: currency }
        - { field: company_name }
        - { field: is_overdue }
```

### Explicit Virtual Column Lists

When a virtual column is not referenced in table columns or layout fields but still needed (e.g., only used in `item_classes` or `visible_when`), you can list it explicitly:

```yaml
index:
  table_columns:
    - { field: name, link_to: show }
    - { field: status }
  virtual_columns: [is_overdue, priority_score]

show:
  virtual_columns: [priority_score]
  layout:
    - title: "Details"
      fields:
        - { field: name }
```

In most cases this is not needed — the Collector automatically detects virtual columns from `item_classes`, `visible_when`, action conditions, etc.

### Action-Level and Scope-Level Declarations

When a custom action handler or scope filter reads a virtual column at runtime but doesn't reference it in any YAML condition, declare it on the action or scope:

```yaml
actions:
  single:
    - name: escalate
      type: custom
      virtual_columns: [health_score]   # action handler reads health_score from record

scopes:
  - name: critical
    virtual_columns: [health_score]     # scope filter uses health_score
```

These declarations are merged into the per-presenter superset — `health_score` will be included in every index query for this presenter, not just when the action is executed.

## Conditional Rendering with Virtual Columns

Virtual columns integrate with the [conditional rendering](conditional-rendering.md) system. You can use them in `item_classes`, `visible_when`, `disable_when`, and action visibility.

### Row Styling Based on Virtual Column

```yaml
index:
  table_columns:
    - { field: name, link_to: show }
    - { field: tasks_count }
    - { field: is_overdue }
  item_classes:
    - css_class: "bg-danger-subtle"
      when: { field: is_overdue, operator: eq, value: true }
    - css_class: "text-muted"
      when: { field: tasks_count, operator: eq, value: 0 }
```

The Collector automatically detects that `is_overdue` and `tasks_count` are needed from the `item_classes` conditions.

### Action Visibility

```yaml
actions:
  single:
    - name: send_reminder
      type: custom
      visible_when: { field: is_overdue, operator: eq, value: true }
    - name: close
      type: custom
      visible_when: { field: tasks_count, operator: gt, value: 0 }
```

### Compound Conditions

```yaml
item_classes:
  - css_class: "highlight-urgent"
    when:
      all:
        - { field: is_overdue, operator: eq, value: true }
        - { field: tasks_count, operator: gt, value: 5 }
```

### Form Field Visibility

Virtual columns can control form field visibility on the edit page:

```yaml
form:
  sections:
    - title: "Details"
      fields:
        - field: notes
          visible_when: { field: is_overdue, operator: eq, value: true }
```

## Where Conditions (Declarative Aggregates)

The `where` hash filters the aggregate subquery with equality conditions:

```yaml
virtual_columns:
  active_tasks:
    function: count
    association: tasks
    where: { status: active }

  high_priority_tasks:
    function: count
    association: tasks
    where: { status: active, priority: high }

  my_tasks:
    function: count
    association: tasks
    where: { assignee_id: :current_user }
```

Supported patterns:

```yaml
where: { status: open }                         # WHERE status = 'open'
where: { status: [open, in_progress] }           # WHERE status IN ('open','in_progress')
where: { deleted_at: null }                      # WHERE deleted_at IS NULL
where: { status: active, priority: high }        # WHERE status = 'active' AND priority = 'high'
where: { assignee_id: :current_user }            # WHERE assignee_id = <current_user.id>
```

The `:current_user` placeholder resolves to `current_user.id` at query time. When no user is signed in, it resolves to `nil` (producing `IS NULL`). This enables per-user counts like "my open tasks".

## Soft Delete Awareness

When the target model uses `soft_delete`, **declarative** aggregates automatically exclude soft-deleted records (`WHERE discarded_at IS NULL`). Set `include_discarded: true` to include them:

```yaml
virtual_columns:
  all_tasks_count:
    function: count
    association: tasks
    include_discarded: true

  active_tasks_count:
    function: count
    association: tasks
    # Automatically excludes soft-deleted tasks
```

For **expression** columns with correlated subqueries or JOINs referencing a soft-deletable model, you must handle soft-delete filtering yourself in the SQL:

```yaml
virtual_columns:
  recent_comments_count:
    expression: "(SELECT COUNT(*) FROM comments WHERE comments.order_id = %{table}.id AND comments.discarded_at IS NULL)"
    type: integer
```

## Advanced Patterns

### EXISTS Checks

`EXISTS(...)` is efficient for boolean conditions — it returns TRUE/FALSE (never NULL) and stops scanning after the first match:

```yaml
virtual_columns:
  has_approved_approval:
    expression: "EXISTS(SELECT 1 FROM approvals WHERE approvals.order_id = %{table}.id AND approvals.status = 'approved')"
    type: boolean
```

Use in row styling:

```yaml
item_classes:
  - css_class: "bg-success-subtle"
    when: { field: has_approved_approval, operator: eq, value: true }
```

Since EXISTS never returns NULL, `default:` is not needed — unlike boolean arithmetic expressions.

### Window Functions

Window functions work naturally with the `expression` key:

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

Window functions don't need `join` or `group` — they operate on the result set. They interact with pagination correctly: values are computed over the full result set (after WHERE, before LIMIT/OFFSET), so page 2 shows globally correct ranks, not page-local ones.

**Show page limitation:** On a show page (`WHERE id = 123`), the result set has one row, so `ROW_NUMBER()` always returns 1, `PERCENT_RANK()` always returns 0, etc. Window function values are only meaningful on index pages.

### LATERAL JOINs (PostgreSQL)

PostgreSQL's `LATERAL` keyword enables per-row subqueries — useful for fetching fields from the latest child record:

```yaml
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

The YAML anchor (`&latest_comment_join` / `*latest_comment_join`) avoids duplicating the JOIN string. The builder deduplicates identical JOINs — one JOIN in SQL, multiple SELECT aliases.

**Note:** LATERAL JOINs are PostgreSQL-specific. For DB-portable logic, use service virtual columns with Arel.

### Top-N via JSON Aggregation (PostgreSQL)

Virtual columns are scalar — one value per row. For top-N results, aggregate into a single value:

```yaml
virtual_columns:
  latest_3_comments:
    expression: >-
      (SELECT json_agg(sub ORDER BY sub.created_at DESC)
       FROM (SELECT c.body, c.author_name, c.created_at
             FROM comments c
             WHERE c.order_id = %{table}.id
             ORDER BY c.created_at DESC LIMIT 3) sub)
    type: json
```

Result: `[{"body": "Great!", "author_name": "Alice", "created_at": "2026-03-05"}, ...]` — one JSON array per row, renderable with a custom renderer.

### Complex Correlated Subqueries

Correlated subqueries with internal JOINs don't need a top-level `join:` — the JOIN is inside the subquery:

```yaml
virtual_columns:
  weighted_approval_score:
    expression: >-
      (SELECT COALESCE(SUM(a.weight * al.priority), 0)
       FROM approvals a
       JOIN approval_levels al ON al.id = a.level_id
       WHERE a.order_id = %{table}.id)
    type: float
```

### Service with Arel (DB Portability)

For DB-portable virtual columns, use a service with Arel to generate SQL that works across PostgreSQL and SQLite:

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
  # Per-record evaluation (show pages)
  def self.call(record, options: {})
    record.due_date.present? && record.due_date < Date.current && record.status != "done"
  end

  # SQL expression for index queries (DB-portable via Arel)
  def self.sql_expression(model_class, options: {})
    t = model_class.arel_table
    condition = t[:due_date].lt(Arel::Nodes.build_quoted(Date.current))
      .and(t[:status].not_eq(Arel::Nodes.build_quoted("done")))
    Arel::Nodes::Case.new.when(condition).then(true).else(false).to_sql
  end
end
```

Services with both `call` and `sql_expression` get the best of both worlds: `call` for show pages (no SQL overhead for a single record), `sql_expression` for index pages (batch SQL, sortable).

### NULL Safety for Boolean Expressions

SQL boolean expressions return NULL (not FALSE) when any operand is NULL. For example, `due_date < CURRENT_DATE AND status != 'done'` returns NULL when `due_date` is NULL. After type coercion, `nil` ≠ `false`, so conditions like `{ operator: eq, value: false }` won't match.

**Fix:** Use `default: false` on boolean virtual columns with comparisons:

```yaml
virtual_columns:
  is_overdue:
    expression: "(%{table}.due_date < CURRENT_DATE AND %{table}.status != 'done')"
    type: boolean
    default: false   # COALESCE wraps the expression
```

**Exception:** `EXISTS(...)` always returns TRUE/FALSE, never NULL — no `default:` needed.

## Permissions

Virtual columns are visible to all roles regardless of field permissions — they are computed values, not stored data. There is no way to restrict a virtual column to specific roles in the permissions YAML.

## Virtual Columns vs. Computed Fields

Both produce derived values, but they serve different purposes:

| | Virtual Columns | Computed Fields |
|---|---|---|
| **Storage** | Not stored (SQL at query time) | Persisted in DB column |
| **Recalculation** | On every query | On every save |
| **Source** | Associated records, JOINs, SQL expressions | Fields on the same record (or associations via service) |
| **Sortable** | Yes (ORDER BY SQL alias) | Yes (real column, Ransack-compatible) |
| **Filterable (Ransack)** | No (SQL alias, not a real column) | Yes (real column) |
| **Editable** | Never | Never (readonly in forms) |
| **Use case** | `tasks_count` from children, `is_overdue` flag, `company_name` via JOIN | `total = price * quantity`, `full_name = first + last` |

**Rule of thumb:** If the value depends on fields of the **same record** and should be persisted, use a [computed field](computed-fields.md). If it summarizes data from **associated records**, derives from SQL expressions, or should always reflect the current state without saving, use a virtual column.

## Limitations

- **Not filterable via Ransack** — Virtual columns are SQL aliases, not real columns. They cannot be used in the advanced filter builder, saved filters, or Ransack WHERE clauses. To filter by a virtual column value, use a custom scope (`type: custom`).
- **Not in summary bar / column summaries** — Summary statistics operate on real database columns only. Virtual column names are silently skipped.
- **Permission scopes cannot reference virtual columns** — Permission scope types `where` and `field_match` use `.where()` which requires real columns. Virtual column names in WHERE would cause "column does not exist" errors. Use `type: custom` with a named scope that embeds the SQL expression.
- **Read-only in forms** — Virtual columns are always read-only. If referenced in a form layout, they render as read-only display fields. The controller never includes virtual column names in `permitted_params`.
- **DB portability** — `expression:` and `join:` strings are used as-is. The platform does not abstract PostgreSQL vs SQLite differences. For DB-portable logic, use service virtual columns with Arel (see [Service with Arel](#service-with-arel-db-portability) above).
- **`auto_include` scope** — `auto_include: true` only affects controller queries. Direct `Model.find`, `Model.where` calls from custom actions, event handlers, or other Ruby code do not include virtual columns — use `VirtualColumns::Builder.apply` explicitly.

## Backward Compatibility

The `aggregates` YAML key continues to work. Both keys are merged at parse time:

```yaml
# This still works exactly as before
aggregates:
  tasks_count:
    function: count
    association: tasks

# New virtual columns can be added alongside
virtual_columns:
  is_overdue:
    expression: "CASE WHEN %{table}.due_date < CURRENT_DATE THEN 1 ELSE 0 END"
    type: boolean
```

The legacy `sql` key is accepted as an alias for `expression`:

```yaml
# Legacy syntax — still works
aggregates:
  weighted_score:
    sql: "SELECT SUM(r.score * r.weight) / NULLIF(SUM(r.weight), 0) FROM ratings r WHERE r.project_id = %{table}.id"
    type: float

# Equivalent new syntax
virtual_columns:
  weighted_score:
    expression: "SELECT SUM(r.score * r.weight) / NULLIF(SUM(r.weight), 0) FROM ratings r WHERE r.project_id = %{table}.id"
    type: float
```

The DSL `aggregate` method is an alias for `virtual_column`:

```ruby
# These are equivalent
aggregate :tasks_count, function: :count, association: :tasks
virtual_column :tasks_count, function: :count, association: :tasks
```

## Complete Example

### Model

```yaml
# config/lcp_ruby/models/order.yml
model:
  name: order
  fields:
    - { name: title, type: string }
    - { name: status, type: string }
    - { name: due_date, type: date }
  associations:
    - { type: has_many, name: line_items, target_model: line_item, foreign_key: order_id }
    - { type: belongs_to, name: company, target_model: company, foreign_key: company_id, required: false }
  virtual_columns:
    items_count:
      function: count
      association: line_items
    total_value:
      expression: "COALESCE(SUM(line_items.quantity * line_items.unit_price), 0)"
      join: "LEFT JOIN line_items ON line_items.order_id = %{table}.id"
      group: true
      type: decimal
    is_overdue:
      expression: "CASE WHEN %{table}.due_date < CURRENT_DATE AND %{table}.status != 'completed' THEN 1 ELSE 0 END"
      type: boolean
    company_name:
      expression: "companies.name"
      join: "LEFT JOIN companies ON companies.id = %{table}.company_id"
      type: string
  options:
    timestamps: true
```

### Presenter

```yaml
# config/lcp_ruby/presenters/orders.yml
presenter:
  name: orders
  model: order
  slug: orders
  label: "Orders"

  index:
    default_sort: { field: created_at, direction: desc }
    table_columns:
      - { field: title, link_to: show, sortable: true }
      - { field: status, sortable: true }
      - { field: company_name, sortable: true }
      - { field: items_count, sortable: true }
      - { field: total_value, renderer: currency, sortable: true }
      - { field: is_overdue }
    item_classes:
      - css_class: "bg-danger-subtle"
        when: { field: is_overdue, operator: eq, value: true }

  show:
    layout:
      - title: "Order Details"
        fields:
          - { field: title }
          - { field: status }
          - { field: due_date }
          - { field: company_name }
      - title: "Statistics"
        fields:
          - { field: items_count }
          - { field: total_value, renderer: currency }
          - { field: is_overdue }

  form:
    sections:
      - title: "Order"
        fields:
          - { field: title, autofocus: true }
          - { field: status }
          - { field: due_date }
          - { field: company_id, input_type: association_select }

  actions:
    single:
      - { name: show, type: built_in }
      - { name: edit, type: built_in }
      - { name: destroy, type: built_in, confirm: true, style: danger }
    collection:
      - { name: create, type: built_in }
```

### DSL Equivalent

```ruby
define_model :order do
  label "Order"
  label_plural "Orders"

  field :title, :string, null: false
  field :status, :string
  field :due_date, :date

  has_many :line_items, model: :line_item, foreign_key: :order_id
  belongs_to :company, model: :company, foreign_key: :company_id, required: false

  virtual_column :items_count, function: :count, association: :line_items
  virtual_column :total_value,
    expression: "COALESCE(SUM(line_items.quantity * line_items.unit_price), 0)",
    join: "LEFT JOIN line_items ON line_items.order_id = %{table}.id",
    group: true,
    type: :decimal
  virtual_column :is_overdue,
    expression: "CASE WHEN %{table}.due_date < CURRENT_DATE AND %{table}.status != 'completed' THEN 1 ELSE 0 END",
    type: :boolean
  virtual_column :company_name,
    expression: "companies.name",
    join: "LEFT JOIN companies ON companies.id = %{table}.company_id",
    type: :string

  timestamps true
end
```

## Reference

- [Models Reference — Virtual Columns](../reference/models.md#virtual-columns) — Complete attribute reference
- [Computed Fields Guide](computed-fields.md) — Persisted calculated fields (different concept)
- [Conditional Rendering Guide](conditional-rendering.md) — Using VCs in `visible_when`, `item_classes`
- [Extensibility Guide](extensibility.md) — Service registration and discovery
- Source: `lib/lcp_ruby/virtual_columns/builder.rb`, `lib/lcp_ruby/virtual_columns/collector.rb`
