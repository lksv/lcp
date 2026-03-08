# Pages Reference

Pages are the top-level layout unit in LCP Ruby. Every routable URL maps to a page, which contains one or more **zones** — regions that display either a presenter or a widget.

Pages are defined in `config/lcp_ruby/pages/` as YAML files with the root key `page:`.

## Page Attributes

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `name` | string | yes | — | Unique page identifier. Used in view group references and dialog targets. |
| `slug` | string | no | — | URL slug for routing. Pages without a slug are only accessible as dialog targets. |
| `model` | string | no | — | Associated model name. Standalone dashboard pages may omit this. |
| `layout` | string | no | `semantic` | `semantic` (named areas) or `grid` (CSS grid with explicit positions). |
| `title_key` | string | no | — | i18n key for page title. Falls back to humanized name. |
| `dialog` | object | no | — | Dialog rendering config. When present, the page can be rendered in a modal. |
| `zones` | array | yes | — | One or more zone definitions (min 1). |

## Dialog Configuration

The `dialog:` key controls how the page renders as a modal.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `size` | string | `medium` | `small`, `medium`, `large`, or `fullscreen`. |
| `closable` | boolean | `true` | Whether clicking outside or pressing Escape closes the dialog. |
| `title_key` | string | — | i18n key for the dialog title bar. |

```yaml
page:
  name: quick_create_order
  dialog:
    size: large
    closable: false
    title_key: lcp_ruby.dialogs.quick_create
  zones:
    - name: main
      presenter: order_create_form
```

## Zone Attributes

Each zone represents a content region within the page.

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `name` | string | yes | — | Unique identifier within the page. |
| `type` | string | no | `presenter` | `presenter` or `widget`. |
| `presenter` | string | conditional | — | Presenter name. Required for presenter zones. |
| `area` | string | no | `main` | Named area for semantic layout (`main`, `sidebar`). |
| `widget` | object | conditional | — | Widget config. Required for widget zones. |
| `position` | object | no | — | Grid positioning (`row`, `col`, `width`, `height`). |
| `scope` | string | no | — | Named scope to apply to the zone's data query. |
| `limit` | integer | no | — | Maximum records to display (min 1). |
| `visible_when` | object | no | — | Conditional visibility (role shortcut or condition object). |

### Presenter Zones

Render a full presenter (index table, show page, form). The presenter must exist in `config/lcp_ruby/presenters/`.

```yaml
zones:
  - name: recent_tasks
    presenter: dashboard_tasks
    scope: recent
    limit: 5
```

### Widget Zones

Render a standalone widget. Set `type: widget` and provide the `widget:` config.

## Widget Types

### kpi_card

Displays an aggregate value (count, sum, avg, min, max) over a model's records.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | yes | Must be `kpi_card`. |
| `model` | string | yes | Model to aggregate over. |
| `aggregate` | string | yes | `count`, `sum`, `avg`, `min`, or `max`. |
| `aggregate_field` | string | no | Field to aggregate. Required for `sum`/`avg`/`min`/`max`. Defaults to `id` for `count`. |
| `format` | string | no | Display format (e.g., `currency`, `number`, `percent`). |
| `icon` | string | no | Icon name for the card. |
| `link_to` | string | no | Page slug to navigate to on click. |
| `label_key` | string | no | i18n key for the card label. |

```yaml
- name: total_revenue
  type: widget
  widget:
    type: kpi_card
    model: order
    aggregate: sum
    aggregate_field: total_amount
    format: currency
    icon: dollar-sign
    link_to: orders
    label_key: lcp_ruby.dashboard.revenue
  position: { row: 1, col: 1, width: 4, height: 1 }
```

### text

Displays translated static content.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | yes | Must be `text`. |
| `content_key` | string | yes | i18n key for the text content. |

```yaml
- name: welcome
  type: widget
  widget:
    type: text
    content_key: lcp_ruby.dashboard.welcome
  position: { row: 2, col: 1, width: 12, height: 1 }
```

### list

Displays recent records from a model.

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | yes | Must be `list`. |
| `model` | string | yes | Model to list records from. |
| `link_to` | string | no | Page slug for the "view all" link. |
| `label_key` | string | no | i18n key for the list header. |

```yaml
- name: recent_orders
  type: widget
  widget:
    type: list
    model: order
    link_to: orders
    label_key: lcp_ruby.dashboard.recent_orders
  scope: recent
  limit: 5
```

## Grid Positioning

Grid layout pages use a 12-column CSS grid. Each zone specifies its position:

| Key | Type | Description |
|-----|------|-------------|
| `row` | integer | Starting grid row (1-based). |
| `col` | integer | Starting grid column (1-12). |
| `width` | integer | Number of columns to span. |
| `height` | integer | Number of rows to span. |

