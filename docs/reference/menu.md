# Menu Reference

The menu system controls the navigation layout of your LCP Ruby application. It supports top bar, sidebar, or combined layouts with dropdown grouping, custom links, separators, and role-based visibility.

## Configuration

```ruby
LcpRuby.configure do |config|
  config.menu_mode = :auto    # :auto (default) or :strict
end
```

| Mode | No menu.yml | menu.yml exists |
|------|------------|-----------------|
| `:auto` | Auto-generate nav from view groups | Use menu + auto-append unreferenced view groups |
| `:strict` | Raises `MetadataError` | Use menu only (sole source of truth) |

## File Location

```
config/lcp_ruby/menu.yml
```

## YAML Schema

```yaml
menu:
  top_menu:        # Top bar navigation items
    - ...
  sidebar_menu:    # Sidebar navigation items
    - ...
```

**Layout mode** is determined by which keys are present:

| Keys present | Layout |
|-------------|--------|
| Only `top_menu` | Top bar |
| Only `sidebar_menu` | Sidebar |
| Both | Top bar + sidebar |

## Menu Item Types

Each item in the menu arrays must be one of four types, determined by which key is present:

### View Group Reference

References an existing view group. Label, icon, and slug are resolved from the view group's primary presenter.

```yaml
- view_group: deals
```

Optional overrides:

```yaml
- view_group: deals
  label: "My Deals"          # Override resolved label
  icon: dollar               # Override resolved icon
  visible_when:
    role: [admin, manager]
  position: bottom            # Pin to sidebar bottom
```

### Group (Dropdown / Collapsible Section)

Container for nested items. Renders as a dropdown in top bar, collapsible section in sidebar.

```yaml
- label: "CRM"
  icon: briefcase
  children:
    - view_group: deals
    - view_group: companies
    - separator: true
    - label: "Reports"
      url: /crm/reports
```

**Required:** `label`

### Custom Link

Link to an external or host app URL.

```yaml
- label: "Dashboard"
  icon: home
  url: /dashboard
```

**Required:** `label`, `url`

### Separator

Visual divider between items.

```yaml
- separator: true
```

## Optional Keys

These keys can be added to any item (except separators):

| Key | Type | Description |
|-----|------|-------------|
| `label` | string | Display text (required for groups and links, optional override for view groups) |
| `icon` | string | Icon name (resolved from presenter for view groups) |
| `visible_when` | object | Role-based visibility filter |
| `position` | string | `"bottom"` pins item to sidebar bottom |
| `badge` | object | Dynamic badge display (see [Badges](#badges) section) |

## Role-Based Visibility

Use `visible_when` to restrict menu items by role:

```yaml
- label: "Admin"
  visible_when:
    role: [admin]
  children:
    - view_group: users
    - view_group: settings
```

The user's role is read using the configured `role_method` (default: `lcp_role`). If the user has none of the listed roles, the item (and all its children for groups) is hidden.

View group items also check presenter accessibility via the permission system.

## Detection Priority

When parsing a menu item hash, keys are checked in this order:

1. `separator` — separator item
2. `view_group` — view group reference
3. `children` — group with nested items
4. `url` — custom link

## Auto Mode Behavior

In `:auto` mode (the default):

1. If no `menu.yml` exists, navigation is auto-generated from view groups (same as before)
2. If `menu.yml` exists, it is used as the menu definition
3. Any navigable view groups not referenced in `menu.yml` are automatically appended to `top_menu`
4. View groups with `navigation: false` are excluded from auto-generation and auto-append

## Strict Mode Behavior

In `:strict` mode:

1. `menu.yml` is required — raises `MetadataError` if missing
2. The menu is the sole source of truth — no auto-append
3. View groups must not have `navigation` config (only `navigation: false` is allowed)

## Badges

Menu items can display dynamic badges — counts, text labels, or icons — populated by data providers.

### Badge YAML Schema

```yaml
- view_group: tasks
  badge:
    provider: open_tasks        # Required: data provider name
    renderer: count_badge       # One of: renderer, template, or partial
    options:                    # Optional: passed to renderer
      color: "#dc3545"
```

Exactly one rendering form must be specified:

| Key | Description |
|-----|-------------|
| `renderer` | A `Display::BaseRenderer` subclass from `Display::RendererRegistry` |
| `template` | String with `{key}` interpolation, wrapped in a badge `<span>` |
| `partial` | Rails partial path, receives `data` local variable |

### Data Providers

Data providers are registered in `Services::Registry` under the `data_providers` category. They are auto-discovered from `app/lcp_services/data_providers/`.

**Contract:** `call(user:)` → data (any shape) or `nil` (nil = hide badge).

```ruby
# app/lcp_services/data_providers/open_tasks.rb
module LcpRuby::HostServices::DataProviders
  class OpenTasks
    def self.call(user:)
      LcpRuby::Dynamic::Task.where(status: "open").count
    end
  end
end
```

### Built-in Badge Renderers

| Renderer | Input | Output |
|----------|-------|--------|
| `count_badge` | Positive `Integer` | Red pill with count (nil for 0 or non-integer) |
| `text_badge` | `String` or `Hash` with `"text"`, optional `"color"` | Uppercase text badge with optional background color |
| `icon_badge` | `String` or `Hash` with `"icon"`, optional `"color"` | Icon element with optional color |

### Template Form

For the `template` form, `{key}` placeholders are interpolated from the provider data:

- If provider returns a **Hash**, keys are available directly: `{count}`, `{label}`
- If provider returns a **simple value** (Integer, String), use `{value}`

```yaml
- view_group: inbox
  badge:
    provider: unread_messages
    template: "{count} new"
```

### Partial Form

The partial receives a `data` local variable with the provider's return value:

```yaml
- view_group: system_health
  badge:
    provider: health_status
    partial: "badges/health_indicator"
```

### Badge Examples

```yaml
menu:
  sidebar_menu:
    # Count badge on tasks
    - view_group: tasks
      badge:
        provider: open_tasks
        renderer: count_badge

    # Text badge with color
    - view_group: inbox
      badge:
        provider: unread_messages
        template: "{count} new"

    # Badge on a group
    - label: "CRM"
      badge:
        provider: crm_alerts
        renderer: text_badge
        options:
          color: "#dc3545"
      children:
        - view_group: deals
```

## Complete Example

```yaml
menu:
  top_menu:
    - view_group: deals
    - label: "CRM"
      icon: briefcase
      children:
        - view_group: companies
        - view_group: contacts
        - separator: true
        - label: "Reports"
          url: /crm/reports

  sidebar_menu:
    - view_group: deals
    - label: "CRM"
      icon: briefcase
      children:
        - view_group: companies
        - view_group: contacts
    - label: "Settings"
      icon: settings
      position: bottom
      visible_when:
        role: [admin]
      children:
        - view_group: users
        - view_group: audit_log
```
