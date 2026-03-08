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
