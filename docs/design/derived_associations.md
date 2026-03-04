# Feature Specification: Derived Associations

**Status:** Proposed (v2 — after Aggregate Columns)
**Date:** 2026-03-04
**Depends on:** [Aggregate Columns](aggregate_columns.md)

## Problem / Motivation

Aggregate columns (see [aggregate_columns.md](aggregate_columns.md)) solve the problem of showing scalar derived values — counts, sums, averages — on index and show pages. But there is a closely related and equally common need: **showing data from a specific related record** selected from a `has_many` association.

Consider a project tracker. On the project index page, you want to show:

| Project | Status | Last comment date | Last comment author |
|---------|--------|-------------------|---------------------|
| Alpha   | active | 2 hours ago       | Jan Novák           |
| Beta    | active | 3 days ago        | Eva Malá            |

The "last comment date" and "last comment author" both come from **the same record** — the most recent comment for each project. With aggregate columns, you could define two independent aggregates:

```yaml
aggregates:
  last_comment_at:
    function: max
    association: comments
    source_field: created_at
  last_comment_author:
    sql: "SELECT u.name FROM comments c JOIN users u ON u.id = c.user_id WHERE c.project_id = %{table}.id ORDER BY c.created_at DESC LIMIT 1"
    type: string
```

This works, but has significant drawbacks:

1. **No consistency guarantee across databases.** The `MAX(created_at)` subquery and the `ORDER BY ... LIMIT 1` subquery are independent. If a comment is inserted between the two evaluations, they could return data from different records. (In PostgreSQL, a single `SELECT` statement sees a consistent snapshot, so this is not an issue. But other databases — notably MySQL with certain isolation levels — may not guarantee this.)

2. **Verbose and repetitive.** Each column from the same related record requires its own `sql:` aggregate with a nearly identical subquery. Showing three columns means three copy-pasted subqueries.

3. **No semantic connection.** The platform has no way to know that `last_comment_at` and `last_comment_author` refer to the same record. This prevents optimization (a single subquery/join instead of N), and it makes the configuration harder to read and maintain.

4. **Cannot use dot-path traversal.** Aggregates return scalar values. You cannot write `last_comment.author.name` — the dot-path resolution that works for `belongs_to` associations does not apply to aggregate results.

What is needed is a way to say: *"From this `has_many`, pick one record according to criteria, and make it accessible like a `belongs_to`."*

## User Scenarios

**As a platform user configuring a project tracker,** I want to show the most recent comment's date and author on the project index page, so that I can see recent activity at a glance without clicking into each project.

**As a platform user building a CRM,** I want to show the latest activity (date, type, and description) on the company index, so that sales reps can quickly identify which companies need attention.

**As a platform user building a helpdesk,** I want to show the last response on the ticket index — who responded, when, and whether it was a customer or agent reply — so that the support team can prioritize follow-ups.

**As a platform user building an HR system,** I want to show the current (most recent) contract's start date and position on the employee index, so that HR staff can see employment details without opening each record.

**As a platform user,** I want derived associations to respect soft delete — if the latest comment was deleted, it should pick the next one.

## Configuration & Behavior

### Model YAML — new top-level `derived_associations` key

Derived associations are defined on the model alongside `fields`, `associations`, and `aggregates`. Each derived association has a unique name and becomes accessible via dot-path in presenters — just like a `belongs_to` association.

```yaml
# config/lcp_ruby/models/project.yml
name: project
fields:
  - { name: name, type: string }
  - { name: status, type: enum, values: [active, archived] }

associations:
  - { type: has_many, name: comments, target_model: comment }
  - { type: has_many, name: orders, target_model: order }
  - { type: has_many, name: contracts, target_model: contract }

derived_associations:
  latest_comment:
    association: comments
    order_by: created_at
    direction: desc

  top_order:
    association: orders
    where: { status: completed }
    order_by: amount
    direction: desc

  current_contract:
    association: contracts
    where: { active: true }
    order_by: start_date
    direction: desc
```

### Derived association definition schema

```yaml
derived_associations:
  <name>:                              # unique name, becomes a virtual association
    association: <has_many name>       # required — existing has_many on this model
    order_by: <field on target model>  # required — which field determines selection
    direction: asc | desc             # optional, default: desc
    where: { field: value, ... }      # optional — equality conditions on target model
    include_discarded: false           # optional, default: false
```

