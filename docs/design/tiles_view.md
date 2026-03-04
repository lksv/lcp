# Feature Specification: Tiles View (Index Layout)

**Status:** Proposed
**Date:** 2026-03-04

## Problem / Motivation

Index pages currently support two layouts: the default **table** and **tree**. Both are data-dense, row-oriented views optimized for scanning many records with many columns. However, many real-world information systems need a card/tile layout:

- **CRM:** Company cards with logo, name, status badge, and key metrics
- **Project management:** Project tiles showing progress bar, issue count, and deadline
- **HR:** Employee cards with avatar, department, and contact info
- **Product catalog:** Product tiles with image, price, and stock status
- **Help desk:** Ticket cards with priority badge, assignee avatar, and time-since-last-update

Card layouts are better suited when:
- Visual identification matters (images, avatars, logos)
- Records have a few key attributes rather than many uniform columns
- Users benefit from spatial arrangement over linear scanning
- Aggregate/computed values need prominent display (progress bars, counts, badges)

Without platform support, host apps must build custom view overrides, breaking the declarative YAML model.

## User Scenarios

**As a platform user configuring a CRM,** I want to define a "Companies — Cards" presenter that shows each company as a tile with its logo, name, status badge, and total revenue, so users can visually browse companies. I link this presenter to the existing "Companies — Table" presenter via a view group, so users can switch between table and card views.

**As a platform user building a project tracker,** I want project tiles to display the project name, status badge, a progress bar (from an aggregate), and the issue count — all configured in YAML without writing any Ruby code.

**As a platform user,** I want the tiles view to support sorting via a dropdown (since tiles have no column headers) and to have its own `per_page` default (fewer items per page, since cards are larger than table rows).

**As a platform user,** I want to optionally show a summary bar below the tiles grid (e.g., "Total revenue: $1.2M across 24 companies"), configurable per presenter.

## Configuration & Behavior

### Unified index `layout` key

The index page gets a unified `layout` key that determines how records are rendered. This replaces the current `tree_view: true` boolean flag and the unused `default_view` / `views_available` keys.

| `layout` value | Behavior |
|----------------|----------|
| `table` | Current default. Tabular rows with sortable column headers. |
| `tiles` | Card grid with configurable card structure. |
| `tree` | Hierarchical tree (existing `tree_view` behavior). |

When `layout` is omitted, it defaults to `table` (backward compatible — all existing presenters continue to work unchanged).

The `tree_view: true` key becomes a deprecated alias for `layout: tree`. Both forms are accepted; the validator emits a deprecation warning for `tree_view`.

The `default_view` and `views_available` keys are removed. Switching between layouts is handled by **view groups** — each layout is a separate presenter linked via a view group definition. This follows the principle: one presenter = one layout.

### Tile configuration — YAML

```yaml
# config/lcp_ruby/presenters/companies_tiles.yml
name: companies_tiles
model: company
slug: companies-cards

index:
  layout: tiles
  per_page: 12
  per_page_options: [8, 12, 24, 48]
  default_sort:
    field: name
    direction: asc

  tile:
    title_field: name
    subtitle_field: status
    subtitle_renderer: badge
    image_field: logo                     # optional — attachment or URL field
    description_field: summary            # optional — truncated text
    description_max_lines: 3              # optional — CSS line-clamp (default: 3)
    columns: 3                            # grid columns on desktop (default: 3)
    card_link: show                       # click card → show page (default: show, or false)
    actions: dropdown                     # dropdown | inline | none (default: dropdown)
    fields:                               # additional key-value fields on the card
      - { field: total_revenue, renderer: currency, options: { currency: "EUR" } }
      - { field: issues_count }
      - { field: last_activity_at, renderer: relative_date }
      - { field: health_index, renderer: progress_bar }

  sort_fields:                            # optional — fields available in sort dropdown
    - { field: name, label: "Name" }
    - { field: created_at, label: "Created" }
    - { field: total_revenue, label: "Revenue" }

  summary:                                # optional — summary bar below grid
    enabled: true
    fields:
      - { field: total_revenue, function: sum, renderer: currency, options: { currency: "EUR" } }
      - { field: id, function: count, label: "Total companies" }
```

### Tile configuration — DSL

