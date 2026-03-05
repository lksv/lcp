# Feature Specification: Timeline View (Index Layout)

**Status:** Proposed
**Date:** 2026-03-05

## Problem / Motivation

The platform now supports three index layouts: **table**, **tiles**, and **tree**. These all display records as a flat or hierarchical list. However, many business domains have inherently chronological data where the time dimension is the primary organizing principle:

- **Audit logs:** A chronological history of changes to a record, grouped by day
- **Activity feeds:** Recent interactions with a customer — emails, calls, meetings, notes
- **Project milestones:** Key dates and deliverables on a vertical timeline
- **Incident management:** Ticket history — creation, escalation, resolution, with timestamps
- **HR:** Employee lifecycle events — hiring, promotions, transfers, reviews

For such data, a table sorted by date works but loses the temporal context. Users have to mentally reconstruct the chronological narrative from rows. A dedicated **timeline layout** presents records as events on a vertical time axis, making temporal patterns immediately visible — gaps, clusters, sequences.

The timeline layout is architecturally close to tiles: each event is a card, and the rendering pipeline (FieldValueResolver, RendererRegistry, ColumnSet, ActionSet) is fully reusable. The main difference is the visual arrangement: a vertical axis with date group headers instead of a grid.

## User Scenarios

**As a platform user building a CRM,** I want to define an "Activities — Timeline" presenter that shows customer interactions (calls, emails, meetings) on a vertical timeline grouped by day, so sales reps can quickly see the full history of a customer relationship.

**As a platform user configuring an audit log viewer,** I want audit entries displayed as a timeline with the change date, action type badge, user name, and a summary of changed fields — so administrators can visually trace who changed what and when.

**As a platform user building a project tracker,** I want project milestones displayed as timeline events showing the milestone name, due date, status badge, and assigned person — so project managers can see the project's chronological plan at a glance.

**As a platform user,** I want the timeline to group events by a configurable time period (day, month, year) with group headers, so I can quickly navigate through long histories.

**As a platform user,** I want to link the timeline presenter to an existing table presenter via a view group, so users can switch between table and timeline views of the same data.

## Configuration & Behavior

### Layout key

```yaml
index:
  layout: timeline
```

Follows the unified `layout` key established by the tiles feature. All existing features (filtering, search, pagination, permissions, sort dropdown, per-page selector, summary bar) work identically.

### Timeline configuration — YAML

```yaml
# config/lcp_ruby/presenters/activities_timeline.yml
name: activities_timeline
model: activity
slug: activities-timeline

index:
  layout: timeline
  per_page: 30
  per_page_options: [15, 30, 50, 100]
  default_sort:
    field: performed_at
    direction: desc

  timeline:
    date_field: performed_at                  # required — field used for the time axis
    group_by: day                             # day | week | month | year (default: day)
    title_field: subject                      # required — event title
    subtitle_field: activity_type             # optional — e.g., "Call", "Email", "Meeting"
    subtitle_renderer: badge                  # optional — renderer for subtitle
    description_field: notes                  # optional — event body text
    description_max_lines: 3                  # optional — CSS line-clamp (default: 3)
    icon_field: activity_type                 # optional — field driving the timeline marker icon
    card_link: show                           # show | edit | false (default: show)
    actions: dropdown                         # dropdown | inline | none (default: dropdown)
    fields:                                   # optional — additional key-value fields on the event card
      - { field: contact.name, label: "Contact" }
      - { field: performed_by, label: "Rep" }
      - { field: duration_minutes, label: "Duration", renderer: number, options: { suffix: " min" } }

  sort_fields:
    - { field: performed_at, label: "Date" }
    - { field: created_at, label: "Created" }

  summary:
    enabled: true
    fields:
      - { field: id, function: count, label: "Total activities" }
      - { field: duration_minutes, function: sum, label: "Total duration" }
```

### Timeline configuration — DSL

