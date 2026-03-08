# Implementation Plan: Tier 2 Phase A — Composite Page Rendering

**Status:** Implemented
**Date:** 2026-03-08

**Source:** [Composite Pages v2 spec](composite_pages_v2.md) (Tier 2 section), with dependencies on [Modal Dialogs spec](modal_dialogs.md) and [Dashboards spec](dashboards.md).

**Goal:** Enable explicit composite pages (master-detail with tabs, sidebar) rendered server-side with full page reload. This is the foundational Tier 2 capability.

**End result:** A YAML like this works:

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
      label_key: pages.employee_detail.tabs.leave
      scope_context:
        employee_id: :record_id
    - name: trainings
      presenter: trainings_index
      area: tabs
      label_key: pages.employee_detail.tabs.trainings
      scope_context:
        employee_id: :record_id
```

URL `/employees/123?tab=leave_requests` renders the employee show header + a tab bar + the leave_requests table scoped to employee 123.

---

## Architecture Overview

### Entry point

Composite pages are **record-bound** (have a model + `:id`), so they enter via `ResourcesController#show`. The show action detects a composite page and branches to composite rendering.

### Zone rendering strategy

| Zone area | Presenter type | What it renders | Data source |
|-----------|---------------|-----------------|-------------|
| `main` | show presenter | Record detail sections (fields, labels) | Primary record (`@record`) |
| `tabs` | index presenter | Table of related records | `PresenterZoneResolver` + `scope_context` |
| `sidebar` | show/widget | Related info or KPI | Show: primary record fields; Widget: `DataResolver` |
| `below` | index/widget | Additional lists or widgets | `PresenterZoneResolver` or `DataResolver` |

### Data flow

```
GET /employees/123?tab=leave_requests
  → ApplicationController#set_presenter_and_model
    → @page_definition (employee_detail, composite)
    → @presenter_definition (employee_show — main zone's presenter)
    → @model_class (Employee)
  → ResourcesController#show
    → @record = Employee.find(123)
    → authorize @record (main zone's model)
    → detect composite page (current_page.composite?)
    → load_composite_page:
        Main zone: load show view objects (layout_builder, column_set, etc.)
        For each non-main zone:
          - check visible_when
          - check can_access_presenter?(zone.presenter)
          - if tab zone: skip unless active tab
          - resolve scope_context: { employee_id: :record_id } → { employee_id: 123 }
          - PresenterZoneResolver.resolve(scope_context: resolved)
        Set @zone_data, @active_tab
    → render show.html.erb
      → detects composite → renders _semantic_page.html.erb
        → main area: render show sections (existing _show_sections partial extraction)
        → tab bar: render tab navigation links
        → active tab: render presenter zone table
        → sidebar: render show/widget zones
        → below: render index/widget zones
```

---

## Steps

### Step 1: Extend ZoneDefinition with new attributes

**File:** `lib/lcp_ruby/metadata/zone_definition.rb`

Add two new attributes:
- `scope_context` (Hash, optional) — e.g., `{ "employee_id" => ":record_id" }`
- `label_key` (String, optional) — i18n key for tab label display

Changes:
- Add `attr_reader :scope_context, :label_key`
- Accept in `initialize` kwargs
- Parse in `from_hash`
- Add `#label` method: `I18n.t(label_key, default: name.humanize)` if label_key present, else `name.humanize`

No new validation at this level — validation of scope_context references happens in `ConfigurationValidator`.

**Tests:** `spec/lib/lcp_ruby/metadata/zone_definition_spec.rb`
- New zone with scope_context and label_key
- `from_hash` parsing of both attributes
- `#label` method with and without label_key

---

### Step 2: Extend PageDefinition with composite page helpers

**File:** `lib/lcp_ruby/metadata/page_definition.rb`

Add methods:
- `composite?` — `!auto_generated? && zones.size > 1 && !standalone?`
- `zones_for_area(area)` — `zones.select { |z| z.area == area }`
- `tab_zones` — `zones_for_area("tabs")`
- `has_tabs?` — `tab_zones.any?`
- `has_sidebar?` — `zones_for_area("sidebar").any?`
- `has_below?` — `zones_for_area("below").any?`
- `semantic?` — `@layout == :semantic` (complement to existing `grid?`)

**Tests:** `spec/lib/lcp_ruby/metadata/page_definition_spec.rb`
- `composite?` returns true for multi-zone, non-auto, non-standalone page
- `composite?` returns false for auto-generated, standalone, or single-zone
- `zones_for_area`, `tab_zones`, `has_tabs?`, `has_sidebar?`
- `semantic?`