```ruby
define_presenter :companies_tiles do
  model :company
  slug "companies-cards"

  index do
    layout :tiles
    per_page 12
    per_page_options 8, 12, 24, 48
    default_sort :name, :asc

    tile do
      title_field :name
      subtitle_field :status, renderer: :badge
      image_field :logo
      description_field :summary, max_lines: 3
      columns 3
      card_link :show
      actions :dropdown

      field :total_revenue, renderer: :currency, options: { currency: "EUR" }
      field :issues_count
      field :last_activity_at, renderer: :relative_date
      field :health_index, renderer: :progress_bar
    end

    sort_field :name, label: "Name"
    sort_field :created_at, label: "Created"
    sort_field :total_revenue, label: "Revenue"

    summary do
      field :total_revenue, function: :sum, renderer: :currency, options: { currency: "EUR" }
      field :id, function: :count, label: "Total companies"
    end
  end
end
```

### Tile card structure

A tile card has a fixed visual structure with optional zones:

```
┌──────────────────────────┐
│  ┌──────┐                │
│  │ image│  Title          │ ← title_field (required)
│  │      │  Subtitle ●     │ ← subtitle_field + renderer (optional)
│  └──────┘                │
│                          │
│  Description text that   │ ← description_field (optional, line-clamped)
│  can span multiple lines │
│  and gets truncated...   │
│                          │
│  Revenue    $1,234,567   │ ← fields (optional, key-value list)
│  Issues     42           │
│  Last seen  3 days ago   │
│  Health     ████████░░   │
│                          │
│                      [⋮] │ ← actions (dropdown/inline/none)
└──────────────────────────┘
```

- **Image** — rendered from an attachment field (Active Storage thumbnail variant) or a URL string field. Positioned at top or top-left depending on aspect ratio configuration. When absent, the card starts with the title.
- **Title** — required. Resolved via `FieldValueResolver` (supports dot-paths, templates). Clickable if `card_link: show`.
- **Subtitle** — optional. Rendered with specified renderer (typically `badge` for status fields).
- **Description** — optional. Rendered with CSS `line-clamp` truncation. Supports renderers (e.g., `truncate`, `markdown`).
- **Fields** — optional array. Each field rendered as a label-value pair, using the same `FieldValueResolver` + `RendererRegistry` pipeline as table columns and show page fields. Field labels default to the humanized field name (same convention as table column headers).
- **Actions** — record actions from `ActionSet.single_actions(record)`, rendered as a kebab dropdown menu, inline icon buttons, or hidden entirely.

### Per-page options

Both table and tiles layouts support a `per_page_options` key that enables a per-page selector in the pagination area:

```yaml
index:
  layout: table
  per_page: 25
  per_page_options: [10, 25, 50, 100]
```

When `per_page_options` is present, a small dropdown appears near the pagination controls. The selected value is passed as `?per_page=50` in the URL. The controller uses `params[:per_page]` (clamped to the allowed options list) instead of the presenter default.

When `per_page_options` is absent, no selector is shown and the presenter's `per_page` value is used (current behavior, backward compatible).

### Sort dropdown

For the tiles layout, sortable column headers are not available. Instead, a **sort dropdown** appears in the toolbar or filter bar area.

If `sort_fields` is defined, the dropdown lists those fields with their labels. If `sort_fields` is omitted, the dropdown is populated from all `tile.fields` that are known to be sortable (regular model fields and SQL-backed aggregates).

The sort dropdown uses the same URL parameters as table sorting (`?sort=field&direction=asc`), so the controller's `apply_sort` works unchanged.

The sort dropdown is also available for the table layout if `sort_fields` is explicitly defined — it appears alongside the clickable column headers. This can be useful for tables with many columns where the user wants quick access to common sort options.

### Summary bar

The summary bar displays aggregate statistics across the entire filtered result set (not per-record aggregates, but set-level computations like "sum of all visible records' revenue").

```yaml
index:
  summary:
    enabled: true
    fields:
      - { field: total_revenue, function: sum, renderer: currency, options: { currency: "EUR" } }
      - { field: id, function: count, label: "Total companies" }
      - { field: budget, function: avg, label: "Avg budget" }
```

