# Feature Specification: Pages — Unified Rendering Abstraction

**Status:** Tier 1 + Tier 1b + Tier 2 Phase A Implemented
**Date:** 2026-03-07
**Updated:** 2026-03-08 (Tier 2 Phase A: composite page rendering with semantic layout, tabs, scope_context, per-zone authorization)

## Problem / Motivation

LCP currently renders presenters directly — each URL maps to one presenter, which maps to one model. This creates two architectural limitations:

1. **No multi-presenter layouts.** Real information systems need composite screens: an employee detail page with tabs for leave requests, expense claims, and trainings — each a different model. A company 360-degree view with company details, contact list, deal pipeline, and activity feed on one screen. Today this requires custom host-app pages outside the platform.

2. **No unified rendering abstraction.** When modal dialogs are introduced, the system needs to render "something" in a modal context. That "something" could be a single presenter or a multi-presenter layout. Without a unified abstraction, every rendering context (page, dialog, drawer, embedded panel) needs branching logic for "is this a presenter or a composite layout?"

The solution is **Page** — a thin abstraction layer between the URL/trigger and the presenter(s). A page defines spatial layout (zones), and each zone renders a presenter. Every presenter always has a page (auto-created for simple cases). The rendering pipeline always renders a page — never a presenter directly.

### Relationship to other features