```ruby
define_presenter :activities_timeline do
  model :activity
  slug "activities-timeline"

  index do
    layout :timeline
    per_page 30
    per_page_options 15, 30, 50, 100
    default_sort :performed_at, :desc

    timeline do
      date_field :performed_at
      group_by :day
      title_field :subject
      subtitle_field :activity_type, renderer: :badge
      description_field :notes, max_lines: 3
      icon_field :activity_type
      card_link :show
      actions :dropdown

      field :contact_name, label: "Contact"   # dot-path shorthand
      field :performed_by, label: "Rep"
      field :duration_minutes, label: "Duration", renderer: :number, options: { suffix: " min" }
    end

    sort_field :performed_at, label: "Date"
    sort_field :created_at, label: "Created"

    summary do
      field :id, function: :count, label: "Total activities"
      field :duration_minutes, function: :sum, label: "Total duration"
    end
  end
end
```

### Timeline card structure

A timeline event card has a fixed visual structure:

```
    2026-03-04 (Tuesday)                      <-- group header
    ─────────────────────────────────────

    o── Meeting with Acme Corp              <-- marker + title (card_link → show)
    │   Call  ●                             <-- subtitle + renderer
    │
    │   Discussed Q2 renewal terms and      <-- description (line-clamped)
    │   pricing adjustments for the...
    │
    │   Contact    John Smith               <-- fields (key-value list)
    │   Rep        Jane Doe
    │   Duration   45 min
    │                                [⋮]    <-- actions (dropdown/inline/none)
    │
    o── Follow-up email sent
    │   Email  ●
    │   ...

    2026-03-03 (Monday)                      <-- next group header
    ─────────────────────────────────────

    o── Initial discovery call
    │   ...
```

- **Group header** — date label formatted by `group_by` granularity. `day` shows full date, `week` shows "Week of Mar 3, 2026", `month` shows "March 2026", `year` shows "2026".
- **Timeline marker** — a dot/circle on the vertical axis line. When `icon_field` is configured, the marker can display a small icon derived from the field value (using a simple icon mapping defined in the presenter or a renderer).
- **Title** — required. Resolved via `FieldValueResolver`. Clickable if `card_link: show`.
- **Subtitle** — optional. Rendered with specified renderer (typically `badge` for type/status).
- **Description** — optional. CSS `line-clamp` truncation, same as tiles.
- **Fields** — optional array. Label-value pairs, same rendering pipeline as tiles.
- **Actions** — record actions, same as tiles (dropdown/inline/none).

### Group headers

Records are grouped by the `date_field` value according to the `group_by` granularity:

| `group_by` | Grouping key | Header format |
|------------|-------------|---------------|
| `day` (default) | Date part of the field | "March 4, 2026 (Tuesday)" |
| `week` | ISO week start (Monday) | "Week of March 3, 2026" |
| `month` | Year + month | "March 2026" |
| `year` | Year | "2026" |

Grouping is performed in the template from already-sorted, paginated records. The controller does **not** add extra queries for grouping — it is purely a display concern. Records with a nil `date_field` value are placed in a "No date" group at the end (or beginning, depending on sort direction).

### Sort direction and timeline

Timeline works naturally with both `asc` (oldest first — chronological) and `desc` (newest first — reverse chronological). The default sort should typically be on the `date_field` but is not restricted to it — the user can sort by any field, the grouping always uses `date_field`.

### Icon field mapping

When `icon_field` is set, the timeline marker can display an icon based on the field value. This uses a simple mapping in the timeline config:

```yaml
timeline:
  icon_field: activity_type
  icon_map:
    call: phone
    email: envelope
    meeting: calendar
    note: file-text
```

When `icon_map` is omitted, the marker is always a plain dot. The icon names follow the same convention used elsewhere in the platform (e.g., menu icons). This is a visual-only enhancement — if the mapping is missing for a value, it falls back to the dot.

### Interaction with existing features

All interactions documented for tiles apply identically to timeline:

- **Sorting:** Same `?sort=&direction=` URL params. Sort dropdown visible by default.
- **Filtering / search:** Unchanged — layout-independent.
- **Pagination:** Unchanged (Kaminari). Note: a group header might span a page boundary (e.g., the last records of "March 4" are on page 1, and the first records of "March 4" are on page 2). This is expected and acceptable — the group header simply repeats on the next page.
- **Permissions:** ColumnSet filters timeline fields same as tile fields.
- **Renderers:** All existing renderers work in timeline fields.
- **Eager loading:** DependencyCollector scans timeline field references.
- **Summary bar:** Works unchanged.
- **Per-page selector:** Works unchanged.
- **View groups:** Timeline is just another presenter in a view group.
- **Empty state:** Same empty state message.

