# Feature Specification: Dashboards (via Pages)

**Status:** Tier 1b Implemented
**Date:** 2026-03-06
**Updated:** 2026-03-07

**Architectural decision:** Dashboards are **not** a separate metadata concept. A dashboard is a **standalone page** (no primary model) with **widget zones** and `layout: grid`. This eliminates a parallel abstraction (`DashboardDefinition`, `DashboardController`, dashboard-specific loader, permissions key, routing) and reuses the full Pages infrastructure — permissions, menu, routing, view groups, slug ownership, dialog integration.

See [Pages spec](composite_pages_v2.md) for the page abstraction, layout modes, and widget zone types.

## Problem / Motivation

LCP currently generates CRUD presenters — index (table/tiles/tree), show, and form views. All of them are scoped to a single model. There is no way to build an overview page that aggregates data from multiple models, shows KPI metrics, charts, or recent activity across the system.

Real-world information systems need dashboards:

- **CRM:** Pipeline value, deals closed this month, top customers, activity feed
- **Project management:** Open issues count, burndown chart, overdue tasks, team workload
- **HR:** Headcount by department, open positions, upcoming reviews, attrition trend
- **Help desk:** Tickets by status, average resolution time, SLA compliance, recent escalations
- **E-shop:** Revenue today, orders by status, top products, stock alerts

Without platform-level dashboard support, host apps must build custom pages outside the declarative YAML model, losing permissions, routing, menu integration, and the consistent UI.

## Why Dashboards Converge with Pages

The original design proposed dashboards as a parallel metadata concept with their own `DashboardDefinition`, controller, loader, and permission key. However, dashboards and composite pages share nearly all infrastructure:

| Concern | Dashboard (original) | Standalone Page (converged) |
|---------|---------------------|-----------------------------|
| Definition object | `DashboardDefinition` (new) | `PageDefinition` (existing) |
| Layout | CSS grid with row/col/width/height | `layout: grid` mode on page (new) |
| Content units | Widgets | Widget zones (`type: widget`) |
| Table/list content | References presenter | Presenter zone (`type: presenter`) |
| Routing | `/dashboards/:slug` (new) | `/:slug` (existing page routing) |
| Permissions | New `dashboards:` permission key | Existing `presenters:` key per zone |
| Menu | New menu item type | Existing view group menu integration |
| Controller | `DashboardsController` (new) | Page rendering in `ResourcesController` |
| YAML location | `config/lcp_ruby/dashboards/` (new) | `config/lcp_ruby/pages/` (existing) |
| Config Source Principle | Separate implementation needed | Inherits from pages |

Convergence eliminates an entire parallel stack. The only new concept is **widget zones** — zones with `type: widget` that render standalone data visualizations instead of presenter-driven content. Widget zones are a natural extension of the existing zone concept.

## User Scenarios

**As a platform configurator,** I want to define a dashboard in YAML that shows KPI cards (total orders, open tasks, revenue this month) and a table of recent records, so that users see an at-a-glance overview when they log in.

**As an admin,** I want different roles to see different dashboards as their landing page — managers see KPIs and charts, regular users see their assigned tasks and recent activity.

**As a platform configurator,** I want to add a chart widget (orders by month, deals by stage) to the dashboard without writing any JavaScript — just YAML configuration referencing existing models and scopes.

**As a platform configurator,** I want to embed an external BI tool (Metabase, Grafana) into a dashboard widget for advanced analytics, while keeping simple widgets native to the platform.

**As a user,** I want to click on a KPI number and be taken to the filtered index page showing the underlying records (e.g., click "47 open tasks" and see those 47 tasks).

## Configuration & Behavior

### Dashboard as a standalone page

A dashboard is a page without a primary model, using grid layout:

```yaml
# config/lcp_ruby/pages/main_dashboard.yml
page:
  name: main_dashboard
  slug: main-dashboard
  title_key: dashboards.main.title    # i18n key, fallback: "Main Dashboard"
  # no model — standalone page
  layout: grid                        # explicit grid positioning (row/col/width/height)

  zones:
    - name: total_orders
      type: widget
      widget:
        type: kpi_card
        model: order
        aggregate: count
        scope: this_month
        icon: shopping-cart
        link_to: orders               # click → /orders?scope=this_month
      position: { row: 1, col: 1, width: 3, height: 1 }

    - name: open_tasks
      type: widget
      widget:
        type: kpi_card
        model: task
        aggregate: count
        scope: open
        link_to: tasks
      position: { row: 1, col: 4, width: 3, height: 1 }

    - name: revenue
      type: widget
      widget:
        type: kpi_card
        model: order
        aggregate: sum
        aggregate_field: total_amount
        scope: this_month
        format: currency
      position: { row: 1, col: 7, width: 3, height: 1 }

    - name: notes
      type: widget
      widget:
        type: text
        content_key: dashboards.main.welcome_note
      position: { row: 1, col: 10, width: 3, height: 1 }

    - name: recent_orders
      type: presenter
      presenter: orders               # reuse existing presenter's columns
      scope: recent
      limit: 5
      position: { row: 2, col: 1, width: 8, height: 2 }

    - name: orders_by_month
      type: widget
      widget:
        type: chart
        chart_type: line              # bar, line, pie, donut, area
        model: order
        group_by: created_at
        group_period: month
        aggregate: count
      position: { row: 2, col: 9, width: 4, height: 2 }
```

