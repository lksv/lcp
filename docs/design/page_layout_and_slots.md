# Feature Specification: Page Layouts & View Slots

**Status:** In Progress (Phase 1 — Slot Registry — implemented)
**Date:** 2026-03-02

## Problem / Motivation

The platform's page templates are monolithic ERB files. Every feature that needs to add UI to a page — saved filters, multiselect/batch actions, workflow status bars, export buttons — must directly modify the same shared templates, guarded by `<% if feature_enabled? %>` blocks.

This creates three problems:

1. **Template bloat.** The index page already contains search, predefined filters, advanced filter builder, view switcher, reorderable columns, empty state, pagination, and summaries. Each new feature adds more conditionals, making templates harder to read and maintain.

2. **No extension point for host apps.** A host application that wants to inject a custom widget into the index toolbar (e.g., a "New from template" button, an analytics summary, a notification badge) has no mechanism to do so without overriding the entire template — losing all future platform improvements.

3. **No alternative data presentations.** The index page is hardcoded as a table. Kanban boards, calendars, timelines, card grids, and inline-editable tables are all valid ways to present the same data, but the current architecture cannot accommodate them without duplicating the entire index template.

### What Exists Today

| Concept | Status | Limitation |
|---------|--------|------------|
| **View groups** | Working | Switch between presenters (different columns/fields), not page structure |
| **View switcher** | Working | Tabs that switch presenter config; same underlying template |
| **Section types** (show page) | Working | `association_list`, `json_items_list`, `audit_history` — but adding a new type requires modifying the show template's `if/elsif` chain |
| **Custom partials** | Working | Per-field `partial:` override — works for individual fields, not for page-level areas |
| **content_for / yield** | Not used | The engine uses none of Rails' named yield slots |

### The Two-Layer Gap

The platform has a plugin system for the **data layer** (`model_options_infrastructure.md` — model features register into the Builder pipeline via hook points). But there is no equivalent for the **UI layer**. Features like saved filters need both:

- A **data-layer** component (the saved_filter model, the query pipeline step)
- A **UI-layer** component (toolbar buttons, save dialog, sidebar panel on the index page)

The data layer has defined extension points. The UI layer does not. This spec defines them.

## User Scenarios

### Scenario 1: Platform feature injects into the index page

The saved filters feature needs to render filter buttons in the toolbar area of every index page where saved filters are enabled. Today, this requires editing `index.html.erb` directly. With view slots, saved filters registers its partial into the `:filter_bar` slot, and the template renders it automatically when the feature is active.

### Scenario 2: Host app adds a custom widget to the toolbar

A logistics application needs a "Bulk Import" button next to the "New" button on the shipments index page. The host app registers a partial into the `:toolbar` slot for the `shipments` presenter. The button appears without overriding any engine template.

### Scenario 3: Configurator switches to kanban view

A project management app defines a `tasks_kanban` presenter with `layout: kanban` and `group_by: status`. Users see a kanban board instead of a table. The toolbar (with search, filters, saved filters) still works — these features inject into shared slots that exist in both the table and kanban layouts.

### Scenario 4: View group with mixed layouts

A CRM has two views for deals: "Table" (default table layout) and "Pipeline" (kanban layout grouped by stage). Both are in the same view group. The view switcher lets users toggle between them. Saved filters work in both — the filter bar slot is present in both layouts.

### Scenario 5: Workflow status on show page

A workflow plugin registers a status bar widget into the `:page_header` slot of show pages. When a model has workflow enabled, the status bar appears above the sections — showing current state, available transitions, and approval status. No template modification needed.

### Scenario 6: Host app adds a sidebar panel to show pages

A legal document management app registers a "Related Documents" panel into the `:sidebar` slot of the show page. The panel shows linked documents from an external system. The show page automatically switches to a sidebar layout when any feature registers into `:sidebar`.

### Scenario 7: Calendar layout for events

An event management app defines a presenter with `layout: calendar` and configures `date_field: start_date`, `end_date_field: end_date`. The index page renders a month/week/day calendar instead of a table. Clicking an event opens the show page. The toolbar with search and filters still works.

## Configuration & Behavior

### Two Layers

The system has two distinct layers:

