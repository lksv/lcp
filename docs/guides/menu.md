# Menu Guide

This guide walks you through setting up custom navigation menus for your LCP Ruby application.

## Default Behavior (No menu.yml)

Without a `menu.yml`, LCP Ruby auto-generates a flat top bar from your view groups, sorted by their `navigation.position`:

```
[ Projects ] [ Tasks ] [ Settings ]
```

This works well for small applications with a few models.

## Adding a menu.yml

Create `config/lcp_ruby/menu.yml` to customize navigation:

### Step 1: Simple Top Bar

```yaml
menu:
  top_menu:
    - view_group: projects
    - view_group: tasks
    - view_group: settings
```

This produces the same flat top bar, but now you control the order.

### Step 2: Add Dropdown Grouping

Group related items into dropdowns:

```yaml
menu:
  top_menu:
    - view_group: projects
    - label: "Administration"
      icon: shield
      children:
        - view_group: users
        - view_group: settings
```

The "Administration" item becomes a hover dropdown containing "Users" and "Settings".

### Step 3: Add Custom Links

Link to pages outside the LCP engine:

```yaml
menu:
  top_menu:
    - view_group: projects
    - label: "Dashboard"
      icon: home
      url: /dashboard
    - label: "Tools"
      children:
        - view_group: tasks
        - separator: true
        - label: "Reports"
          url: /reports
```

### Step 4: Switch to Sidebar

Replace `top_menu` with `sidebar_menu`:

```yaml
menu:
  sidebar_menu:
    - view_group: projects
    - label: "Work"
      icon: briefcase
      children:
        - view_group: tasks
    - view_group: settings
      position: bottom
```

Groups become collapsible sections. Items with `position: bottom` are pinned to the sidebar bottom.

### Step 5: Combined Layout

Use both for a top bar + sidebar:

```yaml
menu:
  top_menu:
    - label: "Dashboard"
      url: /dashboard
    - label: "Reports"
      url: /reports

  sidebar_menu:
    - view_group: projects
    - view_group: tasks
    - view_group: settings
      position: bottom
```

## Role-Based Visibility

Restrict menu items to specific roles:

```yaml
menu:
  sidebar_menu:
    - view_group: projects
    - view_group: tasks
    - label: "Admin"
      icon: shield
      visible_when:
        role: [admin]
      children:
        - view_group: users
        - view_group: audit_log
```

The "Admin" section and all its children are hidden from non-admin users.

## Hiding View Groups from Navigation

Some view groups exist for routing and view switching but should not appear in navigation:

```yaml
# config/lcp_ruby/views/audit_log.yml
view_group:
  model: audit_log
  primary: audit_log
  navigation: false
  views:
    - presenter: audit_log
```

The `navigation: false` setting:
- Removes the view group from auto-generated navigation
- Prevents auto-append in `:auto` mode
- Does not affect direct URL access (e.g., `/audit-log` still works)

## Strict Mode

For production apps where you want full control:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.menu_mode = :strict
end
```

In strict mode:
- `menu.yml` is required (raises error if missing)
- No view groups are auto-appended
- View groups must use `navigation: false` (not `navigation: {position: 1}`)

## Auto-Append Behavior

In `:auto` mode with `menu.yml`, any navigable view groups not referenced in the menu are automatically appended to `top_menu`. This ensures new models are visible without manual menu updates.

To prevent a view group from being auto-appended, set `navigation: false` on it.
