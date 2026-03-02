# View Slots Reference

The View Slots system provides named injection points in page templates where platform features and host applications can register UI components. Components are rendered in position order, can be conditionally enabled, and can be overridden by name.

## How It Works

- Page templates (index, show) call `render_slot(:slot_name, page: :index)` at defined injection points
- Components register into `(page, slot)` pairs via `ViewSlots::Registry`
- Each component has a `name`, `partial`, `position`, and optional `enabled` callback
- At render time, all components for a slot are filtered by `enabled?`, sorted by `position`, and rendered
- Registering a component with the same `name` in the same slot replaces the previous one (host app overrides)

## Registry API

### `ViewSlots::Registry.register`

Register a new component or replace an existing one.

```ruby
LcpRuby::ViewSlots::Registry.register(
  page:     :index,                       # Required. :index or :show
  slot:     :toolbar_end,                 # Required. Slot name (symbol or string)
  name:     :my_button,                   # Required. Unique within the slot
  partial:  "my_app/slots/my_button",     # Required. Rails partial path
  position: 15,                           # Optional. Default: 10. Lower = earlier
  enabled:  ->(ctx) { true }             # Optional. Lambda receiving SlotContext
)
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `page` | Symbol/String | Yes | — | Page type: `:index` or `:show` |
| `slot` | Symbol/String | Yes | — | Slot name (see [Slot Names](#slot-names)) |
| `name` | Symbol/String | Yes | — | Component name. Must be unique within the slot. Re-registering the same name replaces the component. |
| `partial` | String | Yes | — | Rails partial path |
| `position` | Integer | No | 10 | Render order within the slot (ascending). Built-ins use multiples of 10. |
| `enabled` | Lambda | No | Always enabled | `(SlotContext) -> Boolean`. Return `false` to skip rendering. |

### `ViewSlots::Registry.components_for(page, slot)`

Returns an array of `SlotComponent` objects sorted by position.

```ruby
components = LcpRuby::ViewSlots::Registry.components_for(:index, :toolbar_end)
# => [#<SlotComponent name=:manage_all position=5>, #<SlotComponent name=:collection_actions position=10>]
```

### `ViewSlots::Registry.registered?(page, slot, name)`

Returns `true` if a component with the given name is registered in the slot.

```ruby
LcpRuby::ViewSlots::Registry.registered?(:index, :filter_bar, :search)
# => true
```

### `ViewSlots::Registry.clear!`

Removes all registered components. Used in test teardown.

## Slot Names

### Index Page

| Slot | Location | Built-in Components |
|------|----------|---------------------|
| `:page_header` | Above the page title | *(none)* |
| `:toolbar_start` | Toolbar left side | *(none)* |
| `:toolbar_center` | Toolbar middle | `view_switcher` (10) |
| `:toolbar_end` | Toolbar right side | `manage_all` (5), `collection_actions` (10) |
| `:filter_bar` | Below toolbar | `search` (10), `predefined_filters` (20), `advanced_filter` (30) |
| `:below_content` | Below the table | `pagination` (10) |

### Show Page

| Slot | Location | Built-in Components |
|------|----------|---------------------|
| `:page_header` | Above the page title | *(none)* |
| `:toolbar_start` | Toolbar left side | `view_switcher` (10), `back_to_list` (20) |
| `:toolbar_end` | Toolbar right side | `copy_url` (10), `single_actions` (20) |
| `:below_content` | Below the sections | *(none)* |

## Built-in Components

All built-in components are registered at engine boot via `ViewSlots::Registry.register_built_ins!`.

| Name | Page | Slot | Position | Description |
|------|------|------|----------|-------------|
| `view_switcher` | index | toolbar_center | 10 | View group tab navigation |
| `manage_all` | index | toolbar_end | 5 | "Manage All" link (custom fields) |
| `collection_actions` | index | toolbar_end | 10 | "New" button and other collection actions |
| `search` | index | filter_bar | 10 | Quick search form |
| `predefined_filters` | index | filter_bar | 20 | Predefined filter scope buttons |
| `advanced_filter` | index | filter_bar | 30 | Visual filter builder panel |
| `pagination` | index | below_content | 10 | Kaminari pagination |
| `view_switcher` | show | toolbar_start | 10 | View group tab navigation |
| `back_to_list` | show | toolbar_start | 20 | "Back to list" link |
| `copy_url` | show | toolbar_end | 10 | "Copy link" button |
| `single_actions` | show | toolbar_end | 20 | Edit, Delete, and custom action buttons |

## SlotContext

Every slot partial receives a `slot_context` local variable — an immutable data object with the current page state.

| Attribute | Type | Available on | Description |
|-----------|------|--------------|-------------|
| `presenter` | `PresenterDefinition` | All pages | Current presenter (slug, config, labels) |
| `model_definition` | `ModelDefinition` | All pages | Model metadata (fields, validations) |
| `evaluator` | `PermissionEvaluator` | All pages | Permission checks (`can?`, `field_writable?`) |
| `action_set` | `ActionSet` | All pages | Visible actions for the current user |
| `params` | Hash | All pages | Request parameters (filter, qs, sort) |
| `records` | `ActiveRecord::Relation` | Index | Paginated record collection |
| `record` | `ActiveRecord::Base` | Show | Current record |
| `locals` | Hash | All pages | Custom data from controller (`@slot_locals`) |

### Accessing SlotContext in Partials

Built-in partials use `slot_context` for all data access:

```erb
<%# Use slot_context.presenter, not current_presenter %>
<% if slot_context.presenter.search_config["enabled"] %>
  ...