All values must be positive integers (>= 1).

```yaml
page:
  name: main_dashboard
  layout: grid
  zones:
    - name: kpi_1
      type: widget
      widget: { type: kpi_card, model: order, aggregate: count }
      position: { row: 1, col: 1, width: 4, height: 1 }
    - name: kpi_2
      type: widget
      widget: { type: kpi_card, model: order, aggregate: sum, aggregate_field: total }
      position: { row: 1, col: 5, width: 4, height: 1 }
    - name: main_content
      presenter: orders
      position: { row: 2, col: 1, width: 12, height: 3 }
```

## Auto-Page Creation

Presenters that are not explicitly claimed by any page zone automatically get a simple page created at boot:

- Page name = presenter name
- Single presenter zone with `area: main`
- Slug inherited from the presenter
- `auto_generated: true` flag (skipped by schema validation)

This means every presenter is accessible without explicit page YAML. Explicit pages override auto-generated ones by claiming the presenter in a zone.

## Slug Ownership

- Explicit pages with a `slug:` take priority.
- Auto-generated pages inherit the presenter's slug.
- Duplicate slugs across pages produce a validation error.

## Standalone Pages

Pages without a `model:` are standalone — they are not tied to any single model. Standalone dashboard pages can contain widget zones referencing multiple different models.

```yaml
page:
  name: main_dashboard
  slug: dashboard
  layout: grid
  zones:
    - name: orders_count
      type: widget
      widget: { type: kpi_card, model: order, aggregate: count }
      position: { row: 1, col: 1, width: 6, height: 1 }
    - name: tasks_count
      type: widget
      widget: { type: kpi_card, model: task, aggregate: count }
      position: { row: 1, col: 7, width: 6, height: 1 }
```

## Dialog-Only Pages

Pages with `dialog:` config but no `slug:` are dialog-only — they cannot be navigated to directly but can be opened as modal dialogs by actions.

```yaml
page:
  name: feedback_form
  dialog:
    size: medium
    closable: true
    title_key: lcp_ruby.dialogs.feedback
  zones:
    - name: main
      presenter: feedback_create
```

## Composite Pages (Semantic Layout)

Composite pages combine multiple zones into a record-bound layout with named areas: `main`, `tabs`, `sidebar`, and `below`. They use semantic layout (the default) to arrange zones into a structured detail page — for example, an employee detail page with a header, tabbed related records, and a sidebar.

A page is composite when it:
- Is explicitly defined (not auto-generated)
- Has more than one zone
- Is not standalone (has a `model:`)

### Areas

| Area | Description |
|------|-------------|
| `main` | Primary content area. Typically renders a show presenter with record details. |
| `tabs` | Tabbed content below the main area. Each tab zone becomes a tab in the tab bar. Only the active tab's data is loaded. |
| `sidebar` | Side panel alongside the main content. |
| `below` | Full-width area below the tabs. |

### Zone Attributes for Composite Pages