The `where` clause uses the same syntax as aggregate `where` — simple hash equality conditions:

```yaml
where: { status: open }                      # WHERE status = 'open'
where: { status: [open, in_progress] }       # WHERE status IN ('open', 'in_progress')
where: { deleted_at: null }                  # WHERE deleted_at IS NULL
where: { status: active, priority: high }    # WHERE status = 'active' AND priority = 'high'
```

### Model DSL

```ruby
define_model :project do
  field :name, :string
  field :status, :enum, values: %w[active archived]

  has_many :comments, model: :comment
  has_many :orders, model: :order

  derived_association :latest_comment,
                      association: :comments,
                      order_by: :created_at,
                      direction: :desc

  derived_association :top_order,
                      association: :orders,
                      where: { status: "completed" },
                      order_by: :amount,
                      direction: :desc
end
```

### Presenter YAML — dot-path like any association

The presenter references derived association fields using dot-path notation — the same syntax used for `belongs_to` traversal:

```yaml
# config/lcp_ruby/presenters/projects.yml
name: projects
model: project
slug: projects

index:
  table_columns:
    - { field: name, width: "25%", link_to: show, sortable: true }
    - { field: status, renderer: badge, sortable: true }
    - { field: latest_comment.created_at, renderer: relative_date, sortable: true }
    - { field: latest_comment.author_name }
    - { field: top_order.amount, renderer: currency, options: { currency: "EUR" } }

show:
  layout:
    - type: details
      title: Overview
      fields:
        - { field: name }
        - { field: status, renderer: badge }
    - type: details
      title: Latest Activity
      fields:
        - { field: latest_comment.created_at, renderer: relative_date }
        - { field: latest_comment.body, renderer: text }
        - { field: latest_comment.author_name }
```

Renderers, labels, options, `link_to`, width — all work exactly as with regular fields and association dot-paths. This is the key advantage: **the presenter does not need to know whether a dot-path traverses a real association or a derived one.**

## Usage Examples

### Example 1: CRM — latest activity on company index

A CRM shows companies with their most recent activity to help sales reps prioritize outreach.

```yaml
# models/company.yml
associations:
  - { type: has_many, name: activities, target_model: activity }

derived_associations:
  latest_activity:
    association: activities
    order_by: created_at
    direction: desc

# presenters/companies.yml
index:
  table_columns:
    - { field: name, link_to: show, sortable: true }
    - { field: industry, renderer: badge }
    - { field: latest_activity.created_at, renderer: relative_date, sortable: true }
    - { field: latest_activity.activity_type, renderer: badge }
```

The sales rep sees:

| Company     | Industry   | Last activity | Type        |
|-------------|------------|---------------|-------------|
| Acme Corp   | Technology | 2 hours ago   | phone call  |
| Beta Inc    | Finance    | 5 days ago    | email       |
| Gamma Ltd   | Retail     | 3 weeks ago   | meeting     |

Sorting by "Last activity" lets the rep find companies that have not been contacted recently.

### Example 2: HR — current contract on employee index

An HR system shows each employee's current contract details.

```yaml
# models/employee.yml
associations:
  - { type: has_many, name: contracts, target_model: contract }

derived_associations:
  current_contract:
    association: contracts
    where: { active: true }
    order_by: start_date
    direction: desc

# presenters/employees.yml
index:
  table_columns:
    - { field: full_name, link_to: show, sortable: true }
    - { field: department, sortable: true }
    - { field: current_contract.position }
    - { field: current_contract.start_date, renderer: date }
    - { field: current_contract.salary, renderer: currency }
```

### Example 3: Helpdesk — last response on ticket index

A helpdesk shows the most recent response on each ticket, distinguishing customer and agent replies.

```yaml
# models/ticket.yml
associations:
  - { type: has_many, name: responses, target_model: ticket_response }

derived_associations:
  last_response:
    association: responses
    order_by: created_at
    direction: desc

  last_agent_response:
    association: responses
    where: { response_type: agent }
    order_by: created_at
    direction: desc

# presenters/tickets.yml
index:
  table_columns:
    - { field: subject, link_to: show, sortable: true }
    - { field: status, renderer: badge }
    - { field: last_response.created_at, renderer: relative_date, sortable: true }
    - { field: last_response.response_type, renderer: badge }
    - { field: last_agent_response.created_at, renderer: relative_date }
```