---

### Step 3: Create Pages::ScopeContextResolver

**New file:** `lib/lcp_ruby/pages/scope_context_resolver.rb`

Resolves symbolic references in `scope_context` to concrete values.

```ruby
module LcpRuby
  module Pages
    class ScopeContextResolver
      # Input:  scope_context hash (e.g., { "employee_id" => ":record_id" })
      #         record (primary AR record)
      #         user (current_user)
      # Output: resolved hash (e.g., { "employee_id" => 42 })

      DYNAMIC_PREFIX = ":"

      def initialize(scope_context, record:, user:)
        @scope_context = scope_context
        @record = record
        @user = user
      end

      def resolve
        return {} if @scope_context.blank?

        @scope_context.each_with_object({}) do |(key, value), resolved|
          resolved[key] = resolve_value(value)
        end
      end

      private

      def resolve_value(value)
        return value unless value.is_a?(String) && value.start_with?(DYNAMIC_PREFIX)

        reference = value.delete_prefix(DYNAMIC_PREFIX)
        case reference
        when "record_id"
          @record&.id
        when /\Arecord\.(.+)\z/
          resolve_dot_path(@record, $1)
        when "current_user"
          @user
        when "current_user_id"
          @user&.id
        when "current_year"
          Date.current.year
        when "current_date"
          Date.current
        else
          raise MetadataError, "Unknown scope_context reference: #{value}"
        end
      end

      def resolve_dot_path(object, path)
        path.split(".").reduce(object) do |obj, method|
          return nil unless obj.respond_to?(method)
          obj.public_send(method)
        end
      end
    end
  end
end
```

**Tests:** `spec/lib/lcp_ruby/pages/scope_context_resolver_spec.rb`
- Resolve `:record_id` → record.id
- Resolve `:record.department_id` → record.department_id
- Resolve `:current_user_id` → user.id
- Resolve `:current_year` → Date.current.year
- Resolve static values (no `:` prefix) → passed through unchanged
- Resolve with nil record → returns nil for record refs
- Unknown reference → raises MetadataError
- Empty/nil scope_context → returns empty hash

---

### Step 4: Extend PresenterZoneResolver with scope_context support

**File:** `lib/lcp_ruby/widgets/presenter_zone_resolver.rb`

Changes:
- `initialize` accepts optional `scope_context:` keyword (already resolved hash, e.g. `{ "employee_id" => 42 }`)
- After `apply_zone_scope`, add `apply_scope_context` step
- `apply_scope_context` applies the resolved hash as `where(key: value)` conditions

```ruby
def apply_scope_context(scope, model_class)
  return scope if @scope_context.blank?

  @scope_context.each do |key, value|
    next if value.nil?

    if model_class.respond_to?("filter_#{key}")
      # Delegate to filter_* interceptor method if available
      scope = model_class.public_send("filter_#{key}", scope, value)
    elsif model_class.column_names.include?(key.to_s)
      scope = scope.where(key => value)
    else
      Rails.logger.warn("[LcpRuby::Widgets] scope_context key '#{key}' not found as column on #{model_class.name}")
    end
  end

  scope
end
```

Also extend `DataResolver` similarly — widget zones (KPI, list) on composite pages may also need scope_context for scoping aggregates to the parent record.

**File:** `lib/lcp_ruby/widgets/scope_applicator.rb`

Move `apply_scope_context` to the shared `ScopeApplicator` module so both `PresenterZoneResolver` and `DataResolver` can use it.

**Tests:** `spec/lib/lcp_ruby/widgets/presenter_zone_resolver_spec.rb`
- Resolve with scope_context `{ employee_id: 42 }` → records scoped by employee_id
- Resolve with empty scope_context → no additional scoping
- Scope_context key not a column → logged warning, no crash

---

### Step 5: Composite page loading in ResourcesController

**File:** `app/controllers/lcp_ruby/resources_controller.rb`

Add method `load_composite_page` (similar pattern to existing `load_dashboard`):

