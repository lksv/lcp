# Feature Specification: Dashboards

**Status:** Proposed
**Date:** 2026-03-06

## Problem / Motivation

LCP currently generates CRUD presenters — index (table/tiles/tree), show, and form views. All of them are scoped to a single model. There is no way to build an overview page that aggregates data from multiple models, shows KPI metrics, charts, or recent activity across the system.

Real-world information systems need dashboards:

- **CRM:** Pipeline value, deals closed this month, top customers, activity feed
- **Project management:** Open issues count, burndown chart, overdue tasks, team workload
- **HR:** Headcount by department, open positions, upcoming reviews, attrition trend
- **Help desk:** Tickets by status, average resolution time, SLA compliance, recent escalations
- **E-shop:** Revenue today, orders by status, top products, stock alerts

Without platform-level dashboard support, host apps must build custom pages outside the declarative YAML model, losing permissions, routing, menu integration, and the consistent UI.

## User Scenarios

**As a platform configurator,** I want to define a dashboard in YAML that shows KPI cards (total orders, open tasks, revenue this month) and a table of recent records, so that users see an at-a-glance overview when they log in.

**As an admin,** I want different roles to see different dashboards as their landing page — managers see KPIs and charts, regular users see their assigned tasks and recent activity.

**As a platform configurator,** I want to add a chart widget (orders by month, deals by stage) to the dashboard without writing any JavaScript — just YAML configuration referencing existing models and scopes.

**As a platform configurator,** I want to embed an external BI tool (Metabase, Grafana) into a dashboard widget for advanced analytics, while keeping simple widgets native to the platform.

**As a user,** I want to click on a KPI number and be taken to the filtered index page showing the underlying records (e.g., click "47 open tasks" and see those 47 tasks).

## Configuration & Behavior

### Dashboard definition

Dashboards are a new top-level metadata concept, defined in `config/lcp_ruby/dashboards/`. Each YAML file defines one dashboard. Dashboards are not presenters — they do not map to a single model. They have their own loader, definition object, and controller.

```yaml
# config/lcp_ruby/dashboards/main.yml
slug: main-dashboard
title_key: dashboards.main.title    # i18n key, fallback: "Main Dashboard"
layout:
  columns: 12                       # CSS grid columns (default: 12)

widgets:
  - name: total_orders
    type: kpi_card
    model: order
    aggregate: count
    scope: this_month
    icon: shopping-cart
    trend:
      compare: previous_period      # Tier 2 — compare with previous month
    position: { row: 1, col: 1, width: 3, height: 1 }
    link_to: orders                  # click → /orders?scope=this_month

  - name: open_tasks
    type: kpi_card
    model: task
    aggregate: count
    scope: open
    position: { row: 1, col: 4, width: 3, height: 1 }
    link_to: tasks                   # click → /tasks?scope=open

  - name: revenue
    type: kpi_card
    model: order
    aggregate: sum
    aggregate_field: total_amount
    scope: this_month
    format: currency
    position: { row: 1, col: 7, width: 3, height: 1 }

  - name: recent_orders
    type: table
    presenter: orders                # reuse existing presenter's columns
    scope: recent
    limit: 5
    position: { row: 2, col: 1, width: 8, height: 2 }

  - name: orders_by_month
    type: chart
    chart_type: line                 # bar, line, pie, donut, area
    model: order
    group_by: created_at
    group_period: month
    aggregate: count
    position: { row: 2, col: 9, width: 4, height: 2 }

  - name: notes
    type: text
    content_key: dashboards.main.welcome_note  # i18n key
    position: { row: 1, col: 10, width: 3, height: 1 }
```

### Widget types

| Type | Tier | Description |
|------|------|-------------|
| `kpi_card` | 1 | Large number with label and optional icon. Data from aggregate query on a model + scope. Optional `link_to` for drill-down to filtered index. |
| `table` | 1 | Compact record table. References an existing presenter (reuses its column definitions). Configurable `scope`, `limit`, and optional `link_to` for "view all". |
| `list` | 1 | Simple record list (compact variant of table — title + subtitle fields only). |
| `text` | 1 | Static content from i18n key. For welcome messages, instructions, section headers. |
| `chart` | 2 | Bar, line, pie, donut, area chart. Rendered via Chartkick gem (wraps Chart.js). Data from `group_by` + `aggregate` on a model. |
| `embed` | 3 | Iframe embedding external content (Metabase dashboard, Grafana panel, custom URL). Signed embed URL support. |

### Grid layout