**Layouts** define page structure — the overall arrangement of areas on the page. A layout is like a blueprint: "toolbar on top, sidebar on left, main content in center, pagination at bottom." Different layouts produce fundamentally different page structures (table vs. kanban vs. calendar).

**Slots** are named injection points within a layout. Features and host apps register partials into slots. A slot is like a socket: "put your filter buttons here." The same feature can register into the same slot name across different layouts, and it works in all of them.

```
                    Layout (structure)
                    ┌──────────────────────────────┐
                    │ ┌──────────────────────────┐ │
Slot (injection) →  │ │  :toolbar                │ │  ← shared across layouts
                    │ ├──────────┬───────────────┤ │
                    │ │          │               │ │
                    │ │ :sidebar │ :main_content │ │  ← layout-specific slots
                    │ │          │               │ │
                    │ ├──────────┴───────────────┤ │
                    │ │  :below_content          │ │
                    │ └──────────────────────────┘ │
                    └──────────────────────────────┘
```

### Presenter YAML: Declaring Layouts

Layouts are declared per page type in the presenter:

```yaml
# config/lcp_ruby/presenters/tasks.yml
presenter:
  name: tasks
  model: task
  slug: tasks
  index:
    layout: table                    # default — can be omitted
    columns:
      - { field: title, link_to: show }
      - { field: status }
      - { field: assignee.name }

# config/lcp_ruby/presenters/tasks_kanban.yml
presenter:
  name: tasks_kanban
  model: task
  slug: tasks-kanban
  index:
    layout: kanban
    group_by: status                 # which field drives the columns
    card_fields: [title, assignee.name, due_date]
    card_color_field: priority       # optional: color cards by field value
    column_order: [todo, in_progress, review, done]  # explicit column ordering

# config/lcp_ruby/presenters/events_calendar.yml
presenter:
  name: events_calendar
  model: event
  slug: events
  index:
    layout: calendar
    date_field: start_date           # required for calendar
    end_date_field: end_date         # optional: multi-day events
    default_view: month              # month | week | day
    event_label: "{title}"           # template for event display
```

The `layout` key selects the page structure. All other keys under `index:` are layout-specific configuration. Each layout defines which keys it accepts and validates.

### Built-in Layouts

| Layout | Page | Description |
|--------|------|-------------|
| `table` | index | Default. Sortable table with columns, row actions, pagination. Current behavior. |
| `kanban` | index | Columns grouped by a field value. Cards are draggable between columns. |
| `calendar` | index | Month/week/day calendar grid. Events placed by date field. |
| `cards` | index | Responsive card grid. Each card shows configured fields. Good for visual content (products, profiles). |
| `detail` | show | Default. Sections with field grids. Current behavior. |
| `detail_sidebar` | show | Two-column layout: main sections left, sidebar slots right. |

Additional layouts can be provided by gems or the host application.

### Shared Slots Across Layouts

Some slots appear in **every** layout for a given page type. Features that register into these shared slots work regardless of which layout is active:

**Index page shared slots:**

| Slot | Location | Used by |
|------|----------|---------|
| `:page_header` | Above toolbar | KPI cards, alerts, announcements |
| `:toolbar_start` | Toolbar left side | Multiselect batch actions |
| `:toolbar_center` | Toolbar middle | View switcher (built-in) |
| `:toolbar_end` | Toolbar right side | Collection actions, "New" button (built-in) |
| `:filter_bar` | Below toolbar | Predefined filters, saved filter buttons, search |
| `:below_content` | Below main content area | Pagination (built-in), bulk action confirmation |

**Show page shared slots:**

| Slot | Location | Used by |
|------|----------|---------|
| `:page_header` | Above sections | Workflow status bar, alerts |
| `:toolbar_start` | Toolbar left side | Back to list (built-in) |
| `:toolbar_end` | Toolbar right side | Record actions — edit, delete (built-in) |
| `:below_content` | Below sections | Comments, activity feed |

**Layout-specific slots** are additional injection points that only exist in certain layouts:

| Slot | Layout | Description |
|------|--------|-------------|
| `:sidebar` | `detail_sidebar` | Right-side panel on show page |
| `:card_template` | `cards` | Custom card content override |
| `:board_header` | `kanban` | Per-column header area |

### Slot Registration

Features register their partials into slots. A registration declares: which page, which slot, the partial to render, and a condition for when to render.