The support team sees when each ticket was last responded to and whether the last response was from a customer (needs agent attention) or an agent (waiting for customer).

### Example 4: Inventory — highest-value item per warehouse

```yaml
# models/warehouse.yml
associations:
  - { type: has_many, name: items, target_model: inventory_item }

derived_associations:
  most_valuable_item:
    association: items
    order_by: unit_price
    direction: desc

# presenters/warehouses.yml
index:
  table_columns:
    - { field: name, link_to: show }
    - { field: location }
    - { field: most_valuable_item.product_name }
    - { field: most_valuable_item.unit_price, renderer: currency }
```

### Example 5: Combined with aggregates

Derived associations and aggregates complement each other. One project index might use both:

```yaml
# models/project.yml
aggregates:
  issues_count:
    function: count
    association: issues
  open_issues_count:
    function: count
    association: issues
    where: { status: open }

derived_associations:
  latest_comment:
    association: comments
    order_by: created_at
    direction: desc

# presenters/projects.yml
index:
  table_columns:
    - { field: name, link_to: show, sortable: true }
    - { field: issues_count, sortable: true }
    - { field: open_issues_count, sortable: true }
    - { field: latest_comment.created_at, renderer: relative_date, sortable: true }
    - { field: latest_comment.author_name }
```

This gives a single index page that shows both scalar aggregates (counts) and related record data (latest comment) — all from YAML configuration, no Ruby code.

## Design Discussion

### Why not extend aggregates?

One approach would be to add a `function: pick` or `function: first` to the existing aggregates system. This was considered and rejected:

| Concern | Aggregates | Derived associations |
|---------|-----------|---------------------|
| Return value | Scalar (integer, float, date...) | Record (accessible via dot-path) |
| Presenter usage | `{ field: issues_count }` | `{ field: latest_comment.created_at }` |
| Number of SQL subqueries | 1 per aggregate | 1 per referenced dot-path column |
| Mental model | "Compute a number" | "Pick a related record" |

Forcing a record-selection concept into the aggregate system would require special-casing throughout the codebase: the presenter would need to detect which "aggregates" support dot-paths, `FieldValueResolver` would need separate logic, and the YAML configuration would be confusing — `function: pick` looks like it returns a value, but actually returns a record.

The concepts are different enough to warrant separate top-level keys.

### Why not a special association type?

Another approach: define derived associations as a new association type (`has_one_derived`) within the existing `associations` list:

```yaml
associations:
  - { type: has_many, name: comments, target_model: comment }
  - { type: has_one_derived, name: latest_comment, from: comments, order_by: created_at }
```

This has appeal — the result behaves like an association, so placing it among associations seems natural.

However:

1. **Associations imply writability.** An `association_select` input, FK assignment, nested attributes — these are association behaviors that don't apply to derived associations. A derived association is strictly read-only.

2. **Mixed list complexity.** The `associations` list would contain both real DB-backed associations and virtual computed ones. Validation, schema management, and association applicator logic would need to distinguish between them.

3. **Separate YAML key is more explicit.** When a configurator reads the YAML, `derived_associations` immediately signals "these are computed, read-only, virtual" — no ambiguity.

### Scope interaction: what SQL filtering applies automatically?

Derived associations are implemented as raw SQL subqueries, not ActiveRecord queries. This means Rails default scopes do **not** automatically apply. The question is what to replicate explicitly.

**Soft delete** — automatically applied, like aggregates:

When the target model uses `soft_delete: true`, the subquery automatically adds `AND target_table.discarded_at IS NULL`. Override with `include_discarded: true`. This is consistent with aggregate columns and matches user expectations — deleted records should not appear.

**Other default scopes** — deliberately ignored:

Three approaches were considered:

**A) Ignore all default scopes (only handle soft delete explicitly)**