### Widget zone types

Widget zones use `type: widget` with a nested `widget:` block that specifies the widget type and its data source:

| Widget type | Tier | Description |
|-------------|------|-------------|
| `kpi_card` | 1 | Large number with label and optional icon. Data from aggregate query on a model + scope. Optional `link_to` for drill-down to filtered index. |
| `table` | 1 | Alias for a presenter zone with `limit`. References an existing presenter (reuses its column definitions). Configurable `scope`, `limit`, and optional `link_to` for "view all". Equivalent to `type: presenter` with `limit:`. |
| `list` | 1 | Simple record list (compact variant of table — title + subtitle fields only). |
| `text` | 1 | Static content from i18n key. For welcome messages, instructions, section headers. |
| `chart` | 2 | Bar, line, pie, donut, area chart. Rendered via Chartkick gem (wraps Chart.js). Data from `group_by` + `aggregate` on a model. |
| `embed` | 3 | Iframe embedding external content (Metabase dashboard, Grafana panel, custom URL). Signed embed URL support. |

**Note:** `type: presenter` zones (existing concept) also work on dashboard pages. A presenter zone on a dashboard renders a compact index table — the same infrastructure as a regular index page, just embedded in a grid cell with an optional `limit` and `scope`. This means a "table widget" is simply a presenter zone.

### Grid layout

Dashboard pages use `layout: grid` which switches from semantic areas (`main`, `tabs`, `sidebar`, `below`) to explicit CSS grid positioning. Each zone specifies `position: { row, col, width, height }`. The grid uses 12 columns by default.

On smaller screens, zones stack vertically (responsive fallback via CSS media queries).