**Platform features** register globally (their partials render on all presenters where the feature is active):

```ruby
# Internal: saved filters registers into the filter bar
LcpRuby::ViewSlot.register(
  page: :index,
  slot: :filter_bar,
  name: :saved_filters,
  partial: "lcp_ruby/saved_filters/filter_bar",
  enabled: ->(ctx) { ctx.presenter.saved_filters_enabled? },
  position: 20
)

# Internal: predefined filters (refactored from hardcoded block)
LcpRuby::ViewSlot.register(
  page: :index,
  slot: :filter_bar,
  name: :predefined_filters,
  partial: "lcp_ruby/resources/predefined_filters",
  enabled: ->(ctx) { ctx.presenter.search_config.dig("predefined_filters")&.any? },
  position: 10
)
```

**Host apps** register in an initializer, optionally scoped to specific presenters:

```ruby
# config/initializers/lcp_ruby_slots.rb
LcpRuby::ViewSlot.register(
  page: :index,
  slot: :toolbar_end,
  name: :bulk_import,
  partial: "shipments/bulk_import_button",
  enabled: ->(ctx) { ctx.presenter.slug == "shipments" },
  position: 5       # before the "New" button (position 10)
)

LcpRuby::ViewSlot.register(
  page: :show,
  slot: :sidebar,
  name: :related_documents,
  partial: "documents/related_panel",
  enabled: ->(ctx) { ctx.presenter.model_name == "contract" },
  position: 10
)
```

### Slot Rendering Context

Every slot partial receives a `slot_context` local with access to the current page state:

| Attribute | Type | Available on |
|-----------|------|--------------|
| `presenter` | `PresenterDefinition` | all pages |
| `model_definition` | `ModelDefinition` | all pages |
| `evaluator` | `PermissionEvaluator` | all pages |
| `records` | `ActiveRecord::Relation` | index |
| `record` | `ActiveRecord::Base` | show, form |
| `action_set` | `ActionSet` | all pages |
| `params` | `ActionController::Parameters` | all pages |

```erb
<%# app/views/shipments/_bulk_import_button.html.erb %>
<% if slot_context.evaluator.can?(:create) %>
  <%= link_to "Import CSV",
      bulk_import_shipments_path,
      class: "btn" %>
<% end %>
```

### Custom Layouts

Host apps can define custom layouts. A layout is a named template that defines its slot structure:

```ruby
# config/initializers/lcp_ruby_layouts.rb
LcpRuby::PageLayout.register(
  name: :timeline,
  page: :index,
  template: "layouts/lcp_timeline",        # app/views/layouts/lcp_timeline.html.erb
  slots: [:page_header, :toolbar_start, :toolbar_center, :toolbar_end,
          :filter_bar, :timeline_body, :below_content],
  config_keys: {
    date_field: { type: :string, required: true },
    group_by: { type: :string },
    zoom: { type: :string, default: "month", values: %w[day week month quarter year] }
  }
)
```

The custom layout template uses a helper to render slots:

```erb
<%# app/views/layouts/lcp_timeline.html.erb %>
<div class="lcp-resources-index">
  <div class="lcp-header">
    <h1><%= current_presenter.label %></h1>
    <div class="lcp-toolbar">
      <%= render_slot(:toolbar_start) %>
      <%= render_slot(:toolbar_center) %>
      <%= render_slot(:toolbar_end) %>
    </div>
  </div>

  <%= render_slot(:filter_bar) %>

  <div class="timeline-container" data-zoom="<%= layout_config['zoom'] %>">
    <%# Timeline-specific rendering here %>
    <%= render_slot(:timeline_body) %>
  </div>

  <%= render_slot(:below_content) %>
</div>
```

### DSL for Layouts and Slots

**Presenter DSL — declaring a layout:**

```ruby
define_presenter :tasks_kanban do
  model :task
  slug "tasks-kanban"

  index do
    layout :kanban, group_by: "status",
                    card_fields: %w[title assignee.name due_date],
                    column_order: %w[todo in_progress review done]
  end
end
```

**Host app DSL — registering slots:**

