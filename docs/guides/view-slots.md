# View Slots

View Slots let host applications inject custom UI components into LCP Ruby page templates without overriding the templates themselves. You can add toolbar buttons, filter panels, status bars, and other widgets to index and show pages.

## When to Use

- You need a custom button in the toolbar (e.g., "Export CSV", "Bulk Import")
- You want to add a widget above or below the content area (e.g., KPI cards, comments)
- A platform feature needs to inject UI into pages (e.g., saved filters, workflow status)
- You want to conditionally show/hide built-in UI elements

## Quick Start

Register a component in an initializer:

```ruby
# config/initializers/lcp_ruby_slots.rb
LcpRuby::ViewSlots::Registry.register(
  page: :index,
  slot: :toolbar_end,
  name: :export_csv,
  partial: "shared/export_csv_button",
  position: 15
)
```

Create the partial:

```erb
<%# app/views/shared/_export_csv_button.html.erb %>
<% if slot_context.evaluator.can?(:read) %>
  <%= link_to "Export CSV", export_path(format: :csv), class: "btn" %>
<% end %>
```

The button appears in the toolbar of every index page, between the built-in components at position 10 and 20.

## Step 1: Understand the Slot Layout

### Index Page

```
┌─────────────────────────────────────────────┐
│ :page_header                                │
├─────────────────────────────────────────────┤
│ Page Title                                  │
│ ┌─────────┬──────────────┬─────────────────┐│
│ │:toolbar │ :toolbar     │ :toolbar_end    ││
│ │ _start  │  _center     │                 ││
│ └─────────┴──────────────┴─────────────────┘│
├─────────────────────────────────────────────┤
│ :filter_bar                                 │
│  (search, predefined filters, advanced)     │
├─────────────────────────────────────────────┤
│                                             │
│  Table / Content                            │
│                                             │
├─────────────────────────────────────────────┤
│ :below_content                              │
│  (pagination)                               │
└─────────────────────────────────────────────┘
```

### Show Page

```
┌─────────────────────────────────────────────┐
│ :page_header                                │
├─────────────────────────────────────────────┤
│ Record Title                                │
│ ┌───────────────────┬──────────────────────┐│
│ │ :toolbar_start    │ :toolbar_end         ││
│ │ (back, switcher)  │ (copy, edit, delete) ││
│ └───────────────────┴──────────────────────┘│
├─────────────────────────────────────────────┤
│                                             │
│  Sections / Fields                          │
│                                             │
├─────────────────────────────────────────────┤
│ :below_content                              │
└─────────────────────────────────────────────┘
```

## Step 2: Add a Custom Toolbar Button

Add an "Import" button next to "New" on the shipments index:

```ruby
LcpRuby::ViewSlots::Registry.register(
  page: :index,
  slot: :toolbar_end,
  name: :bulk_import,
  partial: "shipments/bulk_import_button",
  position: 15,
  enabled: ->(ctx) { ctx.presenter.slug == "shipments" }
)
```

```erb
<%# app/views/shipments/_bulk_import_button.html.erb %>
<% if slot_context.evaluator.can?(:create) %>
  <%= link_to "Import CSV", import_shipments_path, class: "btn" %>
<% end %>
```

Key points:
- `position: 15` places it after `collection_actions` (position 10)
- `enabled:` callback scopes it to the "shipments" presenter only
- The partial uses `slot_context.evaluator` for permission checks

## Step 3: Add Conditional Components

Show a "Publish" button only for draft records on the show page:

```ruby
LcpRuby::ViewSlots::Registry.register(
  page: :show,
  slot: :toolbar_end,
  name: :publish_button,
  partial: "articles/publish_button",
  position: 5,
  enabled: ->(ctx) {
    ctx.presenter.slug == "articles" &&
    ctx.record&.status == "draft" &&
    ctx.evaluator.can?(:update)
  }
)
```

```erb
<%# app/views/articles/_publish_button.html.erb %>
<%= button_to "Publish",
    publish_article_path(slot_context.record),
    method: :patch, class: "btn btn-primary" %>
```

The `enabled` callback has access to the full `SlotContext`: presenter, record, evaluator, params, and custom locals.

## Step 4: Override a Built-in Component

Replace the built-in search form with a custom implementation:

```ruby
LcpRuby::ViewSlots::Registry.register(
  page: :index,
  slot: :filter_bar,
  name: :search,              # Same name as built-in → replaces it
  partial: "shared/custom_search",
  position: 10
)
```

```erb
<%# app/views/shared/_custom_search.html.erb %>
<% if slot_context.presenter.search_config["enabled"] %>
  <div class="custom-search">
    <%= form_tag resources_path, method: :get do %>
      <%= text_field_tag :qs, slot_context.params[:qs],
          placeholder: "Search #{slot_context.presenter.label}...",
          class: "custom-search-input",
          data: { autocomplete_url: autocomplete_path } %>
    <% end %>
  </div>
<% end %>
```