```ruby
def load_composite_page
  @active_tab = params[:tab]

  # Set up main zone view objects (reuse existing show setup)
  main_zone = current_page.main_zone
  if main_zone&.presenter_zone?
    main_presenter = LcpRuby.loader.presenter_definition(main_zone.presenter)
    @layout_builder = Presenter::LayoutBuilder.new(main_presenter, current_model_definition)
    load_show_virtual_columns
    preload_associations(@record, :show)
    @column_set = Presenter::ColumnSet.new(main_presenter, current_evaluator)
    @action_set = Presenter::ActionSet.new(main_presenter, current_evaluator, context: condition_context)
    @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
  end

  # Default to first tab if none specified
  tab_zones = current_page.tab_zones
  if tab_zones.any? && @active_tab.blank?
    @active_tab = tab_zones.first.name
  end

  # Load non-main zones
  @zone_data = {}
  current_page.zones.each do |zone|
    next if zone == main_zone

    # Skip invisible zones
    next if zone.visible_when.present? && !zone_visible?(zone.visible_when)

    # Skip inactive tabs (only load active tab)
    if zone.area == "tabs" && zone.name != @active_tab
      # Store zone metadata for tab bar rendering, but don't load data
      @zone_data[zone] = { tab_only: true }
      next
    end

    # Per-zone authorization
    if zone.presenter_zone?
      zone_evaluator = build_zone_evaluator(zone)
      next unless zone_evaluator&.can_access_presenter?(zone.presenter)
    end

    # Resolve scope_context
    resolved_context = resolve_zone_scope_context(zone)

    # Load zone data
    if zone.widget?
      data = Widgets::DataResolver.new(zone, user: effective_user, scope_context: resolved_context).resolve
    else
      data = Widgets::PresenterZoneResolver.new(zone, user: effective_user, scope_context: resolved_context).resolve
    end

    @zone_data[zone] = data
  end
end

def resolve_zone_scope_context(zone)
  return {} if zone.scope_context.blank?

  Pages::ScopeContextResolver.new(
    zone.scope_context,
    record: @record,
    user: effective_user
  ).resolve
end

def build_zone_evaluator(zone)
  presenter = LcpRuby.loader.presenter_definitions[zone.presenter]
  return nil unless presenter

  perm_def = LcpRuby.loader.permission_definition(presenter.model)
  Authorization::PermissionEvaluator.new(perm_def, effective_user, presenter.model)
rescue LcpRuby::MetadataError
  nil
end
```

Modify `#show` to detect composite pages:

```ruby
def show
  authorize @record

  if current_page.composite?
    load_composite_page
    return
  end

  # ... existing show logic unchanged ...
end
```

**Tests:** covered by integration tests (Step 8).

---

### Step 6: View layer — semantic page rendering

#### 6a: Extract show sections into a reusable partial

**New file:** `app/views/lcp_ruby/resources/_show_sections.html.erb`

Extract the section rendering loop from `show.html.erb` (lines 15-80) into a partial so it can be reused in the main zone of a composite page. The partial accepts `layout_builder`, `column_set`, `field_resolver`, `record` as locals.

Update `show.html.erb` to use the extracted partial for non-composite pages.

#### 6b: Create semantic page partial

**New file:** `app/views/lcp_ruby/resources/_semantic_page.html.erb`

```erb
<div class="lcp-semantic-page">
  <div class="lcp-semantic-layout
    <%= 'lcp-has-sidebar' if current_page.has_sidebar? %>
    <%= 'lcp-has-tabs' if current_page.has_tabs? %>
    <%= 'lcp-has-below' if current_page.has_below? %>">

    <%# Main area %>
    <div class="lcp-area-main">
      <%= render "lcp_ruby/resources/show_sections",
            layout_builder: @layout_builder,
            column_set: @column_set,
            field_resolver: @field_resolver,
            record: @record %>
    </div>

    <%# Sidebar area %>
    <% if current_page.has_sidebar? %>
      <div class="lcp-area-sidebar">
        <% current_page.zones_for_area("sidebar").each do |zone| %>
          <% data = @zone_data[zone] %>
          <% next unless data && !data[:hidden] && !data[:tab_only] %>
          <div class="lcp-zone lcp-zone-sidebar">
            <%= render partial: zone_partial_for(zone),
                  locals: { zone: zone, data: data } %>
          </div>
        <% end %>
      </div>
    <% end %>

    <%# Tabs area %>
    <% if current_page.has_tabs? %>
      <div class="lcp-area-tabs">
        <%# Tab navigation bar %>
        <div class="lcp-tab-bar">
          <% current_page.tab_zones.each do |zone| %>
            <% data = @zone_data[zone] %>
            <% next if data.nil? %>  <%# zone was filtered out by visible_when or auth %>
            <a href="<%= request.path %>?tab=<%= zone.name %>"
               class="lcp-tab <%= 'lcp-tab-active' if zone.name == @active_tab %>">
              <%= zone.label %>
            </a>
          <% end %>
        </div>

        <%# Active tab content %>
        <% active_zone = current_page.tab_zones.find { |z| z.name == @active_tab } %>
        <% if active_zone %>
          <% data = @zone_data[active_zone] %>
          <% if data && !data[:hidden] && !data[:tab_only] %>
            <div class="lcp-tab-content">
              <%= render partial: zone_partial_for(active_zone),
                    locals: { zone: active_zone, data: data } %>
            </div>
          <% end %>
        <% end %>
      </div>
    <% end %>

    <%# Below area %>
    <% if current_page.has_below? %>
      <div class="lcp-area-below">
        <% current_page.zones_for_area("below").each do |zone| %>
          <% data = @zone_data[zone] %>
          <% next unless data && !data[:hidden] && !data[:tab_only] %>
          <div class="lcp-zone lcp-zone-below">
            <%= render partial: zone_partial_for(zone),
                  locals: { zone: zone, data: data } %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

#### 6c: Add `zone_partial_for` helper

**File:** `app/helpers/lcp_ruby/dashboard_helper.rb` (rename to `page_helper.rb` or extend)

```ruby
def zone_partial_for(zone)
  if zone.widget?
    "lcp_ruby/widgets/#{zone.widget['type']}"
  else
    "lcp_ruby/widgets/presenter_zone"
  end