```ruby
# config/initializers/lcp_ruby_slots.rb
LcpRuby.configure do |config|
  config.view_slots do |slots|
    slots.register :index, :toolbar_end, :bulk_import,
      partial: "shipments/bulk_import_button",
      enabled: ->(ctx) { ctx.presenter.slug == "shipments" },
      position: 5

    slots.register :show, :below_content, :comments,
      partial: "shared/comments_section",
      position: 50
  end
end
```

**Host app DSL — registering a custom layout:**

```ruby
LcpRuby.configure do |config|
  config.page_layouts do |layouts|
    layouts.register :timeline,
      page: :index,
      template: "layouts/lcp_timeline",
      slots: %i[page_header toolbar_start toolbar_center toolbar_end
                filter_bar timeline_body below_content],
      config_keys: {
        date_field: { type: :string, required: true },
        group_by: { type: :string }
      }
  end
end
```

### View Groups with Mixed Layouts

View groups already handle multiple presenters for the same model. Since layout is a presenter-level config, a view group can mix layouts naturally:

```yaml
# config/lcp_ruby/views/tasks.yml
view_group:
  name: tasks
  model: task
  primary: tasks
  views:
    - presenter: tasks              # layout: table (default)
      label: "List"
      icon: list
    - presenter: tasks_kanban       # layout: kanban
      label: "Board"
      icon: columns
    - presenter: tasks_calendar     # layout: calendar
      label: "Calendar"
      icon: calendar
```

The view switcher renders tabs for all three. Clicking "Board" loads the kanban presenter. Shared slots (toolbar, filter bar) render the same features in all layouts.

### Predefined Filters and Saved Filters in Slots

Currently, predefined filters and advanced search are hardcoded blocks in `index.html.erb`. With slots, they become registered components:

```
:filter_bar slot (position-ordered):
  10 — predefined_filters    (scope buttons from presenter YAML)
  20 — saved_filters         (saved filter buttons/dropdown)
  30 — search_box            (quick search input)
  40 — advanced_filter       (visual filter builder toggle + panel)
```

Each component checks its own `enabled?` condition. A presenter with no search, no predefined filters, and no saved filters renders an empty filter bar. No conditionals in the template.

### Slot Ordering and Conflicts

Within a slot, components are rendered in `position` order (ascending). The built-in components use positions in multiples of 10, leaving gaps for host app insertions:

```
position 5  → host app "bulk import" button (before "New")
position 10 → built-in "New" button
position 15 → host app "New from template" button (after "New")
position 20 → built-in "Export" button
```

If two components register at the same position, they are rendered in registration order (first-registered first). This is stable and predictable — no need for explicit conflict resolution.

### Show Page: Automatic Sidebar Activation

The show page has a subtle interaction: the `detail_sidebar` layout activates automatically when any feature registers into the `:sidebar` slot.

```yaml
# No explicit layout needed:
show:
  sections:
    - fields: [title, description, status]
    - type: audit_history

# If a workflow plugin registers into :sidebar,
# the show page automatically switches from `detail` to `detail_sidebar`.
```

This means the configurator does not need to know which features use the sidebar. Enabling workflow on a model automatically adds the sidebar panel. Disabling it removes the sidebar.

The configurator can also force a layout:

```yaml
show:
  layout: detail_sidebar      # always show sidebar, even if no features use it
  sections: [...]
```

Or force no sidebar:

```yaml
show:
  layout: detail              # never show sidebar, even if features register into :sidebar
  sections: [...]
```

## Usage Examples

### Example 1: Minimal setup (no configuration needed)

An app with a simple `products` presenter and no special features. The `table` layout is used by default. Built-in components (view switcher, "New" button, search, predefined filters) are registered as slot components. The templates use `render_slot` instead of hardcoded blocks. Nothing changes visually — but the infrastructure is ready for extensions.

### Example 2: Saved filters on deals index

```yaml
# config/lcp_ruby/presenters/deals.yml
presenter:
  name: deals
  model: deal
  slug: deals
  search:
    enabled: true
    advanced_filter:
      enabled: true
      saved_filters:
        enabled: true
        display: inline
  index:
    # layout: table (default, omitted)
    columns: [...]
```

The saved filters feature registers into `:filter_bar` with `position: 20`. On the deals index, the filter bar shows: predefined filter buttons (10), then saved filter buttons (20), then search (30), then advanced filter toggle (40).

### Example 3: Kanban + saved filters