The dashboard uses a CSS grid with configurable column count (default 12). Each widget specifies its position and size via `row`, `col`, `width`, `height`. On smaller screens, widgets stack vertically (responsive fallback).

### Permissions

Dashboard visibility is controlled through the existing permission system. Each dashboard can be restricted by role:

```yaml
# config/lcp_ruby/permissions/default.yml
roles:
  admin:
    dashboards: [main-dashboard, admin-overview]
  manager:
    dashboards: [main-dashboard]
  user:
    dashboards: [user-home]
```

Widget-level visibility can use the existing `visible_when` condition system:

```yaml
- name: admin_stats
  type: kpi_card
  visible_when:
    operator: eq
    field: current_user.role
    value: admin
```

### Dashboard as landing page

The engine configuration specifies which dashboard (or presenter) is the landing page per role:

```yaml
# config/lcp_ruby/dashboards/main.yml
landing_page_for: [admin, manager]
```

When a user logs in, the router checks their role and redirects to the matching dashboard. If no dashboard is configured, the existing behavior (first permitted presenter) is preserved.

### Routing

```
/dashboards/:slug    → dashboards#show
```

The dashboard controller resolves the definition from the slug, checks permissions, evaluates widget data, and renders the grid layout.

### Data fetching

Widgets fetch data using existing platform infrastructure — no new query language:

- **KPI cards:** `Aggregates::QueryBuilder` — COUNT, SUM, AVG, MIN, MAX on a model with optional scope
- **Table/list:** Existing presenter logic — `model.scope.limit(n)` with `IncludesResolver` for eager loading
- **Charts:** `model.scope.group(:field).count` (or sum/avg) — Chartkick handles rendering
- **Scopes:** Reference existing model scopes defined in YAML
- **Filters:** Optional Ransack predicates passed as widget config

Each widget query respects the current user's row-level permissions (scope from `PermissionEvaluator`).

### DSL alternative

```ruby
LcpRuby.define_dashboard :main do
  slug "main-dashboard"
  layout columns: 12

  widget :total_orders, type: :kpi_card, position: { row: 1, col: 1, width: 3 } do
    model :order
    aggregate :count
    scope :this_month
    link_to :orders
  end

  widget :recent_orders, type: :table, position: { row: 2, col: 1, width: 8 } do
    presenter :orders
    scope :recent
    limit 5
  end

  widget :orders_chart, type: :chart, position: { row: 2, col: 9, width: 4 } do
    chart_type :line
    model :order
    group_by :created_at, period: :month
    aggregate :count
  end
end
```

## Usage Examples

### Minimal dashboard — KPI + table

```yaml
slug: task-overview
widgets:
  - name: open_count
    type: kpi_card
    model: task
    aggregate: count
    scope: open
    position: { row: 1, col: 1, width: 4 }
    link_to: tasks

  - name: my_tasks
    type: table
    presenter: tasks
    scope: assigned_to_current_user
    limit: 10
    position: { row: 2, col: 1, width: 12 }
```

### Dashboard with charts (Tier 2)

```yaml
slug: sales-dashboard
widgets:
  - name: monthly_revenue
    type: chart
    chart_type: area
    model: order
    group_by: created_at
    group_period: month
    aggregate: sum
    aggregate_field: total_amount
    position: { row: 1, col: 1, width: 8, height: 2 }

  - name: deals_by_stage
    type: chart
    chart_type: pie
    model: deal
    group_by: stage
    aggregate: count
    position: { row: 1, col: 9, width: 4, height: 2 }
```

### Dashboard with external BI embed (Tier 3)

```yaml
slug: analytics
widgets:
  - name: quick_stats
    type: kpi_card
    model: order
    aggregate: count
    position: { row: 1, col: 1, width: 3 }

  - name: detailed_analytics
    type: embed
    provider: metabase
    resource_type: dashboard     # or question
    resource_id: 42
    position: { row: 2, col: 1, width: 12, height: 4 }
```

## General Implementation Approach

### Tiered delivery

**Tier 1 (MVP):** Native server-side widgets only — KPI cards, tables, lists, text. No JavaScript dependencies. Pure HTML + CSS grid. Data via existing `Aggregates::QueryBuilder` and presenter infrastructure. Dashboard controller, YAML loader, `DashboardDefinition` / `WidgetDefinition` value objects, permission integration, routing, menu integration.

**Tier 2:** Add `chartkick` gem (wraps Chart.js) for chart widgets. Add trend indicators on KPI cards (compare with previous period). Add auto-refresh via Turbo Frames (each widget is an independent frame). Add global dashboard filters (date range, department) that propagate to all widgets. Add `visible_when` conditions on widgets.