In addition to the [standard zone attributes](#zone-attributes), composite page zones support:

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `scope_context` | object | no | — | Maps column names on the zone's model to dynamic references resolved from the parent record or request context. |
| `label_key` | string | no | — | i18n key for the zone's tab label. Recommended for tab zones. Falls back to humanized zone name. |

### scope_context

`scope_context` scopes a zone's data query to the parent record. Each key is a column name on the zone's model, and each value is either a static value or a dynamic reference prefixed with `:`.

**Dynamic references:**

| Reference | Resolves to |
|-----------|-------------|
| `:record_id` | The parent record's `id` |
| `:record.<field>` | A field value from the parent record (single-level dot-path only, e.g., `:record.department_id`) |
| `:current_user` | The full `current_user` object (useful with `filter_*` interceptors) |
| `:current_user_id` | The current user's `id` |
| `:current_year` | The current year (integer) |
| `:current_date` | Today's date |

Static values (without `:` prefix) pass through unchanged.

**Dot-path depth limit:** Only single-level dot-paths are supported (e.g., `:record.department_id`). Multi-level paths like `:record.department.company_id` raise a `MetadataError`.

```yaml
# Scope leave requests to the current employee
scope_context:
  employee_id: ":record_id"

# Scope by a field on the parent record
scope_context:
  department_id: ":record.department_id"

# Scope to current user
scope_context:
  assigned_to_id: ":current_user_id"

# Static value
scope_context:
  year: 2024
```

**Scope application:** Each `scope_context` key is applied to the zone's query in this order:

1. If the zone's model defines a `filter_<key>` class method, that method is called. The method may accept 2 arguments `(scope, value)` or 3 arguments `(scope, value, evaluator)` — both signatures are supported.
2. Otherwise, if the key is a column name on the model, a `where(key => value)` clause is applied.
3. If neither exists, a warning is logged and the key is skipped.

### Main Zone Selection

The main zone is selected automatically with this priority:

1. First presenter zone with `area: main`
2. First presenter zone (any area)
3. First zone of any type

### Tab Navigation

Tab zones render as a tab bar with links. The first tab is active by default. Users switch tabs via the `?tab=<zone_name>` query parameter. Only the active tab's data is loaded on each request (server-side full page reload).

Inactive tabs are skipped during data resolution, keeping queries efficient.

### Per-Zone Authorization

Each presenter zone checks whether the current user has presenter access for that zone's presenter. If the user lacks access (via the `presenters` key in permissions YAML), the zone is completely hidden — no tab link appears in the tab bar and no data is loaded.

This differs from `visible_when`, which also hides zones but is based on conditions (role, field values) rather than presenter permissions. Both mechanisms produce the same result: the zone is excluded from rendering.

### Composite Page Example

```yaml
page:
  name: employee_detail
  model: employee
  slug: employees
  zones:
    - name: header
      presenter: employee_show
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

    - name: notes
      presenter: employee_notes
      area: sidebar
      scope_context:
        employee_id: ":record_id"

    - name: activity_log
      presenter: audit_entries
      area: below
      scope_context:
        record_id: ":record_id"
      visible_when:
        role: admin
```

This renders:
- **Main area**: Employee detail (show presenter)
- **Tab bar**: "Leave requests" and "Trainings" tabs, each scoped to this employee
- **Sidebar**: Notes panel scoped to this employee
- **Below**: Activity log visible only to admins

### Widget Zones with scope_context

Widget zones on composite pages can also use `scope_context` to scope their data to the parent record:

```yaml
zones:
  - name: header
    presenter: employee_show
    area: main

  - name: leave_count
    type: widget
    area: sidebar
    widget:
      type: kpi_card
      model: leave_request
      aggregate: count
      label_key: pages.employee.sidebar.leave_count
    scope_context:
      employee_id: ":record_id"
```

### Constraints

The configuration validator enforces these rules for composite pages:

- **Main zone must not be an index presenter when tabs are present.** Index presenters use `page`, `sort`, and `q[...]` query parameters that collide with tab parameters. Use a show presenter for the main zone.
- **Main zone model should match the page model.** A warning is produced if the main zone's presenter references a different model than the page's `model:` attribute.
- **Tab zones should have `label_key`.** Tabs fall back to the humanized zone name, but explicit labels are recommended.

### Claimed Presenters

Presenters used as zones in a composite page are "claimed" and do not get auto-generated pages. This prevents duplicate routes — the composite page owns the rendering for those presenters.

## Conditional Zone Visibility

Use `visible_when` to show zones only to specific users.

### Role Shortcut

```yaml
visible_when:
  role: admin

# or multiple roles
visible_when:
  role: [admin, manager]
```

### Condition Object

Full condition expressions (same syntax as presenter `visible_when`):

```yaml
visible_when:
  field: status
  operator: eq
  value: active
```

## Complete Example

```yaml
page:
  name: main_dashboard
  slug: dashboard
  layout: grid
  title_key: lcp_ruby.dashboard.title
  zones:
    - name: order_count
      type: widget
      widget:
        type: kpi_card
        model: order
        aggregate: count
        icon: shopping-cart
        link_to: orders
      position: { row: 1, col: 1, width: 4, height: 1 }

    - name: total_revenue
      type: widget
      widget:
        type: kpi_card
        model: order
        aggregate: sum
        aggregate_field: total_amount
        format: currency
        icon: dollar-sign
      position: { row: 1, col: 5, width: 4, height: 1 }

    - name: open_tasks
      type: widget
      widget:
        type: kpi_card
        model: task
        aggregate: count
        icon: check-square
      scope: open
      position: { row: 1, col: 9, width: 4, height: 1 }
      visible_when:
        role: [admin, manager]

    - name: welcome_text
      type: widget
      widget:
        type: text
        content_key: lcp_ruby.dashboard.welcome
      position: { row: 2, col: 1, width: 12, height: 1 }

    - name: recent_tasks
      presenter: dashboard_tasks
      scope: recent
      limit: 5
      position: { row: 3, col: 1, width: 6, height: 2 }

    - name: recent_orders
      presenter: dashboard_orders
      scope: recent
      limit: 5
      position: { row: 3, col: 7, width: 6, height: 2 }
```