The summary bar renders below the tiles grid (or below the table). It is a horizontal bar with labeled values. Each summary field specifies:
- `field` — the model field to aggregate
- `function` — `sum`, `avg`, `count`, `min`, `max`
- `renderer` — optional display renderer
- `label` — optional label override (defaults to "Function of Field", e.g., "Sum of total revenue")

This replaces the current per-column `summary` key on table columns with a more explicit, layout-independent configuration. The current per-column `summary` continues to work for backward compatibility in table layout (rendered in `<tfoot>`), but the new `summary` block is the recommended approach for both layouts.

### Responsive behavior

The tiles grid is responsive by default:

| `columns` value | Desktop (>1200px) | Tablet (768-1200px) | Mobile (<768px) |
|-----------------|-------------------|---------------------|-----------------|
| 4 | 4 columns | 2 columns | 1 column |
| 3 (default) | 3 columns | 2 columns | 1 column |
| 2 | 2 columns | 2 columns | 1 column |
| 1 | 1 column | 1 column | 1 column |

This is handled purely in CSS via media queries / container queries. No configuration needed — the `columns` value sets the desktop column count, breakpoints are automatic.

### Reorderable tiles

Drag-and-drop reordering is **not supported** in tiles layout in v1. If a presenter has `layout: tiles` and `reorderable: true`, the `ConfigurationValidator` emits a warning and reordering is ignored.

The architecture should accommodate future drag-and-drop tile reordering (v2) — the positioning system is layout-independent, only the drag UI needs a tile-aware implementation.

### View group integration

Switching between table and tiles is handled by defining two presenters and linking them via a view group:

```yaml
# config/lcp_ruby/view_groups.yml
company_views:
  model: company
  primary: companies
  views:
    - { presenter: companies, label: "Table", icon: "list" }
    - { presenter: companies_tiles, label: "Cards", icon: "grid" }
```

The existing view switcher component renders tab buttons. Each button navigates to the sibling presenter's slug. Query parameters (search, filters, sort, page) are preserved across the switch.

This approach requires no new UI components — the view group switcher already exists and handles everything.

### Interaction with existing features

**Sorting:** Same `apply_sort` pipeline — `?sort=field&direction=asc` URL params work for both table and tiles. The only difference is the UI: column headers (table) vs. sort dropdown (tiles).

**Filtering / search:** Unchanged. The filter bar, quick search, advanced filter, and saved filters work identically — they modify the query scope, which is layout-independent.

**Pagination:** Unchanged (Kaminari). Only `per_page` default may differ between presenters.

**Permissions:** Unchanged. `ColumnSet` filters visible fields. `ActionSet` filters visible actions per record. Both are layout-independent.

**Aggregate columns:** Tiles are a natural display for aggregates. Aggregate fields referenced in `tile.fields` are loaded via `AggregateQueryBuilder` the same way as table columns. The lazy-inclusion approach (only inject subqueries for referenced aggregates) keeps the query efficient.

**Renderers:** All existing renderers work in tile fields — `badge`, `currency`, `relative_date`, `progress_bar`, `avatar`, `image`, etc. The renderer receives a value and returns HTML, regardless of layout context.

**Eager loading:** `IncludesResolver` / `DependencyCollector` scans tile fields for dot-path references and association dependencies, same as it does for table columns.

**Empty state:** When `@records.empty?`, the same empty state message is shown regardless of layout.

**Row click / card click:** Table has `row_click` (entire row clickable). Tiles have `card_link` (entire card clickable). Same concept, different config key to allow independent control per presenter.

## Usage Examples

### Basic: Project tiles with status and deadline

```yaml
# presenters/projects_tiles.yml
name: projects_tiles
model: project
slug: projects-cards

index:
  layout: tiles
  per_page: 12
  default_sort: { field: name, direction: asc }
  tile:
    title_field: name
    subtitle_field: status
    subtitle_renderer: badge
    card_link: show
    fields:
      - { field: due_date, renderer: relative_date }
      - { field: budget, renderer: currency }
```

### With image and aggregate fields