**Tier 3:** Embed widget type for external BI tools (Metabase, Grafana, Superset) with signed URL generation. User personalization (drag-and-drop rearrangement stored in DB). Dashboard definitions via DB (Configuration Source Principle). Dashboard builder UI.

### Hybrid architecture rationale

Building a full BI engine (interactive charts, drill-down, cross-filtering, scheduled reports) from scratch is impractical. The hybrid approach provides:

1. **Native widgets** for simple, common cases (KPI + table covers 60%+ of dashboard needs) — fast, no dependencies, consistent UI
2. **Chartkick integration** for standard charts — minimal effort (Rails gem, no build step), covers another 25%
3. **External BI embedding** for advanced analytics — users who need cross-filtering, pivot tables, or complex visualizations use purpose-built tools (Metabase, Grafana) embedded within the platform frame

This avoids reinventing BI while keeping simple dashboards declarative and integrated.

### Data pipeline

Widget data flows through existing infrastructure:

1. `DashboardController#show` loads `DashboardDefinition` from metadata
2. For each widget, a `WidgetDataResolver` fetches data based on widget type
3. KPI: `model_class.scope.aggregate` via `Aggregates::QueryBuilder`
4. Table/list: `model_class.scope.limit(n)` with presenter column selection and eager loading
5. Chart: `model_class.scope.group(field).calculate(aggregate)` — result passed to Chartkick helper
6. All queries are wrapped with the current user's permission scope from `ScopeBuilder`

### Rendering

Each widget renders as a standalone partial. In Tier 2, each widget becomes a Turbo Frame, enabling independent refresh and lazy loading of slow widgets without blocking the entire page.

### External embed providers

The embed widget uses a provider adapter pattern:

- `EmbedProviders::Metabase` — generates signed iframe URLs using Metabase's embedding secret
- `EmbedProviders::Grafana` — generates panel embed URLs with auth token
- `EmbedProviders::Custom` — host app registers a provider via `LcpRuby.configure { |c| c.register_embed_provider(:name, MyProvider) }`

Each provider implements `embed_url(resource_type:, resource_id:, params:) → String`.

## Decisions

1. **Dashboards are a separate concept, not a presenter type.** Presenters are model-scoped (1 presenter = 1 model). Dashboards aggregate across models. A new `DashboardDefinition` avoids overloading the presenter abstraction, while sharing infrastructure (permissions, routing, menu, conditions).

2. **Chartkick over raw Chart.js or D3.js.** Chartkick is a Rails-native gem with ERB helpers (`<%= line_chart data %>`), no build step, no JavaScript configuration. It wraps Chart.js for rendering. This matches the platform's server-side philosophy. If users need D3-level customization, they use the embed widget with an external tool.

3. **CSS Grid over a JavaScript grid library.** The dashboard layout is static (defined in YAML), not drag-and-drop in Tier 1. CSS Grid handles the layout natively with no dependencies. User personalization (Tier 3) would add a JS drag library only when needed.

4. **Widget data uses existing query infrastructure.** No new query language or data layer. KPI cards use `Aggregates::QueryBuilder`, tables reuse presenter column/scope logic, charts use ActiveRecord `group.calculate`. This keeps the implementation small and leverages tested code.

## Open Questions

1. **Global dashboard filters** — Should filters be a special widget type (a `filter` widget that broadcasts to others), or a top-level dashboard config (`parameters:` key)? The filter widget approach is more flexible but needs a mechanism for inter-widget communication (Turbo Frames with shared query params?).

2. **Trend comparison period** — For KPI trend indicators, how to define the comparison period? Options: `previous_period` (auto-detect from scope), explicit `compare_scope`, or `compare_range: 30_days`. The auto-detect approach is simpler but may be ambiguous.

3. **Dashboard caching** — Should widget results be cached? KPI queries on large tables can be slow. Options: fragment caching per widget with TTL, Russian doll caching tied to model `updated_at`, or leaving it to the database (materialized views). This may be premature for Tier 1.

4. **Chartkick dependency** — Should `chartkick` be a hard dependency or optional? If optional, chart widgets would raise an error when the gem is missing. Given LCP's minimal dependency philosophy, optional (with a clear error message) seems better.

5. **Configuration Source Principle timeline** — The principle requires YAML + DB + host API sources. For Tier 1, only YAML/DSL. DB source (runtime dashboard editor) is Tier 3. Should the `DashboardDefinition` value object be designed upfront to support all three sources, or evolve later? Other concepts (permissions, roles) added DB source retroactively without major refactoring.