- Consistent with aggregates — same SQL subquery strategy, same rules
- Predictable — the configurator sees in YAML exactly what is filtered
- Simple — raw SQL does not need to interact with AR scope mechanism
- Risk: if a model has `default_scope { where(active: true) }`, the derived association ignores it — may return inactive records
- Mitigation: the configurator adds `where: { active: true }` explicitly

**B) Apply default scopes from target model**

- Consistent with how Rails associations work natively
- "Just works" without duplicating logic
- But: fragile — custom default scopes can contain JOINs, subqueries, or Ruby logic that cannot be converted to raw SQL
- Inconsistent with aggregates (which do not apply default scopes)
- Hidden behavior — configurator cannot see from YAML that a filter is applied

**C) Explicit `scope:` parameter referencing a named scope**

```yaml
derived_associations:
  latest_active_comment:
    association: comments
    scope: active
    order_by: created_at
```

- Explicit — visible in YAML
- Flexible — reuses existing named scopes
- But: same fragility as B — named scopes can contain non-portable SQL or Ruby logic
- Added configuration complexity

**Decision: approach A.** Ignore default scopes, handle only soft delete explicitly. The `where:` clause provides explicit, visible filtering. This is consistent with aggregates and keeps the SQL generation simple and predictable. Approach C is a reasonable future extension if the need arises.

### Sorting

Derived association dot-paths that resolve to SQL subqueries can be sortable. When the presenter has `sortable: true` on `latest_comment.created_at`, the engine sorts by the corresponding subquery alias — the same mechanism used for aggregate sorting.

### Permissions

Derived associations are read-only derived values, like aggregates. They are visible to any role that can see the presenter. No field-level `readable`/`writable` permission checks apply.

## General Implementation Approach

### SQL strategy: correlated subqueries per referenced column

Each dot-path column from a derived association becomes an independent correlated subquery in the SELECT clause:

```sql
-- Presenter references: latest_comment.created_at, latest_comment.author_name
SELECT projects.*,
  (SELECT c.created_at FROM comments c
   WHERE c.project_id = projects.id
   ORDER BY c.created_at DESC LIMIT 1) AS "latest_comment.created_at",
  (SELECT c.author_name FROM comments c
   WHERE c.project_id = projects.id
   ORDER BY c.created_at DESC LIMIT 1) AS "latest_comment.author_name"
FROM projects
ORDER BY "latest_comment.created_at" DESC
LIMIT 25 OFFSET 0
```

**Why correlated subqueries (not LATERAL JOIN):**

- Portable across all databases (SQLite, PostgreSQL, MySQL)
- Consistent with the aggregate columns SQL strategy
- Simple to generate — same subquery template, different SELECT column
- One subquery per referenced field is acceptable for 1-3 columns (the typical case)

**Consistency concern across subqueries:**

Multiple correlated subqueries for the same derived association (e.g., `latest_comment.created_at` and `latest_comment.author_name`) are independent — in theory, they could return data from different records if a comment is inserted between evaluations.

In practice, within a single `SELECT` statement:
- **PostgreSQL:** MVCC guarantees a consistent snapshot — all subqueries see the same data. No issue.
- **SQLite:** Uses a shared read lock for the statement — consistent. No issue.
- **MySQL (InnoDB, REPEATABLE READ):** Consistent snapshot within a transaction. No issue under default settings.

