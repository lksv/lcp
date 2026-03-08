# Composite Pages Guide

Composite pages display a record with multiple related zones — a detail header, tabbed sub-tables, an optional sidebar, and below-content areas. This guide walks through building a typical master-detail page.

For the full attribute reference, see the [Pages Reference](../reference/pages.md#composite-pages-semantic-layout).

## When to Use Composite Pages

Use composite pages when a single record's show page needs to display related data from other models. Common examples:

- Employee detail with tabs for leave requests, trainings, and evaluations
- Company 360-degree view with contacts, deals, and activity feed
- Order detail with line items, shipments, and payment history

If you only need a standalone overview with KPI cards and widgets, use a [Dashboard](dashboards.md) instead (standalone page with `layout: grid`).

## Quick Start

### 1. Define the Models

You need a primary model and one or more related models:

```yaml
# config/lcp_ruby/models/employee.yml
model:
  name: employee
  fields:
    - { name: name, type: string }
    - { name: email, type: email }
    - { name: department, type: string }
    - { name: status, type: enum, enum_values: [active, inactive] }

# config/lcp_ruby/models/leave_request.yml
model:
  name: leave_request
  fields:
    - { name: employee_id, type: integer }
    - { name: start_date, type: date }
    - { name: end_date, type: date }
    - { name: status, type: enum, enum_values: [pending, approved, rejected] }
    - { name: reason, type: string }
  associations:
    - { type: belongs_to, name: employee }

# config/lcp_ruby/models/training.yml
model:
  name: training
  fields:
    - { name: employee_id, type: integer }
    - { name: title, type: string }
    - { name: status, type: enum, enum_values: [scheduled, completed, cancelled] }
  associations:
    - { type: belongs_to, name: employee }
```

### 2. Create Presenters for Each Zone

Each zone in a composite page renders a presenter. The main zone typically uses a show presenter, while tab zones use index presenters:

```yaml
# config/lcp_ruby/presenters/employee_detail.yml
presenter:
  name: employee_detail
  model: employee
  slug: employees
  show:
    layout:
      - section: Details
        fields:
          - { field: name }
          - { field: email }
          - { field: department }
          - { field: status }
  actions:
    single:
      - { name: edit, type: built_in }

# config/lcp_ruby/presenters/leave_requests_index.yml
presenter:
  name: leave_requests_index
  model: leave_request
  index:
    table_columns:
      - { field: start_date }
      - { field: end_date }
      - { field: status }
      - { field: reason }

# config/lcp_ruby/presenters/trainings_index.yml
presenter:
  name: trainings_index
  model: training
  index:
    table_columns:
      - { field: title }
      - { field: status }
```

### 3. Define the Composite Page

Create a page YAML that combines the presenters into zones:

```yaml
# config/lcp_ruby/pages/employee_detail.yml
page:
  name: employee_detail
  model: employee
  slug: employees
  zones:
    - name: header
      presenter: employee_detail
      area: main

    - name: leave_requests
      presenter: leave_requests_index
      area: tabs
      label_key: pages.employee_detail.tabs.leave_requests
      scope_context:
        employee_id: ":record_id"

    - name: trainings
      presenter: trainings_index
      area: tabs
      label_key: pages.employee_detail.tabs.trainings
      scope_context:
        employee_id: ":record_id"
```

### 4. Set Up Permissions

Each zone's presenter model needs permissions. If a role has no presenter access for a zone's model, that zone (and its tab) is hidden:

```yaml
# config/lcp_ruby/permissions/employee.yml
permissions:
  model: employee
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      presenters: all
      fields:
        readable: all
        writable: all
    viewer:
      crud: [index, show]
      presenters: all
      fields:
        readable: all

# config/lcp_ruby/permissions/leave_request.yml
permissions:
  model: leave_request
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      presenters: all
      fields:
        readable: all
        writable: all
    viewer:
      crud: [index, show]
      presenters: all
      fields:
        readable: all

# config/lcp_ruby/permissions/training.yml
permissions:
  model: training
  roles:
    admin:
      crud: [index, show]
      presenters: all
      fields:
        readable: all
    viewer:
      crud: [index]
      presenters: []    # No presenter access -> training tab hidden for viewers
      fields:
        readable: all
```

In this example, users with the `viewer` role see the employee detail and leave requests tab, but the trainings tab is hidden because `presenters: []` denies presenter access.

### 5. Add Translations (optional)

```yaml
# config/locales/en.yml
en:
  pages:
    employee_detail:
      tabs:
        leave_requests: "Leave Requests"
        trainings: "Trainings"
```

If translations are missing, tabs fall back to the humanized zone name (e.g., "Leave requests").

## Areas

Composite pages use **semantic layout** with four named areas:

```
+---------------------------+----------+
|         main              | sidebar  |
+---------------------------+----------+
| tabs: [tab1] [tab2]                  |
| +-----------------------------------+|
| | active tab content                ||
| +-----------------------------------+|
+---------------------------------------+
| below                                 |
+---------------------------------------+
```

| Area | Description | Typical use |
|------|-------------|-------------|
| `main` | Primary record details | Show presenter (header section) |
| `sidebar` | Side panel | Notes, quick stats, related links |
| `tabs` | Tabbed content with tab bar | Related record tables (leave requests, trainings) |
| `below` | Full-width area below tabs | Activity log, audit trail |

Zones default to `area: main` if not specified.

## scope_context

The `scope_context` attribute scopes a zone's data query to the parent record. Without it, a tab would show all records from the model, not just those related to the current employee.

Each key is a column name on the zone's model, and each value is a dynamic reference or static value:

```yaml
# Most common: scope by parent record ID
scope_context:
  employee_id: ":record_id"

# Scope by a field on the parent record
scope_context:
  department_id: ":record.department_id"

# Scope to the current user
scope_context:
  assigned_to_id: ":current_user_id"

# Multiple conditions
scope_context:
  employee_id: ":record_id"
  year: ":current_year"
```

**Available dynamic references:**

| Reference | Resolves to |
|-----------|-------------|
| `:record_id` | Parent record's `id` |
| `:record.<field>` | Field value from the parent record (single-level dot-path only) |
| `:current_user` | The full `current_user` object (useful with `filter_*` interceptors) |
| `:current_user_id` | Current user's `id` |
| `:current_year` | Current year (integer) |
| `:current_date` | Today's date |

Static values (without `:` prefix) pass through unchanged.

**Dot-path depth:** Only single-level paths are supported (e.g., `:record.department_id`). Multi-level paths like `:record.department.company_id` raise an error.

**Scope application:** For each `scope_context` key, the platform first checks if the zone's model defines a `filter_<key>` class method. If found, that method is called (both 2-arg `(scope, value)` and 3-arg `(scope, value, evaluator)` signatures are supported). Otherwise, a plain `where(key => value)` clause is applied. If neither a filter method nor a column exists, a warning is logged and the key is skipped.

## Tab Navigation

Tabs are server-side rendered with full page reload. The URL uses a `?tab=<zone_name>` query parameter:

```
/employees/123              → first tab active (leave_requests)
/employees/123?tab=trainings → trainings tab active
```

Only the active tab's data is loaded per request. Inactive tabs render as links in the tab bar but their data is not queried.

## Adding a Sidebar

The sidebar area renders alongside the main content. Both presenter and widget zones work in the sidebar:

```yaml
page:
  name: employee_detail
  model: employee
  slug: employees
  zones:
    - name: header
      presenter: employee_detail
      area: main

    - name: leave_count
      type: widget
      area: sidebar
      widget:
        type: kpi_card
        model: leave_request
        aggregate: count
        label_key: pages.employee_detail.sidebar.leave_count
      scope_context:
        employee_id: ":record_id"

    - name: leave_requests
      presenter: leave_requests_index
      area: tabs
      label_key: pages.employee_detail.tabs.leave
      scope_context:
        employee_id: ":record_id"
```

The sidebar renders alongside the main area (2:1 column ratio). On screens narrower than 768px, it stacks below the main content.

## Conditional Zone Visibility

Use `visible_when` to restrict zone visibility:

```yaml
zones:
  - name: audit_log
    presenter: audit_entries
    area: below
    scope_context:
      record_id: ":record_id"
    visible_when:
      role: admin
```

This supports the same condition syntax as presenter `visible_when` — role shortcuts and full condition objects.

## Claimed Presenters

Presenters used as zones in a composite page are "claimed" — they do not get auto-generated pages. This prevents duplicate routes (e.g., `/leave-requests` would not exist separately since `leave_requests_index` is embedded in the employee detail page).

If you need the presenter to also be accessible as a standalone page, create a separate page definition for it.

## Validation

The configuration validator checks composite page definitions at boot:

- `scope_context` keys must be valid columns on the zone's model (warning)
- Dynamic references must use recognized formats (`:record_id`, `:record.<field>`, etc.) (warning)
- `:record.<field>` references are validated against the page's primary model (warning)
- Tab zones without `label_key` produce a warning (tabs fall back to humanized zone name, but explicit labels are recommended)
- Main zone must not be an index presenter when tabs are present (error — prevents query parameter collisions)
- Main zone presenter model should match the page's `model:` attribute (warning)

Run validation manually:

```bash
bundle exec rake lcp_ruby:validate
```

## Relationship to Dashboards

Both dashboards and composite pages use the Pages infrastructure, but they serve different purposes:

| | Dashboards | Composite Pages |
|---|---|---|
| **Layout** | `grid` (CSS grid with explicit positions) | `semantic` (named areas: main, tabs, sidebar, below) |
| **Model** | Standalone (no `model:`) | Record-bound (has `model:`) |
| **Zones** | Widgets (KPI cards, text, lists) + presenter zones | Presenter + widget zones with `scope_context` |
| **URL** | `/dashboard` | `/employees/123?tab=leave_requests` |
| **Use case** | Overview with KPIs and summaries | Record detail with related data |

## What's Next

- [Pages Reference](../reference/pages.md) — Full attribute reference for pages and zones
- [Dashboards Guide](dashboards.md) — Standalone grid pages with KPI widgets
- [Dialogs Guide](dialogs.md) — Modal dialog pages
- [View Groups Guide](view-groups.md) — Navigation menu and view switching