```yaml
# config/lcp_ruby/presenters/deals_pipeline.yml
presenter:
  name: deals_pipeline
  model: deal
  slug: deals-pipeline
  search:
    enabled: true
    advanced_filter:
      enabled: true
      saved_filters:
        enabled: true
        display: dropdown       # dropdown works better in kanban
  index:
    layout: kanban
    group_by: stage
    card_fields: [title, company.name, amount]
    card_color_field: priority
    column_order: [lead, proposal, negotiation, won, lost]
```

The kanban layout renders cards grouped by `stage`. The `:filter_bar` slot renders a saved filters dropdown. The same saved filters work in both table and kanban views (they filter the same underlying query). The view group lets users switch between table and kanban.

### Example 4: Host app extending the toolbar

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.view_slots do |slots|
    # Add "Export CSV" button to all index pages
    slots.register :index, :toolbar_end, :csv_export,
      partial: "shared/csv_export_button",
      position: 15

    # Add "Related Documents" sidebar to contract show pages
    slots.register :show, :sidebar, :related_docs,
      partial: "contracts/related_documents",
      enabled: ->(ctx) { ctx.model_definition.name == "contract" },
      position: 10

    # Add analytics summary above the deals table
    slots.register :index, :page_header, :deal_stats,
      partial: "deals/kpi_cards",
      enabled: ->(ctx) { ctx.presenter.slug == "deals" },
      position: 10
  end
end
```

### Example 5: Custom timeline layout

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.page_layouts do |layouts|
    layouts.register :timeline,
      page: :index,
      template: "lcp_layouts/timeline",
      slots: %i[page_header toolbar_start toolbar_center toolbar_end
                filter_bar timeline_body below_content],
      config_keys: {
        date_field: { type: :string, required: true },
        group_by: { type: :string },
        zoom: { type: :string, default: "month" }
      }
  end
end
```

```yaml
# config/lcp_ruby/presenters/project_timeline.yml
presenter:
  name: project_timeline
  model: project
  slug: projects-timeline
  index:
    layout: timeline
    date_field: start_date
    end_date_field: deadline
    zoom: quarter
```

All shared slot features (saved filters, search, predefined filters) work automatically in the timeline layout because it declares the shared slots.

## General Implementation Approach

### Phase 1: Slot Registry (implement with saved filters)

Introduce `ViewSlotRegistry` — a simple registry where components declare which `(page, slot)` they render into. Refactor existing hardcoded index template blocks (search, predefined filters, view switcher, "New" button) into slot-registered partials. The index template becomes a series of `render_slot` calls.

This is the minimum needed for saved filters to inject into the index page without modifying the template. It also provides the extension point for host apps.

The show page gets the same treatment: toolbar, sections dispatch, and below-content areas become slots.

### Phase 2: Layout Variants (implement when kanban/calendar is needed)

Introduce `PageLayoutRegistry` — layouts register themselves with a name, template, and declared slots. The presenter's `layout:` key selects which template to render. Built-in layouts: `table` (current), `kanban`, `calendar`, `cards`.

Each layout template uses `render_slot` for shared slots and adds its own layout-specific rendering. The controller resolves the layout from presenter config and renders the appropriate template.

### Phase 3: Custom Layouts (implement when host apps need them)

Open the layout registration API to host apps. A host app defines a layout template, declares its slots, and registers it. Presenters can then reference custom layouts by name.

### Relationship to Existing Architecture

The slot and layout system does **not** replace any existing concept:

| Existing Concept | Relationship |
|------------------|--------------|
| **Presenters** | Presenter config gains `layout:` key. Presenter still defines what data/columns/fields to show. |
| **View groups** | View groups can contain presenters with different layouts (table + kanban in the same group). View switcher works across layouts. |
| **Section types** (show page) | Section types remain as-is. The slot system handles page-level areas; sections handle within-content structure. A new section type (e.g., `comments`) can be implemented either as a section type or a slot component — the choice depends on whether it's controlled by presenter YAML (section) or registered globally by a feature (slot). |
| **Custom partials** | Per-field `partial:` overrides continue to work within any layout. |

## Decisions

**Two-layer architecture: layouts + slots.**
Rationale: Layouts handle fundamentally different page structures (table vs. kanban). Slots handle component injection within any layout. These are orthogonal concerns — a saved filter button works in both table and kanban layouts because it uses a shared slot.

