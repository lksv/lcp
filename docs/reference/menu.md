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
