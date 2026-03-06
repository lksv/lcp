# Feature Specification: Cached Aggregates

**Status:** Proposed
**Date:** 2026-03-06

## Problem / Motivation

The platform supports [virtual aggregates](aggregate_columns.md) — COUNT, SUM, MIN, MAX, AVG computed as SQL subqueries at query time. This works well for moderate data volumes, but read-heavy applications with large child tables pay the subquery cost on every page load.

A common example: an **Employee** model with thousands of **TimeEntry** records. Showing `total_hours` (SUM) and `entries_count` (COUNT) on the employee index requires a correlated subquery per aggregate per page load. When the table has thousands of employees and millions of time entries, these subqueries become the dominant query cost — even with proper indexes.

Rails solves the COUNT case natively with `counter_cache`, which maintains a denormalized integer column on the parent and updates it incrementally (+1/-1) on child create/destroy. But there is no built-in equivalent for SUM, MIN, MAX, or AVG.

The platform currently offers no way to declare a persisted, automatically-maintained aggregate column. Users must either:
- Accept the subquery cost (virtual aggregates)
- Manually wire event handlers to keep a computed field in sync (fragile, error-prone)
- Use `counter_culture` gem outside the platform (breaks the declarative model)

## User Scenarios

**As a platform user building a time-tracking system,** I want to declare `total_hours` on the `employee` model as a cached SUM of `time_entries.hours`, so that the employee index page reads a plain column instead of computing a subquery — and the value stays correct whenever time entries are created, updated, or deleted.

**As a platform user building a project tracker,** I want `open_issues_count` on the `project` model to be a cached COUNT with a `where: { status: open }` condition, so that filtering and sorting by open issue count is instantaneous.

**As a platform user building an e-shop,** I want `total_revenue` on the `customer` model to be a cached SUM of `orders.amount` where `status: completed`, and whenever an order is completed, cancelled, or has its amount changed, the customer's total updates automatically.

**As a platform user,** I want the cached value to be fully consistent — after any child record change (create, update, destroy, soft-delete, restore), the parent's cached column reflects the correct aggregate without manual intervention.

## Configuration & Behavior

### YAML Syntax

Cached aggregates extend the existing `aggregates` block with a `cache: true` option:

```yaml
# config/lcp_ruby/models/employee.yml
model:
  name: employee
  fields:
    - { name: name, type: string }
  associations:
    - { name: time_entries, type: has_many, model: time_entry }
  aggregates:
    total_hours:
      function: sum
      association: time_entries
      source_field: hours
      default: 0
      cache: true

    entries_count:
      function: count
      association: time_entries
      cache: true
```

### DSL Syntax

```ruby
define_model :employee do
  field :name, :string
  has_many :time_entries, model: :time_entry

  aggregate :total_hours, function: :sum, association: :time_entries,
            source_field: :hours, default: 0, cache: true

  aggregate :entries_count, function: :count, association: :time_entries,
            cache: true
end
```

### What `cache: true` Does