end
```

Note: This is essentially the same as existing `widget_partial_for`. Consider renaming/aliasing.

#### 6d: Update show.html.erb

```erb
<div class="lcp-resource-show">
  <%= render_slot(:page_header, page: :show) %>
  <div class="lcp-header">
    <h1><%= @record.respond_to?(:to_label) ? @record.to_label : @record.to_s %></h1>
    <div class="lcp-toolbar">
      <%= render_slot(:toolbar_start, page: :show) %>
      <%= render_slot(:toolbar_end, page: :show) %>
    </div>
  </div>

  <% if current_page&.composite? %>
    <%= render "lcp_ruby/resources/semantic_page" %>
  <% else %>
    <%# existing show rendering (extracted to _show_sections) %>
    <%= render "lcp_ruby/resources/show_sections",
          layout_builder: @layout_builder, column_set: @column_set,
          field_resolver: @field_resolver, record: @record %>
  <% end %>

  <%= render_slot(:below_content, page: :show) %>
</div>
```

#### 6e: CSS for semantic layout

**File:** `app/assets/stylesheets/lcp_ruby/components/_semantic_page.css` (or extend existing stylesheet)

```css
.lcp-semantic-layout {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
}

.lcp-semantic-layout.lcp-has-sidebar {
  grid-template-columns: 1fr 4fr;  /* sidebar 1/4, main 3/4 — adjust as needed */
}

/* Alternative: 8+4 grid */
.lcp-semantic-layout.lcp-has-sidebar {
  grid-template-columns: 2fr 1fr;
}

.lcp-area-main { grid-column: 1; }
.lcp-area-sidebar { grid-column: 2; grid-row: 1 / span 2; }
.lcp-area-tabs { grid-column: 1; }
.lcp-area-below { grid-column: 1 / -1; }