```yaml
# presenters/companies_tiles.yml
name: companies_tiles
model: company
slug: companies-cards

index:
  layout: tiles
  per_page: 12
  tile:
    title_field: name
    subtitle_field: industry
    image_field: logo
    description_field: about
    columns: 4
    actions: dropdown
    fields:
      - { field: total_revenue, renderer: currency, options: { currency: "EUR" } }
      - { field: open_deals_count }
      - { field: last_activity_at, renderer: relative_date }
      - { field: health_score, renderer: progress_bar }

  sort_fields:
    - { field: name }
    - { field: total_revenue }
    - { field: last_activity_at }

  summary:
    enabled: true
    fields:
      - { field: total_revenue, function: sum, renderer: currency }
      - { field: id, function: count, label: "Companies" }
```

### Minimal tiles (auto-derived)

```yaml
index:
  layout: tiles
  tile:
    title_field: name
```

When only `title_field` is set, the card shows just the title and record actions. All other zones (subtitle, image, description, fields) are omitted.

### View group linking table and tiles

```yaml
# view_groups.yml
project_views:
  model: project
  primary: projects
  views:
    - { presenter: projects, label: "Table", icon: "list" }
    - { presenter: projects_tiles, label: "Cards", icon: "grid" }
```

Both presenters can have different `per_page`, `default_sort`, and field selections, but they share the same model, filters, and search configuration.

## General Implementation Approach

### Rendering pipeline

The tiles layout reuses the same rendering pipeline as the table layout. The controller's `index` action is layout-agnostic — it loads records, applies search/filter/sort/pagination, and sets up `@column_set`, `@action_set`, `@field_resolver`. The only difference is which template renders the records.

The index template checks `current_presenter.index_layout` and delegates to the appropriate partial:
- `table` → existing table rendering (inline in `index.html.erb` or extracted to `_table_index.html.erb`)
- `tiles` → new `_tiles_index.html.erb` partial
- `tree` → existing `_tree_index.html.erb` partial

### Tile field resolution

Tile fields (`title_field`, `subtitle_field`, `description_field`, `fields[].field`) are resolved using the same `FieldValueResolver.resolve(record, field_name, fk_map:)` method used by table columns. This means dot-paths (`company.name`), templates (`{first_name} {last_name}`), FK lookups, and aggregate virtual attributes all work automatically.

### ColumnSet for tiles

`ColumnSet` already filters fields by read permissions. For tiles, it needs to filter tile field references the same way. The tile config fields are extracted and checked against `permission_evaluator.readable_fields`. Non-readable fields are omitted from the card.

### Sort dropdown

The sort dropdown is a new view slot component registered in `filter_bar` or `toolbar_center`. It renders a `<select>` or button group with the configured `sort_fields`. On change, it navigates to the same URL with updated `?sort=` and `?direction=` params.

The sort dropdown is always visible for tiles layout. For table layout, it only appears when `sort_fields` is explicitly configured.

### Per-page selector

The per-page selector is a view slot component in `below_content` (near pagination). It renders a small dropdown with the configured `per_page_options`. On change, it navigates with `?per_page=N`. The controller clamps the value to the allowed options list and defaults to `per_page` if the param is invalid.

### Summary computation

Summary fields are computed from the filtered scope (before pagination) using SQL aggregate functions: `scope.sum(:field)`, `scope.average(:field)`, `scope.count`, `scope.minimum(:field)`, `scope.maximum(:field)`. This is the same approach as the existing table column summaries but with an explicit configuration block.

For aggregate model fields (not DB columns), the summary computation uses the aggregate's SQL expression directly in a wrapping query.

### CSS layout

The tiles grid uses CSS Grid with `grid-template-columns: repeat(N, 1fr)` and responsive media queries. Cards use a consistent internal structure with flexbox for vertical alignment. Class naming follows the existing convention: `.lcp-tiles-grid`, `.lcp-tile-card`, `.lcp-tile-image`, `.lcp-tile-title`, `.lcp-tile-subtitle`, `.lcp-tile-description`, `.lcp-tile-fields`, `.lcp-tile-actions`.

### Deprecation of tree_view / default_view / views_available

- `tree_view: true` → treated as `layout: tree`. The validator emits a deprecation warning.
- `default_view` → removed. Ignored with a deprecation warning.
- `views_available` → removed. Ignored with a deprecation warning. View switching is handled by view groups.

## Decisions

1. **One presenter = one layout.** No view mode switching within a single presenter. View groups handle layout switching. This keeps presenters simple and composable.