### Responsive behavior

On mobile (<768px), the timeline vertical axis line moves to the left edge and cards take full width. The group header becomes a sticky element so users always know which date period they are looking at while scrolling. No configuration needed — handled purely in CSS.

## Usage Examples

### Basic: Audit log timeline

```yaml
name: audit_timeline
model: audit_log
slug: audit-history

index:
  layout: timeline
  per_page: 50
  default_sort: { field: created_at, direction: desc }
  timeline:
    date_field: created_at
    group_by: day
    title_field: action_summary
    subtitle_field: action
    subtitle_renderer: badge
    fields:
      - { field: user_snapshot_name, label: "User" }
      - { field: changes_summary, label: "Changes" }
```

### With icon mapping and view group

```yaml
# presenters/activities_timeline.yml
name: activities_timeline
model: activity
slug: activities-timeline

index:
  layout: timeline
  per_page: 30
  default_sort: { field: performed_at, direction: desc }
  timeline:
    date_field: performed_at
    group_by: day
    title_field: subject
    subtitle_field: activity_type
    subtitle_renderer: badge
    description_field: notes
    card_link: show
    icon_field: activity_type
    icon_map:
      call: phone
      email: envelope
      meeting: calendar
      note: file-text
    fields:
      - { field: contact.name }
      - { field: duration_minutes, renderer: number, options: { suffix: " min" } }
```

```yaml
# view_groups.yml
activity_views:
  model: activity
  primary: activities
  views:
    - { presenter: activities, label: "Table", icon: "list" }
    - { presenter: activities_timeline, label: "Timeline", icon: "clock" }
```

### Monthly grouped milestones

```yaml
name: milestones_timeline
model: milestone
slug: milestones

index:
  layout: timeline
  per_page: 20
  default_sort: { field: due_date, direction: asc }
  timeline:
    date_field: due_date
    group_by: month
    title_field: name
    subtitle_field: status
    subtitle_renderer: badge
    card_link: show
    fields:
      - { field: assignee.name, label: "Owner" }
      - { field: budget, renderer: currency }
```

### Minimal timeline

```yaml
index:
  layout: timeline
  timeline:
    date_field: created_at
    title_field: name
```

Only `date_field` and `title_field` are required. The timeline shows a simple list of dated events with titles. No subtitle, description, icons, or extra fields.

## General Implementation Approach

### Rendering pipeline

Identical to tiles. The controller's `index` action is layout-agnostic. The index template checks `current_presenter.index_layout` and for `:timeline` delegates to a new `_timeline_index.html.erb` partial.

### Template grouping

The timeline partial receives the same `@records` collection as table/tiles. It groups records in the template using `group_by` on the `date_field` value:

1. For each record, resolve the `date_field` value via `FieldValueResolver`
2. Truncate to the configured granularity (day/week/month/year) to produce a group key
3. Use Ruby's `chunk_while` or `group_by` to partition the (already sorted) records into consecutive groups
4. Render a group header for each group, then render each record's event card within the group

Since records are already sorted by the controller (via `?sort=` params), the grouping is a simple linear pass — no additional DB queries.

### Event card rendering

Each event card reuses the same rendering patterns as tile cards:
- `FieldValueResolver.resolve` for all field values
- `RendererRegistry` for rendered fields (badges, relative dates, etc.)
- `ColumnSet` for permission-filtered field visibility
- `ActionSet.single_actions(record)` for record actions

The card template structure is simpler than tiles (no image zone, no grid layout) but shares the same data pipeline.

### PresenterDefinition

Add `timeline?` method (analogous to `tiles?`) and `timeline_config` method (analogous to `tile_config`). Add `all_timeline_field_refs` to extract field references for eager loading, following the same pattern as `all_tile_field_refs`. Add `TIMELINE_NAMED_FIELD_KEYS` constant.

### DependencyCollector

Extend `collect_index_deps` to scan timeline field references when `layout == :timeline`, same pattern as the tiles branch.

### ColumnSet

Add `visible_timeline_fields` method following the same pattern as `visible_tile_fields` — filter timeline fields by read permissions.

### ConfigurationValidator