| Feature | Scope | Relationship |
|---------|-------|--------------|
| **Pages** | Spatial layout: zones, areas, context passing | This spec |
| **Presenters** | Content: fields, sections, actions, conditional rendering | Pages contain presenters. Presenters define WHAT is rendered. Pages define HOW it is arranged. |
| **View Groups** | Navigation: menu, breadcrumbs, view switching | View groups reference pages (not presenters directly). View groups define WHERE pages are accessed. |
| **Modal Dialogs** | Render context: modal overlay, size, lifecycle | Dialogs open a page in a modal layout instead of a full-page layout. Dialog = render context, page = content layout. See [Modal Dialogs spec](modal_dialogs.md). |
| **Dashboards** | Multi-model overview: KPIs, charts, widgets | Dashboards converge with pages. A dashboard is a standalone page (no model) with `layout: grid` and widget zones. No separate abstraction. See [Decision D14](#decisions) and [Dashboards spec](dashboards.md). |

## Core Concept

### Three-layer architecture

```
View Group  — WHERE (menu position, breadcrumbs, view switching)
  └── Page  — HOW (zones, spatial layout, context passing)
        └── Presenter(s)  — WHAT (fields, sections, actions)
```

Each layer has a single responsibility. Each has auto-creation for simple cases — no YAML needed until the configurator needs to customize that layer.

### Auto-creation chain

```
Presenter defined
  → Auto-page created (single zone, inherits slug + dialog config)
    → Auto-view-group created (single view, inherits navigation)
```

The configurator can intervene at any level:
- Write only a presenter → auto-page + auto-view-group. Everything works.
- Write a presenter + explicit page → explicit page used, auto-view-group created from page.
- Write a presenter + explicit page + explicit view group → full control.

### Slug ownership

**Slug (URL route) belongs to the page, not the presenter.**

- Auto-page inherits slug from its presenter's `slug:` field.
- Explicit page defines its own slug.
- One slug = one page (validated at boot; duplicate slugs across explicit pages are a validation error).
- When an explicit page uses the same slug as a presenter's auto-page, the explicit page wins. The auto-page loses its slug and becomes unreachable via URL (but still usable as a dialog target or zone in other pages).

Example lifecycle:

```
Phase 1: Only presenter, no explicit page
  Presenter employee_show (slug: employees)
  → Auto-page "employee_show" (slug: employees, 1 zone)
  → /employees/123 renders auto-page → single zone → employee_show

Phase 2: Configurator adds composite page with same slug
  Explicit page employee_detail (slug: employees, 3 zones)
  → Auto-page "employee_show" loses slug (explicit page took it)
  → /employees/123 renders composite page → header + tabs
  → No migration needed — just create the page YAML
```

The presenter's `slug:` field becomes "default slug for my auto-page" — a hint, not ownership.

### Slug migration impact

Today, slug lives on presenters and is used throughout the codebase. Moving slug ownership to pages affects these components:

| Component | Current | After migration | Impact |
|-----------|---------|----------------|--------|
| `Presenter::Resolver.find_by_slug` | Searches presenter definitions | Searches page definitions | Entry point change — returns page, then page resolves presenter(s) |
| `ApplicationController#set_presenter_and_model` | Sets `@presenter_definition` from slug | Sets `@page_definition` from slug; derives `current_presenter` from main zone | New `current_page` helper; see [Controller context model](#controller-context-model-tier-1-vs-tier-2) |
| 12 path helpers (`resource_path`, etc.) | Use `current_presenter.slug` | Use `current_page.slug` | Mechanical change — auto-page slug == presenter slug |
| `BreadcrumbBuilder#resolve_primary_slug` | VG → primary presenter → slug | VG → primary page → slug | Direct replacement |
| `LayoutHelper#navigable_presenters` | VG → presenter → slug, label, icon | VG → page → slug; presenter → label, icon | Rename to `navigable_entries`; slug from page, label from presenter |
| `sibling_views` (view switcher) | VG views list presenters with slugs | VG views list pages with slugs | Direct replacement |
| `SavedFiltersController#target_presenter` | Stores presenter slug | Stores presenter **name** (stable identifier, independent of slug). Lookup changes to `where(target_presenter: current_presenter.name)` | Semantic change — filters bind to presenter fields, not URL |
| `current_request_public?` | Slug → presenter → VG → public? | Slug → page → page's own VG → public? (does not descend into zone presenters' VGs) | Route through page |
| `MenuItem#resolved_slug` | VG → primary presenter → slug | VG → primary page → slug | Menu items resolve slug from page, not presenter |
| `MenuItem#contains_slug?` | Collects presenter slugs in VG | Collects page slugs in VG | Same traversal, different source |

**For Tier 1 (auto-pages only):** All changes are transparent because auto-page slug equals presenter slug. No user-visible behavior change.

**For Tier 2+ (composite pages):** See [Controller context model](#controller-context-model-tier-1-vs-tier-2).

### Controller context model (Tier 1 vs Tier 2)

**Tier 1 — single-zone auto-pages:** Every auto-page has exactly one zone with one presenter. The controller sets up the familiar context:

```
@page_definition     = find page by slug
@presenter_definition = page's main zone presenter (always exists for auto-pages)
@model_definition    = presenter's model definition
@model_class         = AR class from registry (or nil for virtual models)
current_evaluator    = PermissionEvaluator for presenter's model
```

`current_presenter` delegates to the single zone's presenter. All existing code paths (path helpers, views, ActionSet, ColumnSet) work unchanged.

**Tier 2 — multi-zone composite pages:** The controller introduces a **page-level context** and **per-zone contexts**:

```
Page-level:
  @page_definition      = find page by slug
  @model_definition     = page's primary model definition (from page.model)
  @model_class          = AR class for primary model
  @record               = primary record (from :id param)
  page_evaluator        = PermissionEvaluator for primary model

Per-zone:
  zone.presenter_definition  = zone's presenter
  zone.model_definition      = zone presenter's model
  zone.model_class           = AR class for zone's model
  zone.evaluator             = PermissionEvaluator for zone's model
  zone.records / zone.record = zone's data (fetched independently)
```

`current_presenter` returns the main zone's presenter. For pages without a main zone, `current_presenter` returns nil — this is a Tier 2 concern and all code that calls `current_presenter` must handle this (path helpers fall back to `current_page.slug`, views receive zone-specific context).

**Page-level authorization:** Uses the page's primary model permissions. `authorize_presenter_access` checks the main zone's presenter name. For pages without a model (standalone pages), authorization is based on the view group's `public:` flag or a page-level permission check.

**Zone-level authorization:** Each zone independently checks `can_access_presenter?(zone_presenter_name)` against that zone's model permissions. Zones the user cannot access are hidden.

### Virtual model handling

Virtual models (`table_name: _virtual`) are never registered in `LcpRuby.registry` — the engine skips them at boot (no AR class, no DB table). This means the standard controller pipeline (`registry.model_for(name)` → raises `MetadataError`) fails for virtual models.

**Solution:** The controller's `set_presenter_and_model` must branch for virtual models:

```ruby
def set_presenter_and_model
  # ... resolve page and presenter from slug ...
  @model_definition = LcpRuby.loader.model_definition(@presenter_definition.model)

  if @model_definition.virtual?
    @model_class = nil  # no AR class for virtual models
  else
    @model_class = LcpRuby.registry.model_for(@presenter_definition.model)
  end
end
```

Virtual model forms use `JsonItemWrapper` (existing ActiveModel wrapper with validations, type coercion, getters/setters). The `new`/`create` actions detect `@model_class.nil?` (or `current_model_definition.virtual?`) and instantiate `JsonItemWrapper` instead of AR records. Pundit authorization for virtual models uses a dedicated policy or skips model-level auth (relying on action-level permission checks).

This applies to both dialog and full-page rendering of virtual models.

### View groups reference pages

View groups reference pages, not presenters:

```yaml
view_group:
  name: employees
  model: employee
  primary: employee_detail       # page name, not presenter name
  views:
    - page: employee_detail        # composite page
    - page: employee_compact       # auto-page (from presenter)
```

### Auto-view-group creation

Current auto-VG logic: only creates when exactly one presenter exists per model. With pages, this changes:

**New logic:** For each **routable page** (has a slug) that is not referenced by any explicit view group, auto-create a VG:

```
Auto-VG name: "{page_name}_auto"
Model: page's primary model
Primary page: the page
Views: [{ page: page_name }]
Navigation: { menu: "main", position: 99 }
```

Rules:
- Only routable pages (with slug) get auto-VGs. Dialog-only pages (no slug) don't need navigation.
- If multiple routable pages exist for the same model and none has an explicit VG, each gets its own auto-VG.
- Standalone pages (no model) get auto-VGs with relaxed validation — `model` can be nil for standalone pages. The `ViewGroupDefinition` validation must be relaxed to allow `model: nil` when the page has no primary model.

### Permissions `presenters:` key with pages

Permissions YAML controls which presenter **names** a role can access via the `presenters:` key. This remains unchanged — permissions check presenter names, not page names.

For composite pages, authorization happens at two levels:
- **Page entry:** The main zone's presenter is checked via `can_access_presenter?`. If the user can't access the main zone's presenter, the entire page is denied.
- **Per zone:** Each zone's presenter is checked independently. Zones whose presenters the user can't access are hidden (the page still renders, but without those zones).

The `presenters:` permission key does **not** change to `pages:`. Pages are a layout concept, not an authorization concept. Permissions remain model+presenter-scoped.

## Configuration & Behavior

### Auto-page (implicit — no YAML needed)

When a presenter exists without an explicit page, the system auto-creates one:

```yaml
# Configurator writes only a presenter:
presenter:
  name: contacts
  model: contact
  slug: contacts
  dialog:
    size: medium
  sections:
    - name: main
      fields: [first_name, last_name, email]

# System auto-creates (conceptually):
# PageDefinition(
#   name: "contacts",
#   model: "contact",
#   slug: "contacts",
#   dialog: { size: "medium" },
#   zones: [{ name: "main", presenter: "contacts", area: "main" }]
# )
```

Note: `dialog:` is a new key on `PresenterDefinition` — `from_hash` must be extended to parse it and store it on the definition. The auto-page creation logic reads it from there.

### Explicit page — master-detail

```yaml
# config/lcp_ruby/pages/employee_detail.yml
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
      label_key: pages.employee_detail.tabs.leave
      scope_context:
        employee_id: :record_id

    - name: expense_claims
      presenter: expense_claims_index
      area: tabs
      label_key: pages.employee_detail.tabs.expenses
      scope_context:
        employee_id: :record_id

    - name: trainings
      presenter: trainings_index
      area: tabs
      label_key: pages.employee_detail.tabs.trainings
      scope_context:
        employee_id: :record_id
```

### Explicit page — order with inline list

```yaml
page:
  name: order_detail
  model: order
  slug: orders

  zones:
    - name: order_header
      presenter: order_show
      area: main

    - name: order_lines
      presenter: order_lines_index
      area: below
      scope_context:
        order_id: :record_id
```

Note: the "add line" dialog action belongs in the `order_lines_index` **presenter's** `actions_config`, not on the zone definition. Zones define layout and context passing; actions belong to presenters.

### Explicit page — company 360 with sidebar widgets

```yaml
page:
  name: company_360
  model: company
  slug: companies

  zones:
    - name: company_info
      presenter: company_show
      area: main

    - name: quick_stats
      type: widget
      widget:
        type: kpi_card
        model: deal
        aggregate: sum
        aggregate_field: value
        scope_context: { company_id: :record_id }
      area: sidebar

    - name: contacts
      presenter: contacts_index
      area: tabs
      label_key: pages.company_360.tabs.contacts
      scope_context:
        company_id: :record_id

    - name: deals
      presenter: deals_index
      area: tabs
      label_key: pages.company_360.tabs.deals
      scope_context:
        company_id: :record_id

    - name: invoices
      presenter: invoices_index
      area: tabs
      label_key: pages.company_360.tabs.invoices
      scope_context:
        company_id: :record_id
```

Widget zones (`type: widget`) are a new concept introduced in Tier 2. They don't reference a presenter — instead they render a standalone widget component with its own data query. Widget zones are not covered in Tier 1.

### Dialog-only page (no slug)

```yaml
# Presenter with dialog config, no slug → dialog-only auto-page
presenter:
  name: save_filter_dialog
  model: saved_filter
  dialog:
    size: medium
  sections:
    - name: main
      fields: [name, description, visibility, pinned]
```

No slug on the presenter → auto-page has no slug → not routable → can only be opened via dialog action.

### Composite dialog page (no slug, multi-zone)

```yaml
page:
  name: transfer_dialog
  model: inventory_transfer
  # no slug — dialog-only
  dialog:
    size: large
  zones:
    - name: source_item
      presenter: inventory_item_show
      area: sidebar
      width: 4
      record_source:
        param: source_id           # resolved from dialog context params

    - name: transfer_form
      presenter: transfer_form
      area: main
      width: 8
```

`record_source` specifies where the zone loads its record from. Unlike `scope_context` (which filters a collection), `record_source` loads a **single record** by ID from a parameter. The parameter value comes from the dialog trigger's `context:` or `defaults:`.

### Standalone page (no primary model)

```yaml
page:
  name: team_overview
  slug: team-overview
  # no model — standalone composite page

  zones:
    - name: headcount
      type: widget
      widget: { type: kpi_card, model: employee, aggregate: count, default_scope: active }
      area: main

    - name: open_positions
      presenter: positions_index
      area: below
      default_scope: open
```

`default_scope` on a zone applies a **named scope** to the zone's query before any other filtering. It is additive with the zone's presenter default scope (if any) — both are applied. This is distinct from `scope_context` (which passes parameters for parameterized scopes).

Standalone pages (no `model:`) have no primary record. `scope_context` references like `:record_id` are not available. Zones must be self-contained (own model, own scope) or use widget zones.

## Zone Areas and Layout Engine

### Areas

Zones are placed into named areas that define the visual layout:

| Area | Behavior |
|------|----------|
| `main` | Primary content area. Typically one zone. |
| `tabs` | Tabbed panel. Multiple zones render as tabs — only active tab visible. |
| `sidebar` | Side panel. Stacked vertically. |
| `below` | Below the main+tabs row. All zones visible, stacked. |

**`main` is not required.** A page can use any combination of areas:

- **Tabs-only** — all zones in `tabs`, no header. E.g., "Settings" page with tabs for Users, Roles, Groups.
- **Two-column** — zones in `sidebar` + `below`. E.g., comparison view, dual-panel dialog.
- **Single zone** — valid as a building block for dialog references.

### Zone ordering

Zones within each area render in **YAML declaration order**. For tabs, this determines the tab order left-to-right. An explicit `position` field is not needed — reorder by reordering the YAML.

### Layout engine

CSS grid, template determined by populated areas. The page grid is 12 columns. Areas claim columns via `width` on their zones:

```
# main(8) + sidebar(4)
+------------------+----------+
|     main (8)     | sidebar  |
+------------------+  (4)     |
|  tab1 | tab2 (8) |          |
+------------------+----------+

# tabs only (no main, no sidebar)
+----------------------------+
|  tab1 | tab2 | tab3  (12) |
+----------------------------+

# main + below (no sidebar)
+----------------------------+
|          main (12)         |
+----------------------------+
|         below-1 (12)       |
+----------------------------+
|         below-2 (12)       |
+----------------------------+

# sidebar + tabs (no main, e.g. dialog)
+----------+-----------------+
| sidebar  | tab1 | tab2    |
|   (4)    |      (8)       |
+----------+-----------------+
```

`width` controls how many columns of the **page-level 12-column grid** the area occupies:

```yaml
zones:
  - name: source_item
    area: sidebar
    width: 4            # sidebar area gets 4 of 12 page columns
  - name: transfer_form
    area: main
    width: 8            # main area gets 8 of 12 page columns
```

When `width` is omitted, the layout engine distributes columns automatically: if only `main` is present, it gets 12; if `main` + `sidebar`, sidebar defaults to 4 and main gets 8; etc. Multiple zones within the same area (e.g., two sidebar zones) stack vertically within the area's column allocation.

### Layout modes

Pages support two layout modes:

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Semantic** (default) | No `layout:` key, or `layout: semantic` | Zones placed into named areas (`main`, `tabs`, `sidebar`, `below`). The layout engine generates CSS grid from populated areas. |
| **Grid** | `layout: grid` | Zones use explicit `position: { row, col, width, height }`. Direct CSS grid positioning. Used for dashboard-style pages. |

Semantic mode is a higher-level abstraction over grid — `main` maps to the top-left, `sidebar` to the top-right, `tabs` below main, etc. Both modes produce CSS grid output. A page chooses one mode; mixing is a Tier 2+ capability.

```yaml
# Semantic mode — composite page
page:
  name: employee_detail
  model: employee
  slug: employees
  layout: semantic              # default when omitted, but can be stated explicitly
  zones:
    - name: header
      presenter: employee_show
      area: main
    - name: leave_requests
      presenter: leave_requests_index
      area: tabs

# Grid mode — dashboard page
page:
  name: main_dashboard
  slug: main-dashboard
  layout: grid
  zones:
    - name: total_orders
      type: widget
      widget: { type: kpi_card, model: order, aggregate: count, scope: this_month }
      position: { row: 1, col: 1, width: 3, height: 1 }
    - name: recent_orders
      type: presenter
      presenter: orders
      limit: 5
      position: { row: 2, col: 1, width: 8, height: 2 }
```

### Zone types

Each zone has a `type` that determines what it renders:

| Type | Description | Data source |
|------|-------------|-------------|
| `presenter` (default) | Renders a presenter (index, show, or form). This is the standard zone type for composite pages. | Presenter definition + model query |
| `widget` | Renders a standalone data visualization (KPI card, chart, text). Used for dashboard-style pages. | Widget-specific data resolver |

**Presenter zones** are the default (`type` can be omitted). They reference a presenter by name and render its content.

**Widget zones** use `type: widget` with a nested `widget:` block:

```yaml
zones:
  - name: revenue
    type: widget
    widget:
      type: kpi_card           # kpi_card, text, list, chart (Tier 2), embed (Tier 3)
      model: order
      aggregate: sum
      aggregate_field: total_amount
      scope: this_month
      format: currency
      link_to: orders          # click → /orders?scope=this_month
    position: { row: 1, col: 1, width: 3, height: 1 }
```

Widget types:

| Widget type | Tier | Description |
|-------------|------|-------------|
| `kpi_card` | 1 | Large number with label and optional icon. Data from `Aggregates::QueryBuilder`. Optional `link_to` for drill-down. |
| `text` | 1 | Static content from i18n key. For welcome messages, instructions, section headers. |
| `list` | 1 | Simple record list (title + subtitle fields only). |
| `chart` | 2 | Bar, line, pie, donut, area chart via Chartkick (wraps Chart.js). Data from `group_by` + `aggregate`. |
| `embed` | 3 | Iframe embedding external content (Metabase, Grafana). Signed embed URL support. |

Widget zones don't reference a presenter — they have their own data fetching logic. Widget data flows through existing infrastructure: `Aggregates::QueryBuilder` for KPIs, `ActiveRecord#group.calculate` for charts, `I18n.t` for text. All queries respect the current user's permission scope via `ScopeBuilder`.

See [Dashboards spec](dashboards.md) for full dashboard configuration examples and widget details.

## Context Passing — scope_context

Child zones receive data from the parent (primary record) via `scope_context`:

```yaml
scope_context:
  employee_id: :record_id                # parent record's ID
  department_id: :record.department_id   # dot-path into parent record
  year: :current_year                    # dynamic value
```

### Reference resolution (new infrastructure)

`scope_context` introduces a **new reference resolution layer** that does not exist in the current codebase. The resolver translates symbolic references into concrete values:

| Reference | Resolved from |
|-----------|--------------|
| `:record_id` | Primary record's `id` |
| `:record.<field>` | Dot-path into primary record (e.g., `:record.department_id` → `record.department_id`). Single-level only in Phase A. |
| `:current_user` | `current_user` object (useful with `filter_*` interceptors) |
| `:current_user_id` | `current_user.id` |
| `:current_year`, `:current_date` | `Date.current.year`, `Date.current` |
| `:selection_id` | Selected record ID from master-detail (Tier 3) |

After references are resolved to concrete values, the resulting hash (e.g., `{ employee_id: 42 }`) is applied to the child zone's query. The application strategy is:

1. **If the child model has a `filter_<key>` class method** — delegate to it. Both 2-arg `(scope, value)` and 3-arg `(scope, value, evaluator)` signatures are supported.
2. **Otherwise** — apply as `where(key: value)` directly.

This keeps the common case simple (`where(employee_id: 42)`) while supporting complex scoping via filter methods when needed.

## URL Routing and Zone State Encoding

### Primary model owns the base URL

A page with a model uses `/:slug/:id` for record-bound pages and `/:slug` for index/standalone pages. This is unchanged from the current routing. The existing `scope ":lcp_slug"` in `config/routes.rb` handles any slug dynamically — no per-page route generation needed.

### Dialog routing for slugless pages

Dialog-only pages (no slug) cannot use `/:lcp_slug/new?_dialog=1` because there is no slug to route through. Instead, dialogs use a dedicated endpoint:

```
GET  /lcp_dialog/:page_name/new?defaults[field]=value
POST /lcp_dialog/:page_name
```

The dialog controller resolves the page by **name** (not slug), loads the page's presenter and model, and renders the form in the modal layout. For pages with a slug, both routes work — the slug-based route with `?_dialog=1` and the name-based dialog route.

This requires a new route entry:

```ruby
scope "lcp_dialog/:page_name" do
  get  "/new",  to: "dialogs#new"
  post "/",     to: "dialogs#create"
  get  "/:id/edit", to: "dialogs#edit"
  patch "/:id", to: "dialogs#update"
end
```

`DialogsController` is a thin wrapper that resolves the page by name, delegates to the same CRUD logic as `ResourcesController`, and returns Turbo Stream responses for the modal context. It shares the rendering and validation logic — the only difference is page resolution (by name vs by slug) and response format (always Turbo Stream).

### Zone state encoding strategy depends on the rendering tier

The URL needs to encode which tab is active and each zone's interaction state (pagination, sort, filters). The right approach is different per tier:

#### Tier 1: Only active tab params (server-side full reload)

With full-page reload, only the active tab is rendered. Inactive tabs have no state to preserve. The URL carries the active tab identifier and that tab's parameters — unprefixed, as top-level query params:

```
/employees/123?tab=leave_requests&page=2&sort=created_at_desc
```

| Param | Meaning |
|-------|---------|
| `tab` | Which tab zone is active |
| `page`, `sort`, `q[...]` | Parameters of the active tab (standard Ransack/Kaminari) |

Tab switch = page reload with `?tab=<new_tab>`. Previous tab's state is lost. This matches the behavior users expect from server-rendered tab UIs.

Main zone (non-tab) params are also top-level. Since main zone is typically a show view (not paginated/sortable), there is no collision with tab params. **Important constraint:** in Tier 1, the main zone must not be an index presenter if tabs are present — this would cause param collisions (`page`, `sort`, `q[...]` would be ambiguous). This constraint is enforced by boot-time validation for Tier 1 pages.

**No zone-name prefixing, no nested params.** Simple URLs, standard Rails params, zero collision risk (only one tab is active at a time).

#### Tier 2: Turbo Frames — each zone has its own URL

With Turbo Frames, each zone is an independent frame with its own `src` URL. Zone state lives in the frame's URL, not in the parent page URL:

```html
<!-- Parent URL: /employees/123?tab=leave_requests -->

<div class="zone-main">
  <!-- main zone rendered inline, no frame -->
</div>

<div class="zone-tabs">
  <turbo-frame id="zone-leave_requests"
    src="/employees/123/zones/leave_requests?page=2&sort=created_at_desc">
  </turbo-frame>

  <turbo-frame id="zone-expenses"
    src="/employees/123/zones/expenses"
    loading="lazy">
    <!-- loads on tab activation -->
  </turbo-frame>
</div>
```

- **Parent URL** carries only `?tab=leave_requests` (which tab is visible)
- **Frame URL** carries that zone's full state: `/.../zones/leave_requests?page=2&sort=...`
- Pagination, sorting, filtering inside a tab = navigation within the frame, parent URL unchanged
- Tab switch = show/hide frames, lazy-load on first activation
- Previous tab's state survives switching (frame DOM is preserved)

**Zone endpoint routing:**

```
/:slug/:id/zones/:zone_name   → ZonesController#show
```

Lightweight controller — loads page definition, finds the zone, renders the zone's presenter in a zone-only layout (no page chrome). Same rendering logic as a standalone presenter page, just without navigation/breadcrumbs.

#### Tier 3: Master-detail selection

For split-view pages where an index zone's selection drives other zones:

```
/departments?selected=5&tab=employees
```

```yaml
page:
  name: department_explorer
  model: department
  slug: departments

  zones:
    - name: department_list
      presenter: departments_index
      area: sidebar
      width: 4
      selection: single               # click selects, not navigates

    - name: department_detail
      presenter: department_show
      area: main
      width: 8
      record_source: :selection       # shows the selected record

    - name: employees
      presenter: employees_index
      area: tabs
      scope_context:
        department_id: :selection_id  # scoped to selected record
```

- `?selected=5` identifies the selected record from the index zone
- Clicking a row in the list frame → JS updates `?selected=N` in parent URL + refreshes dependent frames
- Detail zone and tab zones receive `:selection_id` via `scope_context`
- Without `?selected=`, detail/tab zones are hidden or show an empty state

### Record click behavior

Configurable per zone:

```yaml
zones:
  - name: leave_requests
    presenter: leave_requests_index
    area: tabs
    scope_context:
      employee_id: :record_id
    record_click: navigate      # default — go to /leave-requests/:id
    # record_click: dialog      # open record show/edit in a dialog
    # record_click: none        # no click action (selection-only zones)
```

## Cross-Model Data Fetching

Each zone fetches data independently. No shared query context. This is intentional:

1. **Simplicity.** Same data-fetching logic as a standalone presenter page.
2. **Independent permissions.** Each zone evaluates against its own model's permissions via its own `PermissionEvaluator`.
3. **Lazy loading readiness.** Independent fetches map to Turbo Frames naturally.

The primary record (from URL) is loaded once and shared via `scope_context`. Zones do not re-fetch the parent.

| Concern | Mitigation |
|---------|------------|
| N zones = N queries | Tier 1: only active tab zone fetches. Tier 2: lazy frame loading. Sidebar widgets = fast aggregate queries. |
| Eager loading | Each zone applies `IncludesResolver` independently. |
| N+1 within zone | Handled by existing `IncludesResolver`. |

## Cross-Zone Interaction

When an action in one zone changes data that another zone displays:

**Tier 1: full page reload.** After any zone-level action, the entire page reloads. Correct, simple.

**Tier 2: explicit reload targets.** Actions in presenter YAML declare which zones to refresh via `on_success`:

```yaml
# In order_lines_index presenter's actions_config
actions:
  collection:
    - name: add_line
      type: dialog
      dialog:
        page: order_line_form
        on_success: reload_zones
        reload_zones: [order_lines, order_summary]
```

After dialog success, a Turbo Stream response replaces the specified zone frames. Unmentioned zones are untouched.

**Tier 3: model-based auto-refresh.** Zones declare data dependencies, auto-refresh when a Turbo Stream event fires for that model:

```yaml
zones:
  - name: quick_stats
    type: widget
    widget: { type: kpi_card, model: deal, aggregate: count }
    area: sidebar
    depends_on: [deal]
```

## Form Zones

**Single form zone (Tier 2):** One zone can be a form presenter on a composite page. Submits independently to its own model's endpoint. Other zones are read-only. After submit, page reloads.

```yaml
zones:
  - name: order_form
    presenter: order_edit
    area: main
    submit_redirect: self       # stay on composite page after save

  - name: order_lines
    presenter: order_lines_index
    area: below
    scope_context:
      order_id: :record_id
```

This is a Tier 2 feature because it requires explicit page YAML (composite layout with multiple zones). Tier 1 auto-pages have a single zone — the form submits through the standard CRUD flow with no special handling.

**Multi-form zones (Tier 3, if ever):** Multiple form zones submitting together ("save all") require cross-model transaction coordination. Recommended pattern: use dialogs for child record editing instead.

## Dialog Integration

### Dialog = page rendered in modal layout

A dialog opens a page (auto or explicit) in a modal rendering context instead of a full-page layout. The rendering pipeline is identical — only the layout wrapper differs. See [Modal Dialogs spec](modal_dialogs.md) for full detail.

### Dialog trigger — always references a page

```yaml
actions:
  # Single-presenter dialog (auto-page)
  - name: save_filter
    type: dialog
    dialog:
      page: save_filter_dialog
      on_success: reload

  # Composite dialog (explicit page)
  - name: transfer
    type: dialog
    dialog:
      page: transfer_dialog
      size: large                 # override page default
      on_success: reload

  # Lightweight confirmation — no page, just text + buttons
  - name: destroy
    type: built_in
    confirm:
      title_key: confirm_delete
      message_key: confirm_delete_message
      style: danger
```

Note: `type: dialog` is a new action type. The existing `ActionSet` currently recognizes `built_in` and custom actions. Dialog actions need to be added to the filter logic — they are authorized by checking `can_access_presenter?` on the dialog page's main zone presenter. The existing `BaseAction#param_schema` mechanism (which shows a form before execution) is a simpler alternative for actions that just need a few input fields — `type: dialog` replaces it for cases that need full presenter-driven forms.

### Dialog config

Pages (auto or explicit) can define dialog defaults:

```yaml
# On explicit page
page:
  name: transfer_dialog
  dialog:
    size: large
    closable: true
    title_key: dialogs.transfer.title

# On presenter (copied to auto-page)
presenter:
  name: save_filter_dialog
  dialog:
    size: medium
```

`dialog:` contains only rendering properties — size, closable, title. Not submit behavior or on_success — those belong to the caller (action).

**Resolution priority:** action override > page `dialog:` config > system defaults.

### Dialog `on_success` taxonomy

| Value | Behavior | Context |
|-------|---------|---------|
| `reload` | Reload current page | Universal |
| `close` | Close dialog, do nothing | Universal |
| `redirect` | Navigate to URL | Universal |
| `reload_zone` | Refresh the zone that triggered the dialog | Composite page (Tier 2) |
| `reload_zones` | Refresh specific zones (with `reload_zones: [a, b]`) | Composite page (Tier 2) |

The triggering zone is tracked via `origin_zone` context passed when the dialog opens. `reload_zone` without an explicit target refreshes the origin zone.

### Submit flow — existing CRUD endpoints

Dialogs for routable pages reuse existing `ResourcesController` endpoints. Dialog is a response format, not a new operation:

```
Routable page (has slug):
  GET  /:lcp_slug/new?_dialog=1
  POST /:lcp_slug

Slugless page (dialog-only):
  GET  /lcp_dialog/:page_name/new
  POST /lcp_dialog/:page_name
```

The controller detects dialog context and adjusts the response format:

```ruby
def create
  # ... existing CRUD logic (unchanged) ...
  if @record.save
    if dialog_context?
      # Turbo Stream: close modal, trigger on_success
      render turbo_stream: [
        turbo_stream.action(:close_dialog),
        turbo_stream.action(:trigger_success, on_success_config)
      ]
    else
      redirect_to resource_path(@record)  # existing behavior
    end
  else
    if dialog_context?
      # Turbo Stream: re-render form in modal with validation errors
      render turbo_stream: turbo_stream.replace(
        "dialog-content",
        partial: "lcp_ruby/resources/form",
        locals: { record: @record, layout: :dialog }
      )
    else
      render :new  # existing behavior
    end
  end
end
```

No duplicated CRUD logic. Dialog is just a response branch. `DialogsController` for slugless pages shares the same logic via a shared concern or base class.

## General Implementation Approach

### Boot-time resolution

```
1. Load presenters (YAML + DSL)
2. Load explicit pages (YAML + DSL)
3. Auto-create pages for presenters not claimed by an explicit page zone
   - Single zone: { name: "main", presenter: <name>, area: "main" }
   - Inherit slug from presenter (if no explicit page claims it)
   - Inherit dialog config from presenter
4. Resolve slug conflicts:
   - Explicit page vs auto-page: explicit wins, auto-page loses slug
   - Explicit page vs explicit page: boot-time validation error
5. Load explicit view groups (now reference pages, not presenters)
6. Auto-create view groups for routable pages without explicit VG
   - One auto-VG per routable page (not per model)
   - Standalone pages (no model): auto-VG with model: nil (relaxed validation)
   - Slugless pages: no auto-VG (not navigable)
7. Validate:
   - No duplicate slugs across all pages
   - All zone presenter references exist
   - Tier 1 pages: main zone is not an index presenter when tabs are present
   - scope_context field references exist on child models (as scopes or columns)
   - Warn on unreachable presenters (auto-page lost slug AND not used in any zone)
   - Warn if virtual model presenter references are used in non-dialog context
```

### Rendering pipeline

```
URL request:
  /:slug/:id → find page by slug → load primary record
             → page-level authorization (primary model)
             → for each visible zone:
                  check can_access_presenter?(zone_presenter)
                  resolve scope_context references from primary record
                  apply scope_context to zone query
                  fetch zone data with zone's own IncludesResolver
             → render zones in full-page layout

Zone request (Tier 2):
  /:slug/:id/zones/:zone_name → find page → find zone
    → zone-level authorization
    → render single zone in zone-only layout

Dialog request:
  /lcp_dialog/:page_name/new → find page by name
    → same zone resolution → render zones in modal layout
  (or /:lcp_slug/new?_dialog=1 for routable pages)
```

One pipeline. The difference between page, zone, and dialog is only the layout wrapper.

### Tiered delivery

**Tier 1 (MVP):**
- Auto-pages from presenters (internal concept, no user-facing page YAML yet)
- `PageDefinition` objects materialized at boot time
- Slug ownership moves to page (transparent — auto-pages inherit from presenters)
- Dialog support: action `type: dialog` opens auto-page in modal layout
- Dialog routing: `/:lcp_slug/new?_dialog=1` for routable pages, `/lcp_dialog/:page_name/new` for slugless pages
- Submit via existing CRUD endpoints with Turbo Stream dialog responses
- Virtual model dialog forms via `JsonItemWrapper`
- Confirmation dialogs (lightweight `confirm:` on actions)
- Full page reload after dialog submit (`on_success: reload`)

**Tier 1b (Dashboards) — Implemented:**
- `layout: grid` mode on pages (explicit row/col/width/height positioning)
- Widget zones (`type: widget`) with `kpi_card`, `text`, `list` widget types
- Standalone pages (no primary model) with widget zones = dashboards
- `Widgets::DataResolver` for widget data (aggregates, i18n text, limited records)
- `Widgets::PresenterZoneResolver` for presenter zones on dashboard pages
- Widget view partials (`_kpi_card`, `_text`, `_list`, `_presenter_zone`)
- Grid layout CSS template (12-column grid, responsive)
- `link_to` drill-down on KPI widgets
- Landing page per role via engine configuration (`landing_page`)
- `visible_when` conditions on zones
- Auto-created view groups for standalone pages

**Tier 2:**
- Explicit page YAML for composite layouts (master-detail, tabs, sidebar)
- `scope_context` reference resolution (new infrastructure) + parameterized scope delegation
- Per-zone authorization (independent `PermissionEvaluator` per zone)
- Turbo Frame zones: lazy tab loading, independent zone refresh
- Zone endpoint (`/:slug/:id/zones/:zone_name`) for frame `src`
- Tab state in parent URL (`?tab=X`), zone state in frame URLs
- `on_success: reload_zone` / `reload_zones` via Turbo Stream
- Chart widget type via Chartkick gem (optional dependency)
- KPI trend indicators (compare with previous period)
- Auto-refresh via Turbo Frames (each zone is an independent frame)
- `record_click: dialog` for inline child record editing
- Form zones with `submit_redirect: self`
- `record_source` for loading a zone's record from a param

**Tier 3:**
- Master-detail split view (`selection: single`, `record_source: :selection`, `?selected=N`)
- Composite dialog pages (multi-zone modals)
- Model-based auto-refresh (`depends_on`)
- Embed widget type for external BI tools (Metabase, Grafana)
- DB-stored page definitions (Configuration Source Principle)
- Page builder UI / Dashboard builder UI
- User personalization (zone rearrangement, drag-and-drop)

## Decisions

### D1: Page is a separate concept from view group and presenter

Three layers, three responsibilities:
- Presenter = content (fields, sections, actions)
- Page = layout (zones, areas, spatial arrangement)
- View Group = navigation (menu, breadcrumbs, switching)

### D2: Every presenter has a page (auto-created)

The rendering pipeline always renders a page. Auto-pages are materialized `PageDefinition` objects created at boot time, stored in `page_definitions` registry. No on-the-fly fallback logic.

### D3: Slug belongs to the page

Auto-pages inherit slug from their presenter. Explicit pages define their own slug. One slug per page (validated). Explicit page slug overrides auto-page slug for the same route. Two explicit pages with the same slug is a boot-time validation error.

### D4: View groups reference pages

View groups point to pages, not presenters. The `views:` list contains page references.

### D5: `main` area is not required

Any combination of areas is valid. Tabs-only, sidebar-only, single-zone pages are all valid. Layout engine adapts grid template based on populated areas.

### D6: Dialog always opens a page

Dialog trigger references a page (auto or explicit) via `page:` key. No separate `presenter:` vs `page:` distinction — always `page:`. Lightweight confirmations (`confirm:` on action) are the only exception — they don't need a page.

### D7: Dialog reuses existing CRUD endpoints

No separate dialog controller for routable pages. `ResourcesController` detects dialog context and returns Turbo Stream responses (close modal + on_success, or re-render with errors). Slugless (dialog-only) pages use a dedicated `DialogsController` that shares the same CRUD logic. Zero logic duplication.

### D8: Each zone fetches data independently

No shared query context. Primary record loaded once and shared via `scope_context`. Each zone runs its own queries with its own permissions and eager loading.

### D9: URL encoding strategy scales with tiers

- **Tier 1:** Active tab params only, unprefixed top-level query params. Simple URLs, no collisions (one tab active at a time, main zone is not an index).
- **Tier 2:** Parent URL carries `?tab=X` only. Zone state lives in Turbo Frame `src` URLs. No prefixing, no nesting — each frame manages its own URL independently.
- **Tier 3:** `?selected=N` for master-detail selection. Dependent frames parameterized by selection.

### D10: Cross-zone refresh is full-page reload in Tier 1

Explicit `reload_zones` via Turbo Stream in Tier 2. Model-based `depends_on` auto-refresh in Tier 3.

### D11: Actions belong to presenters, not to zones

Zones define layout and context. Actions (including dialog triggers) are part of the zone's presenter `actions_config`. No `actions:` key on zone definitions. If a zone needs different actions than the presenter's defaults, create a separate presenter variant.

### D12: Permissions remain presenter-scoped

The `presenters:` key in permissions YAML stays unchanged. Page-level authorization checks the main zone's presenter. Zone-level authorization checks each zone's presenter independently.

### D13: Virtual models require controller branching

Virtual models have no AR class and no registry entry. The controller must detect `model_definition.virtual?` and use `JsonItemWrapper` instead of AR records. Pundit authorization for virtual models uses action-level permission checks.

### D14: Dashboards converge with pages

A dashboard is a standalone page (no primary model) with `layout: grid` and widget zones. No separate `DashboardDefinition`, `DashboardController`, loader, permission key, or routing. This reuses the full pages infrastructure — permissions, menu, routing, view groups, slug ownership, dialog integration, Configuration Source Principle. Widget zones (`type: widget`) are a natural extension of the zone concept. See [Dashboards spec](dashboards.md) for full detail.

**Rationale:** Dashboards and composite pages share nearly all infrastructure (layout, routing, permissions, menu, controller). The only new concept is widget zones — zones that render standalone data visualizations (KPI cards, charts, text) instead of presenter-driven content. Keeping dashboards as a parallel concept would require duplicating the entire page stack (definition, loader, controller, permissions, menu integration) for minimal benefit. Dashboard-style pages use `layout: grid` for explicit positioning; composite pages use `layout: semantic` for area-based layout. Both are valid layout modes on the same `PageDefinition`.

### D15: Two layout modes — semantic and grid

Semantic mode (default) places zones into named areas (`main`, `tabs`, `sidebar`, `below`). Grid mode (`layout: grid`) uses explicit `position: { row, col, width, height }`. Both produce CSS grid output. A page chooses one mode. This separates the common case (composite pages with semantic areas) from the dashboard case (explicit grid positioning) without introducing a separate abstraction.

## Open Questions

1. ~~**Relationship to dashboards**~~ — **Resolved: converged.** See [Decision D14](#d14-dashboards-converge-with-pages).

2. **Zone-level search and filtering** — Should child index zones support full advanced search (filter bar, query language, saved filters)? Or only basic scope + sort? Options: (a) full support; (b) quick search only; (c) configurable per zone (`filters: full | quick | none`).

3. ~~**Conditional zones**~~ — **Resolved: implemented.** Zones support `visible_when` with a role shortcut (`visible_when: { role: admin }` or `visible_when: { role: [admin, manager] }`) and full `ConditionEvaluator` conditions (`visible_when: { field: status, operator: eq, value: active }`). Evaluated at render time against the current user context.

4. **DSL syntax** — Ruby DSL for pages:
   ```ruby
   define_page :employee_detail do
     model :employee
     slug "employees"

     zone :header, presenter: :employee_show, area: :main
     zone :leave_requests, presenter: :leave_requests_index, area: :tabs do
       label_key "pages.employee_detail.tabs.leave"
       scope_context employee_id: :record_id
     end
   end
   ```

5. **Maximum zones** — Configurable limit (default: 10) to prevent performance issues? Lazy loading mitigates cost for tab zones.

6. **Unreachable presenter warning** — When a presenter's auto-page loses its slug (because an explicit page claimed it) AND the presenter is not used as a zone in any explicit page, the presenter is unreachable. Boot-time validator should warn.

7. **Zone-level presenter overrides** — A presenter (e.g., `contacts_index`) can be a zone in multiple composite pages AND have its own auto-page. The auto-page is "this presenter rendered standalone." No conflict. But should zone-level overrides (e.g., zone-specific hidden columns, row click behavior) be possible? Or should all variation go through separate presenter definitions? Separate presenters are simpler and more explicit but may lead to presenter proliferation for minor differences.

8. ~~**Pundit policy for virtual models**~~ — **Resolved: option (b).** Virtual models skip Pundit entirely. Dialog actions use action-level permission checks (`can_access_presenter?` on the dialog page's presenter). The `DialogsController` handles authorization through the page's presenter context, not Pundit policies.