2. **Unified `layout` key replaces `tree_view` boolean.** `layout: table | tiles | tree` is cleaner than separate boolean flags per layout type. Extensible to future layouts without adding more flags.

3. **Flat card structure with role-based fields.** `title_field`, `subtitle_field`, `image_field`, `description_field` as top-level keys, plus a `fields` array for extra data. Simple to configure, covers the majority of card use cases.

4. **Sort dropdown for tiles, not sortable cards.** Tiles have no column headers. A sort dropdown in the toolbar provides the same functionality. Reuses existing `?sort=` URL params.

5. **Summary bar is layout-independent.** The `summary` config block works for both table and tiles. For tables, it replaces (and supersedes) the per-column `summary` key with a cleaner design.

6. **Per-page options are layout-independent.** The `per_page_options` key enables a per-page selector for any layout. Each presenter defines its own default and options.

7. **Reorderable tiles deferred to v2.** Drag-and-drop reordering in a grid layout requires different UX than table rows. Disabled in v1 with a validation warning.

8. **Card actions are configurable.** `actions: dropdown | inline | none` lets the user choose how record actions appear on each card.

9. **Tile fields use the same rendering pipeline.** `FieldValueResolver`, `RendererRegistry`, `ColumnSet` permission checks — all reused without modification. Tiles are a different visual arrangement of the same data pipeline.

## Open Questions / Future (v2)

1. **Card size variants** — `tile.size: small | medium | large` controlling card height/density. Small = compact (title + subtitle only), large = full card with all zones.

2. **Card color / conditional styling** — `tile.color_field: priority` or `tile.style_when: { status: { eq: overdue }, style: danger }` to visually distinguish cards by status.

3. **Drag-and-drop reordering** — Grid-aware drag-and-drop for positioned models.

4. **Masonry layout** — Variable-height cards in a masonry grid (like Pinterest). Requires a different CSS approach (or a JS library).

5. **Infinite scroll** — Alternative to pagination for tiles — load more cards as the user scrolls down. Works well with cards, less so with tables.

6. **Kanban layout** — Cards grouped by a status/category field into columns (like Trello). Could be `layout: kanban` with `group_by: status`.

7. **Card templates / custom partials** — `tile.partial: "my_custom_card"` for host apps that need full control over card HTML while still using the platform's data pipeline.

8. **Aggregates in tile summary** — When aggregate columns land, tile summary bar could reference model-level aggregates in addition to SQL functions on plain fields.

## Planned Future Layouts

Beyond tiles, the following index layouts are planned for future versions. Each will follow the same architecture: a dedicated `layout` value, a layout-specific config block under `index:`, and full reuse of the existing rendering pipeline (FieldValueResolver, RendererRegistry, ColumnSet, ActionSet). View groups handle switching between layouts.

| Layout | `layout` value | Description |
|--------|---------------|-------------|
| **Kanban** | `kanban` | Cards grouped by a status/category field into drag-and-drop columns (Trello-style). Config: `group_by` field, column ordering, WIP limits. |
| **Calendar** | `calendar` | Records displayed on a monthly/weekly/daily calendar grid. Config: `date_field` (or `start_field` + `end_field` for ranges), `title_field`, color mapping. |
| **Gallery** | `gallery` | Image-first grid optimized for visual content — larger thumbnails than tiles, lightbox preview. Config: `image_field`, `caption_field`, aspect ratio. Suitable for product catalogs, document previews, media libraries. |
| **Map** | `map` | Records with geolocation data plotted on an interactive map. Config: `latitude_field`, `longitude_field` (or `location_field`), marker styling, clustering. |
| **Board** | `board` | Two-dimensional swimlane grid — rows and columns defined by different fields (e.g., rows = team, columns = status). A generalization of kanban for resource planning and matrix views. |
| **Timeline** | `timeline` | Chronological vertical axis with records displayed as events or milestones. Config: `date_field`, `title_field`, `description_field`. Suitable for activity history, audit logs, project milestones. |
| **Dashboard** | `dashboard` | Aggregate-only view with KPI widgets, charts, and summary statistics instead of individual records. Config: widget definitions with aggregate functions, chart types, and layout grid. |

These layouts will be introduced incrementally. The unified `layout` key and one-presenter-per-layout principle ensure that adding a new layout requires no changes to existing presenters or the core rendering pipeline.