Add `validate_presenter_timeline` method with validations:
- `date_field` is required and exists in the model
- `title_field` is required and exists in the model
- Named fields (subtitle, description, icon) exist in the model
- Timeline fields exist in the model
- `group_by` is one of: day, week, month, year
- `card_link` is valid (show/edit/false)
- `actions` is valid (dropdown/inline/none)
- `icon_map` values are strings (if present)
- Reorderable + timeline emits a warning

### DSL

Add `TimelineBuilder` class in `presenter_builder.rb`, following the pattern of `TileBuilder`. Methods: `date_field`, `group_by`, `title_field`, `subtitle_field`, `description_field`, `icon_field`, `icon_map`, `columns`, `card_link`, `actions`, `field`.

### CSS

New classes: `.lcp-timeline`, `.lcp-timeline-group`, `.lcp-timeline-group-header`, `.lcp-timeline-axis`, `.lcp-timeline-event`, `.lcp-timeline-marker`, `.lcp-timeline-card`. The vertical axis is a CSS border/pseudo-element. Responsive: axis shifts left on mobile, sticky group headers.

### View slots

No new slot components needed. The existing `sort_dropdown`, `per_page_selector`, and `summary_bar` slots all work via their existing visibility callbacks — the sort dropdown shows when `sort_fields` is defined (and should auto-show for timeline layout, same logic as tiles).

Update the sort dropdown visibility callback to include `timeline?` alongside `tiles?`.

## Decisions

1. **Grouping is a template concern, not a query concern.** Records are sorted and paginated normally. The template groups the already-loaded records by truncating the date field. This avoids complex SQL grouping and keeps the controller layout-agnostic.

2. **Group headers may repeat across pages.** If a day spans two pages, the header appears on both. This is simple, predictable, and matches how real timeline UIs work (e.g., GitHub activity feed).

3. **No collapsible groups in v1.** Groups are always expanded. Collapsible groups (click header to hide/show events) can be added later with minimal JS.

4. **Icon mapping is optional and declarative.** The `icon_map` is a simple value-to-icon-name hash in YAML. No dynamic icon resolution or renderer pipeline — just a static lookup. Falls back to a dot when unmapped.

5. **Reuses tile-established patterns.** Card structure, field rendering, action modes, permission filtering, DSL builder pattern, validator structure — all follow the tile implementation. This minimizes new code and keeps the codebase consistent.

6. **`date_field` is required.** Unlike tiles where `title_field` is the only required field, timeline requires both `date_field` (for the time axis) and `title_field` (for the event label). A timeline without dates makes no sense.

7. **Sort dropdown auto-shows for timeline.** Same behavior as tiles — the sort dropdown is always visible for timeline layout since there are no column headers to click.

## Open Questions

1. **Relative vs. absolute date display in group headers.** Should today's group show "Today" and yesterday's show "Yesterday" instead of the full date? This is a nice UX touch but adds complexity. Could be a `relative_headers: true` option.

2. **Infinite scroll vs. pagination.** Timeline is a natural fit for infinite scroll ("load more" button or auto-load on scroll). This could be a layout-independent feature (`pagination_mode: infinite | paginated`) added later for both timeline and tiles.

3. **Connected records / threading.** Some timelines need to show relationships between events (e.g., "this email is a reply to that email"). This is a v2 feature that would need a `parent_field` or similar linking mechanism.

4. **Color coding.** Beyond icons, events could be color-coded by type/status (e.g., red axis line for overdue milestones). The `item_classes` feature (now implemented) already handles conditional CSS classes on rows/cards/tree nodes — the timeline partial just needs to call `compute_item_classes(record, current_presenter)` on each event card, same as table/tiles/tree. The 7 built-in utility classes (`lcp-row-danger`, `lcp-row-warning`, `lcp-row-success`, etc.) and custom classes will work out of the box. For timeline-specific visual effects (e.g., coloring the axis line segment), custom CSS classes can target `.lcp-timeline-event.my-custom-class .lcp-timeline-axis`.

5. **Horizontal timeline variant.** Some use cases (project Gantt-like view, sprint timeline) benefit from a horizontal time axis. This would be a significantly different layout and might warrant its own `layout: gantt` rather than a variant of timeline.