**Shared slots across all layouts for a given page type.**
Rationale: Features like saved filters, search, and batch actions should work in every layout without per-layout integration. Shared slots (`:toolbar_*`, `:filter_bar`, `:below_content`) are mandatory for all index layouts. Layout-specific slots are additional.

**Position-based ordering within slots, not priority or dependency.**
Rationale: Slot components are independent UI fragments — they don't have data dependencies on each other (unlike Builder pipeline plugins). Simple numeric position is sufficient. Gaps between built-in positions (10, 20, 30) allow host app insertions.

**Layouts are presenter-level, not model-level or view-group-level.**
Rationale: The same model can have a table presenter and a kanban presenter. A view group composes both. This matches the existing pattern — presenters define "how to show data," view groups compose presenters.

**Built-in page elements refactored to slot components.**
Rationale: The "New" button, search box, predefined filters, view switcher, and pagination are refactored from hardcoded template blocks to slot-registered components. This makes them repositionable, removable, and gives host apps a consistent pattern to follow.

**Automatic `detail_sidebar` activation on show pages.**
Rationale: When a feature (workflow, related records) registers into `:sidebar`, the show page should automatically display the sidebar column. The configurator should not need to know which features use the sidebar. Explicit `layout: detail` / `layout: detail_sidebar` overrides remain available.

**Phase 1 first, layout variants later.**
Rationale: Saved filters only need slot injection (Phase 1). Kanban and calendar are separate features that need layout variants (Phase 2). Building the slot registry first provides immediate value and validates the pattern before adding layout complexity.

**Inline editing is a layout, not a slot.**
Rationale: Inline editing fundamentally changes how the table body works (cells become editable, save/cancel controls appear, keyboard navigation changes). This is a structural change to the page, not an additive component — it belongs as a layout variant (`inline_edit`), not a slot injection into `:table_body`.

## Open Questions

1. **Should the form page (new/edit) support layouts?** The form page is structurally simpler than index — it's sections with fields. The main candidate for form layout variants would be multi-step wizards (`layout: wizard`). Worth considering but probably deferred until a wizard feature is designed.

2. **How do slots interact with Turbo/Stimulus?** If the platform adopts Hotwire in the future, slot components would need to declare their Stimulus controllers and Turbo Frame boundaries. The slot registration API should be extensible to support this (e.g., a `stimulus_controllers` key), but the exact mechanism depends on how Hotwire is adopted.

3. **Should layouts support nesting?** A layout template currently uses flat `render_slot` calls. Could a layout compose other layouts (e.g., a `split_view` layout that renders two sub-layouts side by side)? This would enable master-detail views. Probably overengineering for now, but the architecture should not prevent it.

4. **Should slots support `mode: :replace`?** Currently, slot rendering is purely additive — all registered components for a slot are rendered in order. A `mode: :replace` would let a component override the default rendering of a slot (e.g., a host app replacing the built-in search box with a custom one). Alternatively, the host app can just register with the same `name` to replace a built-in component. Need to decide which approach is cleaner.

5. **How do layout-specific presenter config keys get validated?** When `layout: kanban`, the `group_by` key must exist and reference a valid field. Each layout needs to define its own validation rules that `ConfigurationValidator` can invoke. The mechanism (layout classes with a `validate` method? schema-per-layout?) needs to be designed.

6. **Should `render_slot` be available in host app views outside of LCP?** A host app might want to render LCP slot components in its own custom pages (e.g., a dashboard that includes the deals filter bar). This would require exposing the slot rendering helper beyond engine views.

## Related Documents

- **[Saved Filters](saved_filters.md)** — First feature to use slot registration (`:filter_bar` on index)
- **[Model Options Infrastructure](model_options_infrastructure.md)** — Data-layer plugin system (Builder pipeline); this spec is the UI-layer counterpart
- **[View Groups Reference](../reference/view-groups.md)** — Existing multi-presenter composition; layouts extend this with structural variants
- **[Presenters Reference](../reference/presenters.md)** — Presenter YAML gains `layout:` key
- **[Multiselect and Batch Actions](multiselect_and_batch_actions.md)** — Will use `:toolbar_start` slot for batch action buttons