<% end %>

<%# Use slot_context.params, not params %>
<%= text_field_tag :qs, slot_context.params[:qs] %>

<%# Use slot_context.evaluator for permission checks %>
<% if slot_context.evaluator.can?(:create) %>
  ...
<% end %>
```

Route helpers (`resources_path`, `new_resource_path`) and Rails helpers (`request.url`, `link_to`, `form_tag`) are accessed from the view context directly — they are not part of `SlotContext`.

### Passing Custom Data via `locals`

Controllers can pass arbitrary data to slot partials through `@slot_locals`:

```ruby
# In controller action
@slot_locals = { manage_path: manage_custom_fields_path }
```

```erb
<%# In slot partial %>
<% manage_path = slot_context.locals[:manage_path] %>
<% if manage_path %>
  <%= link_to "Manage", manage_path, class: "btn" %>
<% end %>
```

## SlotComponent

Immutable value object representing a registered component.

| Attribute | Type | Description |
|-----------|------|-------------|
| `page` | Symbol | `:index` or `:show` |
| `slot` | Symbol | Slot name |
| `name` | Symbol | Component identifier |
| `partial` | String | Rails partial path |
| `position` | Integer | Render order (ascending) |
| `enabled_callback` | Lambda or nil | Conditional rendering callback |

### `enabled?(context)`

Returns `true` if the component should render. Delegates to `enabled_callback` if set, otherwise returns `true`.

## View Helper

### `render_slot(slot, page:)`

Renders all enabled components for a slot, joined as HTML-safe output.

```erb
<%= render_slot(:toolbar_end, page: :index) %>
```

Returns empty string if no components are registered for the slot. Components are:

1. Fetched from `Registry.components_for(page, slot)`
2. Filtered by `component.enabled?(slot_context)`
3. Rendered via `render partial: component.partial, locals: { slot_context: context }`
4. Joined with `safe_join`

## Position Ordering

Built-in components use positions in multiples of 10, leaving gaps for host app insertions:

```
position 5  → host app component (before built-in)
position 10 → built-in component
position 15 → host app component (after built-in)
position 20 → next built-in component
```

Components at the same position are rendered in registration order.

## Name-Based Override

Registering a component with the same `name` in the same `(page, slot)` replaces the previous registration:

```ruby
# Override the built-in search with a custom implementation
LcpRuby::ViewSlots::Registry.register(
  page: :index, slot: :filter_bar, name: :search,
  partial: "my_app/custom_search", position: 10
)
```

This replaces the built-in search partial with the host app's version.

---

## What's Next

- [View Slots Guide](../guides/view-slots.md) — Step-by-step guide to customizing page layouts
- [Custom Renderers](../guides/custom-renderers.md) — Custom renderers for host applications
- [Extensibility Guide](../guides/extensibility.md) — All extension mechanisms
- [Page Layouts & View Slots Spec](../design/page_layout_and_slots.md) — Full feature specification including future layout variants