See [Pages spec — Layout modes](composite_pages_v2.md#layout-modes) for the full layout system.

### Permissions

Dashboard pages use the standard page permission model — no new `dashboards:` permission key needed.

**Page-level access:** A standalone page (no model) uses view group visibility. The view group's `public:` flag or `visible_when:` conditions control who sees the page in the menu and can access it.

**Zone-level access:** Each zone independently checks access:
- **Presenter zones** — check `can_access_presenter?(zone_presenter_name)` via the zone's model permissions. Zones the user can't access are hidden.
- **Widget zones** — check the user's permission scope for the widget's model. KPI/chart widgets that reference a model apply `ScopeBuilder` to their queries, ensuring users only see data they're authorized to see. If the user has no access to the widget's model at all, the widget zone is hidden.
- **Text/embed widgets** — always visible (no model). Use `visible_when` conditions for role-based visibility.

Widget-level visibility can use the existing `visible_when` condition system:

```yaml
- name: admin_stats
  type: widget
  visible_when:
    operator: eq
    field: current_user.role
    value: admin
  widget:
    type: kpi_card
    model: order
    aggregate: count
```

### Dashboard as landing page

The engine configuration specifies which page is the landing page per role:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.landing_page = {
    admin: "main-dashboard",      # page slug
    manager: "main-dashboard",
    default: "tasks"              # falls back to first permitted page
  }
end
```

When a user logs in, the router checks their role and redirects to the matching page. If no landing page is configured, the existing behavior (first permitted presenter) is preserved.

### Routing

Dashboard pages use standard page routing — no separate `/dashboards/` prefix:

```
/main-dashboard    → page rendered via existing ResourcesController
```

The page slug is the URL. The page controller detects a standalone page (no model) and renders the grid layout with its zones instead of a standard CRUD view.

### Data fetching

Widget zones fetch data using existing platform infrastructure — no new query language:

- **KPI cards:** `Aggregates::QueryBuilder` — COUNT, SUM, AVG, MIN, MAX on a model with optional scope
- **Presenter zones (table/list):** Existing presenter logic — `model.scope.limit(n)` with `IncludesResolver` for eager loading
- **Charts:** `model.scope.group(:field).count` (or sum/avg) — Chartkick handles rendering
- **Scopes:** Reference existing model scopes defined in YAML
- **Filters:** Optional Ransack predicates passed as widget config

Each widget query respects the current user's row-level permissions (scope from `ScopeBuilder`).

### DSL alternative

Pages DSL extended with widget zone support:

```ruby
LcpRuby.define_page :main_dashboard do
  slug "main-dashboard"
  layout :grid

  zone :total_orders, type: :widget, position: { row: 1, col: 1, width: 3 } do
    widget type: :kpi_card, model: :order, aggregate: :count, scope: :this_month
    link_to :orders
  end

  zone :recent_orders, type: :presenter, position: { row: 2, col: 1, width: 8 } do
    presenter :orders
    scope :recent
    limit 5
  end

  zone :orders_chart, type: :widget, position: { row: 2, col: 9, width: 4 } do
    widget type: :chart, chart_type: :line, model: :order do
      group_by :created_at, period: :month
      aggregate :count
    end
  end
end
```

## Usage Examples

### Minimal dashboard — KPI + table

```yaml
page:
  name: task_overview
  slug: task-overview
  layout: grid

  zones:
    - name: open_count
      type: widget
      widget:
        type: kpi_card
        model: task
        aggregate: count
        scope: open
        link_to: tasks
      position: { row: 1, col: 1, width: 4, height: 1 }

    - name: my_tasks
      type: presenter
      presenter: tasks
      scope: assigned_to_current_user
      limit: 10
      position: { row: 2, col: 1, width: 12, height: 2 }
```

### Dashboard with charts (Tier 2)

```yaml
page:
  name: sales_dashboard
  slug: sales-dashboard
  layout: grid

  zones:
    - name: monthly_revenue
      type: widget
      widget:
        type: chart
        chart_type: area
        model: order
        group_by: created_at
        group_period: month
        aggregate: sum
        aggregate_field: total_amount
      position: { row: 1, col: 1, width: 8, height: 2 }

    - name: deals_by_stage
      type: widget
      widget:
        type: chart
        chart_type: pie
        model: deal
        group_by: stage
        aggregate: count
      position: { row: 1, col: 9, width: 4, height: 2 }
```

### Dashboard with external BI embed (Tier 3)

```yaml
page:
  name: analytics
  slug: analytics
  layout: grid

  zones:
    - name: quick_stats
      type: widget
      widget:
        type: kpi_card
        model: order
        aggregate: count
      position: { row: 1, col: 1, width: 3, height: 1 }

    - name: detailed_analytics
      type: widget
      widget:
        type: embed
        provider: metabase
        resource_type: dashboard
        resource_id: 42
      position: { row: 2, col: 1, width: 12, height: 4 }
```

### Mixed dashboard — KPIs + composite tabs

A page can combine grid-positioned widget zones in one area with semantic areas elsewhere. However, for simplicity, Tier 1 dashboard pages use `layout: grid` exclusively. Mixing grid and semantic areas is a Tier 2+ capability.

For now, if you need KPIs above a tabbed view, use two pages: a dashboard page for the KPIs, and a composite page with tabs for the detail views. Or combine them in a single page once Tier 2 mixed layout is available.

## General Implementation Approach

### What is new (beyond existing pages infrastructure)

1. **Widget zone rendering** — `WidgetRenderer` classes: `KpiCardRenderer`, `TextRenderer`, `ListRenderer`. Each receives the zone's `widget:` config, fetches data, and returns HTML.
2. **`WidgetDataResolver`** — resolves widget data based on type:
   - KPI: `model_class.scope.aggregate` via `Aggregates::QueryBuilder`
   - Table/list: `model_class.scope.limit(n)` with presenter column selection
   - Chart: `model_class.scope.group(field).calculate(aggregate)` → Chartkick helper
   - Text: `I18n.t(content_key)`
3. **Grid layout template** — CSS grid partial for `layout: grid` pages. Zones rendered into `grid-row` / `grid-column` based on `position:` config.
4. **Standalone page controller branch** — `ResourcesController` detects `current_page.model.nil?` (standalone) and renders the page layout instead of CRUD views.
5. **`link_to` drill-down** — KPI widget generates an `<a>` tag pointing to the referenced page slug with scope as query param.

### What is reused from existing pages infrastructure

- `PageDefinition`, `ZoneDefinition` (extended with `type`, `widget`, `position`)
- `Pages::Resolver` (slug lookup)
- Page routing, view groups, menu integration
- Permission evaluation (zone-level `can_access_presenter?`)
- `IncludesResolver` for presenter zones
- `ScopeBuilder` for row-level permission scoping on widget queries
- `ConditionEvaluator` for `visible_when` on zones

### Tiered delivery

**Tier 1 (MVP):** Native server-side widgets only — KPI cards, text, presenter-based tables. No JavaScript dependencies. Pure HTML + CSS grid. Data via existing `Aggregates::QueryBuilder` and presenter infrastructure. Widget renderers, `WidgetDataResolver`, grid layout template, standalone page controller branch.

**Tier 2:** Add `chartkick` gem (wraps Chart.js) for chart widgets. Add trend indicators on KPI cards (compare with previous period). Add auto-refresh via Turbo Frames (each zone is an independent frame). Add global page filters (date range, department) that propagate to all zones. Add `visible_when` conditions on zones.

**Tier 3:** Embed widget type for external BI tools (Metabase, Grafana, Superset) with signed URL generation. User personalization (drag-and-drop rearrangement stored in DB). Page definitions via DB (Configuration Source Principle). Dashboard builder UI.

### Hybrid architecture rationale

Building a full BI engine (interactive charts, drill-down, cross-filtering, scheduled reports) from scratch is impractical. The hybrid approach provides:

1. **Native widgets** for simple, common cases (KPI + table covers 60%+ of dashboard needs) — fast, no dependencies, consistent UI
2. **Chartkick integration** for standard charts — minimal effort (Rails gem, no build step), covers another 25%
3. **External BI embedding** for advanced analytics — users who need cross-filtering, pivot tables, or complex visualizations use purpose-built tools (Metabase, Grafana) embedded within the platform frame

This avoids reinventing BI while keeping simple dashboards declarative and integrated.

### External embed providers

The embed widget uses a provider adapter pattern:

- `EmbedProviders::Metabase` — generates signed iframe URLs using Metabase's embedding secret
- `EmbedProviders::Grafana` — generates panel embed URLs with auth token
- `EmbedProviders::Custom` — host app registers a provider via `LcpRuby.configure { |c| c.register_embed_provider(:name, MyProvider) }`

Each provider implements `embed_url(resource_type:, resource_id:, params:) -> String`.

## Decisions

### D1: Dashboards converge with pages

A dashboard is a standalone page with `layout: grid` and widget zones. No separate `DashboardDefinition`, controller, loader, or permission key. This reuses the full pages stack and avoids a parallel abstraction. See [Pages spec, Decision D15](composite_pages_v2.md#decisions).

### D2: Chartkick over raw Chart.js or D3.js

Chartkick is a Rails-native gem with ERB helpers (`<%= line_chart data %>`), no build step, no JavaScript configuration. It wraps Chart.js for rendering. This matches the platform's server-side philosophy. If users need D3-level customization, they use the embed widget with an external tool.

### D3: CSS Grid over a JavaScript grid library

The dashboard layout is static (defined in YAML), not drag-and-drop in Tier 1. CSS Grid handles the layout natively with no dependencies. User personalization (Tier 3) would add a JS drag library only when needed.

### D4: Widget data uses existing query infrastructure

No new query language or data layer. KPI cards use `Aggregates::QueryBuilder`, tables reuse presenter column/scope logic, charts use ActiveRecord `group.calculate`. This keeps the implementation small and leverages tested code.

### D5: Chartkick is an optional dependency

Chart widget zones raise a clear error if the `chartkick` gem is not installed. Given LCP's minimal dependency philosophy, this avoids adding a hard dependency for a Tier 2 feature. KPI/table/text widgets work without any additional gems.

## Open Questions

1. ~~**Global page filters**~~ — **Resolved: top-level `parameters:` key, deferred to Tier 2+.** A top-level `parameters:` key on the page definition is simpler than a filter zone and avoids inter-zone communication complexity. Parameters are passed as query params and propagated to all zone queries. The filter zone approach (broadcasting) is not needed — parameters are resolved once at page level and injected into each zone's scope. Implementation deferred until composite pages (Tier 2) are stable.

2. ~~**Trend comparison period**~~ — **Resolved: explicit `compare_scope`.** The widget config uses `compare_scope:` to reference a named scope on the same model (e.g., `compare_scope: last_month` alongside `scope: this_month`). Auto-detection from scope names is fragile and ambiguous. Explicit scopes are consistent with the existing scope system and give the configurator full control over the comparison window.

3. ~~**Dashboard caching**~~ — **Resolved: deferred to Tier 3.** Premature for Tier 2. Lazy loading (Turbo Frames) and independent zone queries already mitigate the cost. When caching becomes necessary, fragment caching per zone with configurable TTL (`cache: { ttl: 5_minutes }` on the zone) is the recommended approach. Database-level solutions (materialized views) are the host app's responsibility.