/* Tab bar */
.lcp-tab-bar {
  display: flex;
  border-bottom: 2px solid var(--lcp-border-color, #dee2e6);
  margin-bottom: 1rem;
}

.lcp-tab {
  padding: 0.5rem 1rem;
  text-decoration: none;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
  color: var(--lcp-text-muted, #6c757d);
}

.lcp-tab-active {
  border-bottom-color: var(--lcp-primary, #0d6efd);
  color: var(--lcp-text, #212529);
  font-weight: 600;
}
```

---

### Step 7: ConfigurationValidator extensions

**File:** `lib/lcp_ruby/metadata/configuration_validator.rb`

In `validate_pages`, add validation for composite page zones:

1. **scope_context validation:**
   - Each value must be a valid reference (`:record_id`, `:record.<field>`, `:current_user_id`, `:current_year`, `:current_date`) or a static value
   - Each key must be a column or scope param on the zone's model
   - `:record.<field>` — field must exist on the page's primary model

2. **label_key for tabs:**
   - Warn if a zone with `area: tabs` has no `label_key` (will fall back to humanized name)

3. **Tier 1 constraint (from spec):**
   - If page has tab zones, the main zone must not be an index presenter (prevents param collision)
   - Check via presenter's default action or by presence of `index_config`

4. **Zone presenter references:**
   - Already validated (each zone's presenter must exist)

**Tests:** `spec/lib/lcp_ruby/metadata/configuration_validator_spec.rb`
- scope_context with valid column reference → passes
- scope_context with invalid reference format → warning
- Tab zone without label_key → warning
- Main zone is index when tabs present → error

---

### Step 8: Integration test fixtures and tests

#### 8a: Test fixtures

Create a composite page test fixture set under `spec/fixtures/integration/composite/`:

**Models:**
- `employee.yml` — fields: name, department_id, email, status
- `leave_request.yml` — fields: employee_id, start_date, end_date, status, reason
- `training.yml` — fields: employee_id, title, date, status

**Presenters:**
- `employee_show.yml` — show presenter for employee (name, email, department, status)
- `leave_requests_index.yml` — index presenter for leave_request (start_date, end_date, status)
- `trainings_index.yml` — index presenter for training (title, date, status)

**Pages:**
- `employee_detail.yml`:
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
        label_key: pages.employee_detail.tabs.leave
        scope_context:
          employee_id: :record_id
      - name: trainings
        presenter: trainings_index
        area: tabs
        label_key: pages.employee_detail.tabs.trainings
        scope_context:
          employee_id: :record_id
  ```

**Permissions:**
- `employee.yml`, `leave_request.yml`, `training.yml` — admin has full CRUD + presenter access

**View groups:**
- `employees.yml` — references page: employee_detail

#### 8b: Integration tests

**New file:** `spec/integration/composite_page_spec.rb`

Test scenarios:
1. **Basic composite rendering** — GET `/employees/:id` returns 200, renders main zone + tab bar
2. **Tab rendering** — GET `/employees/:id?tab=leave_requests` shows leave requests scoped to employee
3. **Default tab** — GET `/employees/:id` (no ?tab) defaults to first tab
4. **Tab switch** — Different `?tab=` shows different content
5. **scope_context scoping** — Leave requests table only shows records for the given employee
6. **Per-zone authorization** — Zone hidden when user lacks presenter access
7. **visible_when** — Zone hidden when condition not met
8. **Empty tab** — Tab with no records shows empty state
9. **Widget zone on composite page** — KPI widget in sidebar scoped via scope_context

---

### Step 9: Update page JSON schema and documentation

**File:** `docs/reference/pages.md` — Add composite page examples and scope_context reference
**File:** `lib/lcp_ruby/metadata/page_json_schema.rb` (if exists) — Add scope_context and label_key to zone schema

---

## Dependency Graph

```
Step 1 (ZoneDefinition)
  ↓
Step 2 (PageDefinition)    Step 3 (ScopeContextResolver)
  ↓                              ↓
Step 4 (PresenterZoneResolver + scope_context)
  ↓
Step 5 (Controller load_composite_page)
  ↓
Step 6 (Views: semantic_page, show_sections, CSS)
  ↓
Step 7 (ConfigurationValidator)
  ↓
Step 8 (Integration tests)
  ↓
Step 9 (Docs)
```

Steps 1, 2, 3 can be done in parallel.
Steps 7 and 9 can be done in parallel with Step 8.

---

## Scope explicitly excluded from Phase A

- **Turbo Frames / lazy loading** — Full page reload only. Phase B.
- **Zone endpoint** (`/:slug/:id/zones/:zone_name`) — Not needed for server-side rendering.
- **`on_success: reload_zone`** — Requires Turbo Frames. Phase B.
- **Chart widget** — Independent, Phase C.
- **Form zones** — Phase C.
- **`record_source`** — Phase C.
- **`record_click: dialog`** — Phase C.
- **Index composite pages** — Only show (record-bound) composite pages. Index composites are Tier 3 (master-detail).
- **Mixed layout (grid + semantic)** — Not in scope. One mode per page.

## Risks and edge cases

1. **Main zone presenter model != page model** — The spec says main zone should be the page's primary model. Enforce in validator.
2. **Auto-page vs explicit page slug collision** — Already handled in loader. Explicit wins.
3. **Param collision** — Spec's Tier 1 constraint: main zone must not be index when tabs present. Enforced in validator.
4. **Virtual model in main zone** — Shouldn't happen for composite pages (they have a real model). But if it does, @model_class is nil — handle in controller.
5. **scope_context with nested dot-path** — `:record.department.company_id` — limit to one level deep in Phase A for safety.
