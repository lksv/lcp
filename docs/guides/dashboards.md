# Dashboards Guide

Dashboards in LCP Ruby are **standalone pages** with `layout: grid` and widget zones. They reuse the full Pages infrastructure — no separate abstraction is needed.

For record-bound multi-zone pages with tabs and related data (e.g., employee detail with leave requests and trainings), see the [Composite Pages Guide](composite-pages.md) instead.

## Quick Start

### 1. Define a Dashboard Page

Create a page YAML in `config/lcp_ruby/pages/`:

```yaml
# config/lcp_ruby/pages/main_dashboard.yml
page:
  name: main_dashboard
  slug: dashboard
  layout: grid
  title_key: lcp_ruby.dashboard.title
  zones:
    - name: total_orders
      type: widget
      widget:
        type: kpi_card
        model: order
        aggregate: count
        icon: shopping-cart
        link_to: orders
      position: { row: 1, col: 1, width: 4, height: 1 }

    - name: revenue
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
        link_to: tasks
      scope: open
      position: { row: 1, col: 9, width: 4, height: 1 }

    - name: welcome
      type: widget
      widget:
        type: text
        content_key: lcp_ruby.dashboard.welcome
      position: { row: 2, col: 1, width: 12, height: 1 }

    - name: recent_tasks
      presenter: tasks
      scope: recent
      limit: 5
      position: { row: 3, col: 1, width: 6, height: 2 }

    - name: recent_orders
      presenter: orders
      scope: recent
      limit: 5
      position: { row: 3, col: 7, width: 6, height: 2 }
```

### 2. Add a View Group (optional)

If you don't define an explicit view group, one will be auto-created. For custom navigation:

```yaml
# config/lcp_ruby/views/dashboard.yml
view_group:
  name: dashboard
  primary: main_dashboard
  navigation:
    menu: main
    position: 1
  views:
    - page: main_dashboard
      label: "Dashboard"
```

### 3. Configure Landing Page (optional)

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  # Simple: everyone lands on the dashboard
  config.landing_page = "dashboard"

  # Role-based: different dashboards per role
  config.landing_page = {
    "admin" => "admin-dashboard",
    "manager" => "manager-dashboard",
    "default" => "dashboard"
  }
end
```

## Widget Types

### KPI Card

Displays an aggregate value (count, sum, avg, min, max) from a model.

```yaml
- name: total_revenue
  type: widget
  widget:
    type: kpi_card
    model: order           # Required: model to query
    aggregate: sum         # Required: count, sum, avg, min, max
    aggregate_field: total_amount  # Required for sum/avg/min/max
    format: currency       # Optional: currency, percentage, decimal, integer
    icon: dollar-sign      # Optional: Lucide icon name
    link_to: orders        # Optional: slug to link "View all"
    label_key: dashboard.revenue  # Optional: i18n key for label
  scope: completed         # Optional: named scope to apply
  position: { row: 1, col: 1, width: 3, height: 1 }
```

### Text

Displays static i18n content.

```yaml
- name: welcome
  type: widget
  widget:
    type: text
    content_key: lcp_ruby.dashboard.welcome  # Required: i18n key
  position: { row: 2, col: 1, width: 12, height: 1 }
```

### List

Displays a limited list of records from a model.

```yaml
- name: recent_tasks
  type: widget
  widget:
    type: list
    model: task            # Required: model to query
    link_to: tasks         # Optional: slug to link "View all"
  scope: recent            # Optional: named scope
  limit: 5                 # Optional: max records (default: 5)
  position: { row: 3, col: 1, width: 6, height: 2 }
```

### Presenter Zone

Displays a compact table from an existing presenter (reuses column definitions, actions, and field rendering).

```yaml
- name: recent_orders
  presenter: orders        # Required: presenter name
  scope: recent            # Optional: named scope
  limit: 10                # Optional: max records (default: 10)
  position: { row: 3, col: 7, width: 6, height: 2 }
```

## Grid Layout

The grid uses a 12-column CSS Grid layout. Each zone specifies its position:

```yaml
position:
  row: 1      # Grid row (1-based)
  col: 1      # Grid column (1-based, out of 12)
  width: 4    # Column span (default: 1)
  height: 1   # Row span (default: 1)
```

On screens narrower than 768px, zones stack into a single column.

## Conditional Zones

Use `visible_when` to show/hide zones based on conditions.

### Role Shortcut

The simplest form — show a zone only to specific roles:

```yaml
- name: admin_stats
  type: widget
  widget:
    type: kpi_card
    model: user
    aggregate: count
  visible_when:
    role: admin
  position: { row: 1, col: 1, width: 4, height: 1 }

# Multiple roles:
- name: management_kpi
  type: widget
  widget:
    type: kpi_card
    model: order
    aggregate: sum
    aggregate_field: total_amount
  visible_when:
    role: [admin, manager]
  position: { row: 1, col: 5, width: 4, height: 1 }
```

### Condition Object

Full condition expressions for dynamic visibility:

```yaml
- name: status_alert
  type: widget
  widget:
    type: kpi_card
    model: task
    aggregate: count
  visible_when:
    field: role
    operator: eq
    value: admin
  position: { row: 1, col: 1, width: 4, height: 1 }
```

## Dedicated Dashboard Presenter

For presenter zones on dashboards, you can create a dedicated presenter with a compact column set:

```yaml
# config/lcp_ruby/presenters/dashboard_tasks.yml
presenter:
  name: dashboard_tasks
  model: task
  embeddable: true
  read_only: true
  index:
    table_columns:
      - { field: title }
      - { field: status }
      - { field: due_date }
    default_sort: { field: due_date, direction: asc }
  actions:
    collection: []
    single:
      - { name: show, type: built_in }
```

Reference it in the dashboard page:

```yaml
- name: upcoming_tasks
  presenter: dashboard_tasks
  scope: upcoming
  limit: 5
  position: { row: 3, col: 1, width: 6, height: 2 }
```

## Permissions

- Widget zones that reference a model check `can?(:index)` for that model
- If the user has no access to a widget's model, the widget is hidden (not an error)
- Presenter zones also check `can_access_presenter?` for the referenced presenter
- Standalone dashboard pages skip presenter-level authorization (no primary presenter)