Registering with `name: :search` (the same name as the built-in) replaces the default search component entirely.

## Step 5: Add a Page Header Widget

Add KPI cards above the deals index:

```ruby
LcpRuby::ViewSlots::Registry.register(
  page: :index,
  slot: :page_header,
  name: :deal_stats,
  partial: "deals/kpi_cards",
  position: 10,
  enabled: ->(ctx) { ctx.presenter.slug == "deals" }
)
```

```erb
<%# app/views/deals/_kpi_cards.html.erb %>
<div class="kpi-cards">
  <div class="kpi-card">
    <span class="kpi-value"><%= slot_context.records.count %></span>
    <span class="kpi-label">Total Deals</span>
  </div>
  <div class="kpi-card">
    <span class="kpi-value"><%= slot_context.records.sum(:amount) %></span>
    <span class="kpi-label">Pipeline Value</span>
  </div>
</div>
```

## Step 6: Pass Custom Data from Controller

When the controller needs to pass extra data to slot partials (beyond what `SlotContext` provides), use `@slot_locals`:

```ruby
# In a custom controller or concern
class ShipmentsController < LcpRuby::ResourcesController
  before_action :set_slot_locals, only: :index

  private

  def set_slot_locals
    @slot_locals = {
      warehouse_count: Warehouse.active.count,
      last_import: Import.last&.created_at
    }
  end
end
```

```erb
<%# In slot partial %>
<div class="import-status">
  Last import: <%= slot_context.locals[:last_import]&.strftime("%Y-%m-%d") || "Never" %>
</div>
```

## Writing Slot Partials

### Use `slot_context` for Data

Always access presenter, params, evaluator, records, and record through `slot_context`:

```erb
<%# Good — uses slot_context %>
<% if slot_context.presenter.search_config["enabled"] %>
<% if slot_context.evaluator.can?(:create) %>
<%= text_field_tag :qs, slot_context.params[:qs] %>

<%# Avoid — bypasses slot_context %>
<% if current_presenter.search_config["enabled"] %>
```

### Use View Context for Route Helpers

Route helpers and Rails tag helpers come from the view context directly:

```erb
<%# Route helpers — from view context %>
<%= link_to "Back", resources_path, class: "btn" %>
<%= link_to "New", new_resource_path, class: "btn" %>

<%# Rails helpers — from view context %>
<%= form_tag resources_path, method: :get do %>
  <%= text_field_tag :qs, slot_context.params[:qs] %>
<% end %>
```

## Testing

### Unit Tests

Test the registry directly:

```ruby
RSpec.describe "Custom slot registration" do
  before { LcpRuby::ViewSlots::Registry.clear! }

  it "registers and retrieves a custom component" do
    LcpRuby::ViewSlots::Registry.register(
      page: :index, slot: :toolbar_end, name: :export,
      partial: "shared/export", position: 15
    )

    components = LcpRuby::ViewSlots::Registry.components_for(:index, :toolbar_end)
    expect(components.map(&:name)).to include(:export)
  end
end
```

### Integration Tests

Test that components render in the page:

```ruby
RSpec.describe "Export button", type: :request do
  before do
    load_integration_metadata!("crm")
    stub_current_user(role: "admin")

    LcpRuby::ViewSlots::Registry.register(
      page: :index, slot: :toolbar_end, name: :export,
      partial: "shared/export_button", position: 15
    )
  end

  after do
    LcpRuby::ViewSlots::Registry.clear!
    LcpRuby::ViewSlots::Registry.register_built_ins!
  end

  it "renders the export button on the index page" do
    get "/deals"
    expect(response.body).to include("Export CSV")
  end
end
```

## Built-in Component Positions

Reference for inserting custom components between built-ins:

### Index Toolbar End

```
position 5  — manage_all (custom fields link)
position 10 — collection_actions (New button)
```

### Index Filter Bar

```
position 10 — search (quick search form)
position 20 — predefined_filters (scope buttons)
position 30 — advanced_filter (visual filter builder)
```

### Show Toolbar Start

```
position 10 — view_switcher (view group tabs)
position 20 — back_to_list (back link)
```

### Show Toolbar End

```
position 10 — copy_url (copy link button)
position 20 — single_actions (edit, delete buttons)
```

---

## What's Next

- [View Slots Reference](../reference/view-slots.md) — Complete API reference
- [Custom Renderers](custom-renderers.md) — Custom renderers for host applications
- [Extensibility Guide](extensibility.md) — All extension mechanisms