1. **Creates a real DB column** on the parent table (e.g., `total_hours` decimal, `entries_count` integer) via `SchemaManager` — same as a regular field.
2. **Installs callbacks on the child model** (`after_create`, `after_update`, `after_destroy`) that update the parent's cached column.
3. **On index pages**, reads the column directly — no subquery injected. The aggregate behaves like a regular persisted field.
4. **On show pages**, same — reads the column value.
5. The aggregate remains sortable, filterable (via Ransack — it's a real column), and usable in conditions (`visible_when`, `record_rules`).

### Supported Functions

| Function | Cache strategy | Column type |
|----------|---------------|-------------|
| `count` | Increment/decrement (+1/-1) on create/destroy. On update: adjust if `where` conditions change (record enters/leaves the filtered set). | `integer` |
| `sum` | On create: add value. On destroy: subtract value. On update: add difference (new - old). Adjust for `where` condition changes. | Same as `source_field` |
| `min` / `max` | Full recalculation on any child change (incremental min/max is unsafe — deleting the current min requires finding the new one). | Same as `source_field` |
| `avg` | Full recalculation (or store count + sum and derive). | `float` or `decimal` |

### `counter_cache` Shorthand for belongs_to

For the simple COUNT case, the platform also supports Rails' native `counter_cache` on the `belongs_to` side:

```yaml
# config/lcp_ruby/models/time_entry.yml
model:
  name: time_entry
  fields:
    - { name: hours, type: decimal }
  associations:
    - name: employee
      type: belongs_to
      model: employee
      counter_cache: true           # column: time_entries_count on employees
```

This is syntactic sugar — equivalent to defining `aggregate :time_entries_count, function: :count, association: :time_entries, cache: true` on the parent. It delegates directly to Rails' built-in `counter_cache` mechanism.

Custom column name:

```yaml
associations:
  - name: employee
    type: belongs_to
    model: employee
    counter_cache: entries_count    # custom column name
```

### Conditional Cached Aggregates

When `where` conditions are present, the callbacks must detect whether a child record enters or leaves the filtered set:

```yaml
aggregates:
  open_issues_count:
    function: count
    association: issues
    where: { status: open }
    cache: true
```

On `issue` update:
- If `status` changed from `open` to `closed` → decrement parent's `open_issues_count`
- If `status` changed from `closed` to `open` → increment parent's `open_issues_count`
- If `status` didn't change → no update (for count), or adjust value (for sum)

The callback inspects `saved_changes` to determine what changed.

### Interaction with Soft Delete

When the child model uses `soft_delete` and the aggregate has `include_discarded: false` (default):
- `discard!` → treated as a "destroy" for cache purposes (decrement/subtract)
- `undiscard!` → treated as a "create" for cache purposes (increment/add)

This integrates with the existing `SoftDeleteApplicator` callbacks.

### Recalculation

A rake task and model method allow full recalculation for data repair:

```bash
# Recalculate all cached aggregates for a model
bundle exec rake lcp_ruby:recalculate_caches[employee]

# Recalculate a specific aggregate
bundle exec rake lcp_ruby:recalculate_caches[employee,total_hours]
```

```ruby
# Programmatic recalculation
LcpRuby::CachedAggregates::Recalculator.call(:employee)
LcpRuby::CachedAggregates::Recalculator.call(:employee, :total_hours)
```

This is essential for:
- Initial deployment (populating the column for existing data)
- Data migrations or bulk imports that bypass callbacks
- Recovery from bugs or inconsistencies

### Validation Rules

`ConfigurationValidator` enforces:
- `cache: true` is only valid on **declarative** aggregates (`function` + `association`). Not on `sql:` or `service:` types.
- The `association` must be a `has_many` (not `belongs_to` or `has_one`).
- `where` conditions with `:current_user` placeholder are **not compatible** with `cache: true` (cached value is shared across all users).
- The aggregate name must not collide with an existing field name (same as virtual aggregates).

## Usage Examples

### Time Tracking: Employee with Cached Hours Sum

```yaml
# models/employee.yml
model:
  name: employee
  fields:
    - { name: name, type: string }
  associations:
    - { name: time_entries, type: has_many, model: time_entry }
  aggregates:
    total_hours:
      function: sum
      association: time_entries
      source_field: hours
      default: 0
      cache: true

# models/time_entry.yml
model:
  name: time_entry
  fields:
    - { name: hours, type: decimal }
    - { name: description, type: string }
  associations:
    - { name: employee, type: belongs_to, model: employee }

# presenters/employees.yml
presenter:
  name: employees
  model: employee
  slug: employees
  index:
    columns:
      - { field: name, link_to: show, sortable: true }
      - { field: total_hours, sortable: true }    # reads column directly, no subquery
```

### Project Tracker: Conditional Cached Count

```yaml
# models/project.yml
model:
  name: project
  fields:
    - { name: name, type: string }
  associations:
    - { name: issues, type: has_many, model: issue }
  aggregates:
    issues_count:
      function: count
      association: issues
      cache: true
    open_issues_count:
      function: count
      association: issues
      where: { status: open }
      cache: true
```

### Simple Counter Cache via belongs_to

```yaml
# models/comment.yml
model:
  name: comment
  fields:
    - { name: body, type: text }
  associations:
    - name: post
      type: belongs_to
      model: post
      counter_cache: true    # creates comments_count on posts table
```

## General Implementation Approach

### Column Creation

When `SchemaManager` processes aggregates with `cache: true`, it creates a real DB column on the parent table — same mechanism as regular fields. The column type is inferred from the aggregate function and source field (integer for count, decimal/float for sum, etc.). The column has a `NOT NULL` constraint with default 0 (for count/sum) or NULL (for min/max/avg).

### Callback Installation

A new `CachedAggregateApplicator` runs during the `ModelFactory::Builder` pipeline. For each cached aggregate on a parent model, it installs `after_create`, `after_update`, and `after_destroy` callbacks on the **child** model. This means the applicator must run after all models are built (two-pass: first build all models, then wire cross-model callbacks).

**Count callbacks** use atomic SQL updates for safety under concurrency:
```sql
UPDATE employees SET entries_count = entries_count + 1 WHERE id = ?
UPDATE employees SET entries_count = entries_count - 1 WHERE id = ?
```

**Sum callbacks** similarly use atomic updates:
```sql
UPDATE employees SET total_hours = total_hours + ? WHERE id = ?
UPDATE employees SET total_hours = total_hours - ? WHERE id = ?
```

**Min/Max/Avg callbacks** trigger a full recalculation query:
```sql
UPDATE employees SET oldest_entry = (SELECT MIN(date) FROM time_entries WHERE employee_id = ?) WHERE id = ?
```

### Foreign Key Reassignment

When a child record changes its parent (e.g., `time_entry.employee_id` changes from 5 to 8), the callback must update **both** the old and new parent:
- Old parent: decrement/subtract
- New parent: increment/add

The callback checks `saved_changes` for FK column changes.

### Conditional Aggregates (where)

For aggregates with `where` conditions, the callback evaluates whether the record matches the condition **before** and **after** the change (using `saved_changes`). Four transitions are possible:

| Before matched? | After matched? | Action |
|----------------|---------------|--------|
| No | No | No-op |
| No | Yes | Treat as "create" (increment/add) |
| Yes | No | Treat as "destroy" (decrement/subtract) |
| Yes | Yes | Update value (for sum: adjust by difference) |

### Two-Pass Build

Since cached aggregate callbacks on the child model reference the parent model, both models must exist before callbacks are installed. The builder pipeline adds a second pass:

1. **Pass 1 (existing):** Build all models (schema, fields, validations, associations, scopes, etc.)
2. **Pass 2 (new):** `CachedAggregateApplicator` iterates all models with cached aggregates and installs callbacks on the resolved child model classes.

### counter_cache on belongs_to

The `AssociationApplicator` is extended to pass the `counter_cache` option to Rails' `belongs_to` macro. Rails handles the rest natively — no custom callbacks needed for simple count caching via this path.

`SchemaManager` creates the corresponding column on the parent table (e.g., `comments_count integer NOT NULL DEFAULT 0`).

### Query Behavior Change

When a cached aggregate is referenced in a presenter column:
- `AggregateQueryBuilder` detects `cache: true` and **skips** subquery injection — the value is already in the table.
- The field behaves like a regular column: sortable via `ORDER BY`, filterable via Ransack, usable in conditions.

### Auditing Integration

Changes to cached aggregate columns are **excluded** from audit logs by default — they are derived values, not user actions. The `AuditWriter` skips fields marked as cached aggregates.

## Decisions

1. **`cache: true` on existing aggregate syntax.** This keeps the configuration surface minimal — one boolean flag upgrades a virtual aggregate to a cached one. The aggregate definition (function, association, where, etc.) stays identical.

2. **Declarative aggregates only.** `sql:` and `service:` aggregates cannot be cached because the platform cannot derive inverse callbacks from arbitrary SQL or Ruby code. The escape hatch remains: use event handlers + computed fields for complex cached calculations.

3. **Atomic SQL updates for count/sum.** Using `UPDATE ... SET col = col + ?` instead of `record.reload; record.update_column` avoids race conditions under concurrent writes without requiring advisory locks.

4. **Full recalculation for min/max/avg.** Incremental maintenance of min/max is unsafe (deleting the current min requires a full scan to find the new one). Avg requires maintaining sum + count or a full recalc. Given that these are less common than count/sum, full recalc is acceptable.

5. **Two-pass build.** Cross-model callbacks require both models to exist. A second pass after all models are built is the simplest correct approach.

6. **`:current_user` incompatible with cache.** A cached column stores a single value shared by all users. Per-user aggregates (`:current_user` in `where`) must remain virtual.

7. **Recalculation tooling included.** Cached values can drift (bulk imports, bugs, direct DB edits). A rake task and programmatic API for full recalculation are essential from day one.

## Open Questions

1. **Concurrency under high write load.** Atomic `col = col + 1` works for most cases, but under extreme concurrent writes to the same parent, row-level lock contention on the parent could become a bottleneck. Should the platform support deferred/async cache updates (e.g., via background job) as an option? For now, synchronous atomic updates are likely sufficient.

2. **Bulk operations.** `BulkUpdater.tracked_update_all` bypasses AR callbacks. Should it trigger cached aggregate recalculation? Options:
   - Automatic: `BulkUpdater` detects affected parent IDs and recalculates after bulk update.
   - Manual: User calls recalculation rake task after bulk operations.
   - Hook: `BulkUpdater`'s yield callback could notify `CachedAggregateApplicator`.

3. **Initial population strategy.** When `cache: true` is added to an existing aggregate on a model with data, the column defaults to 0/NULL. Should `SchemaManager` automatically trigger recalculation on migration, or is the rake task sufficient?

4. **Should `counter_cache` on belongs_to and `cache: true` on aggregate be unified internally?** Rails' `counter_cache` is battle-tested for simple counts. The platform could use it under the hood for `count` + `cache: true` (no `where` conditions) and only use custom callbacks for sum/min/max/avg and conditional counts. This reduces the surface area of custom code.

5. **Transaction safety.** Should cached aggregate updates happen inside the same transaction as the child record save? Rails' `counter_cache` uses `after_create`/`after_destroy` which run inside the transaction. Custom callbacks should follow the same pattern. But if the parent update fails, should the child save also roll back?