This is a theoretical concern with no practical impact under standard database configurations. If strict cross-database consistency guarantees are needed, the PostgreSQL LATERAL JOIN optimization (see [Future](#future-v3--postgresql-lateral-join-optimization)) resolves it with a single subquery.

### Show page: real AR object

On the show page (single record), the derived association is loaded as a real ActiveRecord object:

1. The engine finds the `has_many` association on the model
2. Builds an AR query: `record.comments.where(where_conditions).order(order_by => direction).first`
3. The result is a real AR object — renderers can access any field, including nested associations

This is more flexible than subqueries and avoids N+1 (only one record is loaded). Service-based renderers that expect full AR objects work without changes.

### Lazy inclusion

Like aggregates, derived association subqueries are only injected when the presenter references them:

1. `ColumnSet` collects dot-paths that start with a derived association name
2. Only the referenced columns generate subqueries
3. No derived association reference in the presenter → zero SQL overhead

## Decisions

1. **Separate top-level key `derived_associations`.** Not an aggregate extension, not a special association type. The concept is distinct enough to warrant its own namespace.

2. **Correlated subqueries per column (portable).** Works on SQLite, PostgreSQL, and MySQL. Consistent with the aggregate columns SQL strategy. Acceptable performance for the typical 1-3 columns.

3. **Dot-path access in presenter.** Derived associations are referenced as `derived_name.field` — the same syntax as `belongs_to` dot-paths. The presenter does not need to distinguish between real and derived associations.

4. **Scope interaction: only soft delete.** Default scopes are ignored. Soft delete filtering is applied automatically (consistent with aggregates). Explicit `where:` for any other filtering.

5. **Show page: real AR object.** On the show page, the derived association is loaded as a real ActiveRecord record via the underlying `has_many` association. On the index page, raw SQL subqueries are used for efficiency.

6. **v2 feature, after aggregates.** For v1, complex cases can be handled with `sql:` aggregates. Derived associations add the clean abstraction in v2.

## Open Questions / Future

### Future (v2): multi-column `order_by`

The initial implementation supports single-column ordering. A future extension could support multi-column ordering for tiebreakers:

```yaml
derived_associations:
  latest_high_priority_comment:
    association: comments
    order_by: [priority, created_at]
    direction: [desc, desc]
```

For v2, start with single-column — it covers the vast majority of cases.

### Future (v2): explicit `scope:` parameter

If the need arises to reference named model scopes in derived associations (beyond what `where:` hash supports), an explicit `scope:` parameter could be added:

```yaml
derived_associations:
  latest_published_comment:
    association: comments
    scope: published              # named scope on comment model
    order_by: created_at
```

This requires resolving the named scope to SQL at subquery generation time — feasible but adds complexity. Deferred unless demand emerges.

### Future (v3): PostgreSQL LATERAL JOIN optimization

When the platform detects PostgreSQL, derived associations with multiple referenced columns could be optimized to a single `LATERAL JOIN` instead of N correlated subqueries:

```sql
-- Instead of N correlated subqueries:
SELECT projects.*,
  (SELECT c.created_at FROM comments c WHERE c.project_id = projects.id ORDER BY c.created_at DESC LIMIT 1),
  (SELECT c.author_name FROM comments c WHERE c.project_id = projects.id ORDER BY c.created_at DESC LIMIT 1)
FROM projects

-- One LATERAL JOIN:
SELECT projects.*, lc.created_at AS "latest_comment.created_at", lc.author_name AS "latest_comment.author_name"
FROM projects
LEFT JOIN LATERAL (
  SELECT c.created_at, c.author_name
  FROM comments c
  WHERE c.project_id = projects.id
  ORDER BY c.created_at DESC
  LIMIT 1
) lc ON true
```

**Advantages of LATERAL JOIN:**

- **Single subquery per derived association** instead of one per column — significant performance improvement when 3+ columns are referenced
- **Guaranteed consistency** — all columns come from the same row, by definition
- **Better optimizer support** — PostgreSQL can use a single index scan instead of repeating it per subquery
- **Cleaner generated SQL** — easier to read and debug

**Why not use LATERAL JOIN from the start:**

- Not portable — LATERAL JOIN is PostgreSQL-specific (MySQL 8.0.14+ has limited support; SQLite does not support it)
- Correlated subqueries work everywhere and are sufficient for 1-3 columns
- Adding database-specific SQL generation adds complexity to the engine

**Implementation approach:** Database adapter detection at boot time. When PostgreSQL is detected and a derived association has 2+ referenced columns, generate LATERAL JOIN. Otherwise, fall back to correlated subqueries. The presenter and field resolution layer are unaffected — only the SQL generation changes.

### Future: derived associations in `record_rules` / `visible_when`

Using derived association values in conditions:

```yaml
record_rules:
  - action: destroy
    deny_when:
      latest_comment.created_at:
        lt: "3_days_ago"
```

This requires the derived association value to be loaded on the record, which happens when the presenter references it. Natural extension once the base feature is stable.

### Future: through-association derived records

Picking a record through a chain of associations:

```yaml
derived_associations:
  latest_sprint_task:
    association: tasks
    through: sprints
    order_by: created_at
```

Requires a JOIN in the subquery. Same complexity as through-association aggregates — deferred to the same timeline.
