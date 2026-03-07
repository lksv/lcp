# Feature Specification: User Menu

**Status:** Proposed
**Date:** 2026-03-07

## Problem / Motivation

The platform has a navigation menu system (`top_menu`, `sidebar_menu`) for navigating between view groups, but there is no dedicated area for user-related actions. Users need a consistent place to:

- See who they are logged in as
- Access preferences (locale, timezone, items per page, theme)
- Use impersonation (already exists but lives in a separate banner)
- Access their profile
- Log out

Currently these actions are either missing, scattered, or handled entirely by the host app. A standardized user menu in the top-right corner provides a consistent UX across all LCP Ruby applications.

## User Scenarios

**Basic user:** Opens the dropdown in the top-right, sees their name and role. Changes language to Czech, sets timezone to Prague. Logs out when done.

**Admin:** Opens user menu, sees "Impersonate" option. Selects a role to test permissions. The impersonation indicator appears. Clicks "Stop impersonation" in the same menu to return.

**Host app developer:** Configures the user menu in `menu.yml` to add a custom "My Organization" link. Uses `LcpRuby.configure` to set `user_display_method` so the menu shows the user's full name.

**External auth app:** The host app uses Devise independently. Configures `logout_path` so the user menu logout button works correctly. The rest of the user menu (preferences, impersonation) works the same.

## Configuration & Behavior

### menu.yml — `user_menu` key

A new top-level key `user_menu` in `menu.yml`:

```yaml
menu:
  top_menu:
    - view_group: deals

  user_menu:
    items:
      - action: preferences
        icon: settings
      - action: impersonate
        icon: eye
        visible_when:
          role: [admin]
      - separator: true
      - label: "My Organization"
        url: /organization
        icon: building
      - separator: true
      - action: logout
        icon: log-out
```

### Built-in actions

User menu introduces a new item type: `action`. These are platform-provided behaviors:

| Action | Behavior | Auth modes |
|--------|----------|------------|
| `preferences` | Links to current user's preferences edit page (generator-based presenter) | all (hidden when generator not run) |
| `impersonate` | Opens impersonation UI (role selector) | all (visibility controlled by `impersonation_roles` config) |
| `logout` | Submits logout request | `:built_in`, `:external` (hidden in `:none`) |
| `profile` | Links to user profile page (generator-based) | `:built_in` (or when generator used) |

### Auto mode behavior

When `menu_mode: :auto` (default):
- If `user_menu` is not defined in `menu.yml`, the platform auto-generates a default user menu:
  - Preferences (if generator has been run)
  - Impersonate (if `impersonation_roles` is configured and user has the role)
  - Separator
  - Logout (unless auth mode is `:none`)
- If `user_menu` is defined, it is used as-is (no auto-append)

When `menu_mode: :strict`:
- `user_menu` is optional (unlike `top_menu`/`sidebar_menu`). If omitted, no user menu is rendered.

### Engine configuration

```ruby
LcpRuby.configure do |config|
  # User display in the menu trigger
  config.user_display_method = :name          # method on user object (default: :name)
  config.user_avatar_method = nil             # method returning avatar URL (nil = no avatar)

  # Logout (for :external auth mode)
  config.logout_path = :destroy_user_session_path  # Symbol (route helper) or String (path)
  config.logout_method = :delete                    # HTTP method for logout
end
```

Preferences availability is determined by whether the `lcp_ruby:user_preferences` generator has been run (i.e., the preferences presenter YAML exists). No separate toggle needed.

### Logout resolution

The logout link must work across all auth modes:

| Auth mode | Logout behavior |
|-----------|----------------|
| `:built_in` | `DELETE /auth/logout` (Devise, already exists) |
| `:external` | Uses `config.logout_path` — host app must configure this |
| `:none` | Logout item is hidden |

If `:external` and `logout_path` is not configured, the logout item is hidden (with a dev-mode warning log).

## User Preferences

### Generator

Preferences are implemented as a standard generator-based feature — the same pattern as `lcp_ruby:custom_fields` and `lcp_ruby:saved_filters`:

```bash
rails generate lcp_ruby:user_preferences
```

The generator creates:
- **Model YAML** — a model definition for user preferences (or extends the existing user model with `profile_data` JSON field)
- **Presenter YAML** — an edit form with the preference fields (locale, timezone, items_per_page, theme)
- **Permissions YAML** — each user can only edit their own preferences

The resulting preferences page is served by the standard `ResourcesController` — no custom controller, no special routes. The `action: preferences` menu item resolves to the edit page for the current user's record (e.g., `/user-preferences/<current_user.id>/edit`).

### Storage

Preferences are stored in the `profile_data` JSON column on the user model. This column already exists on `LcpRuby::User` (built-in auth). For external auth, the host app's user model must have a `profile_data` JSON column (or the host provides a custom accessor via concern).

| Auth mode | Storage | Mechanism |
|-----------|---------|-----------|
| `:built_in` | `profile_data` JSON column on `LcpRuby::User` | Provided automatically |
| `:external` | `profile_data` JSON column on host user model | Host includes `LcpRuby::UserPreferences` concern (or implements the contract) |
| `:none` | N/A — preferences disabled | No persistent user object; `action: preferences` is auto-hidden |

**Contract on user object** (`:built_in` and `:external`):
```ruby
# Reading
user.lcp_preferences  # => { "locale" => "cs", "timezone" => "Europe/Prague", ... }

# Writing
user.update_lcp_preferences(locale: "cs", timezone: "Europe/Prague")
```

For `LcpRuby::User` (built-in), these methods are provided automatically using `profile_data`. For external auth, the host app implements them on their user model (or uses a provided concern).

### Providable concern for external auth

```ruby
# Host app's User model
class User < ApplicationRecord
  include LcpRuby::UserPreferences  # Adds lcp_preferences / update_lcp_preferences

  # Requires: profile_data JSON column (or override storage)
end
```

### Preference field definition

The generator creates a presenter with the 4 built-in preference fields. Host apps can customize the generated presenter YAML to add/remove fields — standard presenter editing, no special extension mechanism.

**Built-in fields** (generated by default):

| Field | Type | Rails/system fallback | Platform fallback | Values |
|-------|------|----------------------|-------------------|--------|
| `locale` | select | `I18n.default_locale` | `"en"` | `I18n.available_locales` |
| `timezone` | select | `Time.zone.name` | `"UTC"` | ActiveSupport timezone list |
| `items_per_page` | select | — | `25` | `[10, 25, 50, 100]` |
| `theme` | select | — | `"auto"` | `["light", "dark", "auto"]` |

Host apps add custom fields to the same presenter YAML. Custom preference fields use `default_value` from presenter config or `nil`.

**Default resolution chain:** `presenter default_value` → `Rails/system default` → `platform hardcoded fallback`

### Preference application

Preferences are applied early in the request cycle (via `before_action` in `ApplicationController`):

```
Request → authenticate_user! → apply_user_preferences! → resolve_presenter → ...
```

- `locale` → sets `I18n.locale` for the request
- `timezone` → sets `Time.zone` for the request
- `items_per_page` → available to pagination (Kaminari `per`)
- `theme` → sets CSS class on `<body>` or `<html>` element

The `apply_user_preferences!` callback reads from `current_user.lcp_preferences` (when available) and applies values. When the generator has not been run or auth mode is `:none`, the callback is a no-op.

## Impersonation integration

Currently impersonation has its own yellow banner and separate UI flow. With the user menu:

1. "Impersonate" item in user menu opens the existing role selector (could be inline dropdown or link to existing UI)
2. When impersonating, the user menu trigger shows the impersonated role (e.g., "Admin (as Viewer)")
3. "Stop impersonation" appears as a menu item (replaces "Impersonate")
4. The yellow banner can remain as a secondary indicator

**Safety rule:** "Stop impersonation" must **always** be visible when `impersonating?` is true, regardless of `visible_when` constraints or the impersonated role's permissions. Without this, a user who impersonates a low-privilege role (one not in `impersonation_roles`) would lose the ability to stop impersonating via the menu. The rendering logic must check `impersonating?` first and unconditionally show the stop action, bypassing normal visibility rules. The yellow banner remains as a secondary safety net.

## Profile page (generator) — future enhancement

A separate generator creates a read-only profile page:

```bash
rails generate lcp_ruby:user_profile
```

This generates a presenter over the user model showing read-only user info (name, email, role, login history). It is a separate view group from preferences. When the generator is run, `action: profile` becomes available in the user menu; until then, `action: profile` is auto-hidden.

The preferences generator (`lcp_ruby:user_preferences`) handles the editable preferences form. The profile generator is a nice-to-have for apps that want a "My Account" page alongside preferences.

## Usage Examples

### Minimal setup (built-in auth)

No configuration needed — auto mode generates a default user menu with preferences and logout.

### External auth with custom logout

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.authentication = :external
  config.logout_path = :destroy_user_session_path
  config.logout_method = :delete
end
```

### Custom user menu items

```yaml
# config/lcp_ruby/menu.yml
menu:
  top_menu:
    - view_group: tasks

  user_menu:
    items:
      - action: preferences
        icon: settings
      - separator: true
      - label: "Help & Support"
        url: /help
        icon: help-circle
      - label: "API Docs"
        url: /api/docs
        icon: book
      - separator: true
      - action: impersonate
        visible_when:
          role: [admin]
      - separator: true
      - action: logout
```

### Host app with custom user display

```ruby
LcpRuby.configure do |config|
  config.user_display_method = :full_name
  config.user_avatar_method = :avatar_url
end
```

## General Implementation Approach

### Menu system extension

The existing `MenuDefinition` gains a third attribute `user_menu` alongside `top_menu` and `sidebar_menu`. `MenuDefinition.from_hash` parses the `user_menu` key.

**User menu items** are parsed by a new `UserMenuItem` class (not the existing `MenuItem`). This is a separate class because user menu items support the `action` key, which doesn't exist in navigation menus, and don't support `view_group` or `children` (no nested groups in the user dropdown).

`UserMenuItem` detection priority: `separator` > `action` > `url` (link). An item must have exactly one of these keys. `MenuItem::TYPES` is not modified.

`UserMenuItem` attributes:
- `type` — `:separator`, `:action`, or `:link`
- `action_name` — for `:action` type: `preferences`, `impersonate`, `logout`, `profile`
- `label` — optional override (built-in actions use i18n: `I18n.t("lcp_ruby.user_menu.actions.#{action_name}")`)
- `icon` — optional
- `url` — for `:link` type
- `visible_when` — role-based visibility (same as `MenuItem`)

### Rendering

The user menu renders as a dropdown in the top-right of the navigation bar, regardless of layout mode (top, sidebar, or both). The trigger shows user name (+ optional avatar). The dropdown contains the configured items.

### Preferences — standard CRUD via generator

No custom controller or special routes. The `lcp_ruby:user_preferences` generator creates model/presenter/permissions YAML. The standard `ResourcesController` handles the form. The `action: preferences` menu item resolves to the edit path for the current user's record. When the generator has not been run, `action: preferences` is auto-hidden (same pattern as `action: profile`).

### Request-level preference application

A `before_action` in `ApplicationController` reads the current user's preferences and applies them (locale, timezone, items_per_page stored in an instance variable for Kaminari).

### Auto-generation

When no `user_menu` is defined and mode is `:auto`, `MenuBuilder` (or equivalent) constructs a default set of user menu items based on the current configuration (auth mode, impersonation_roles, preferences_enabled).

## Decisions

1. **Preferences via generator + standard CRUD** — `lcp_ruby:user_preferences` generator creates model/presenter/permissions YAML. Standard `ResourcesController` handles the form. No custom controller, no special routes, no route conflict with `/:lcp_slug`. Consistent with `lcp_ruby:custom_fields` and `lcp_ruby:saved_filters` patterns.
2. **`profile_data` JSON column** for preferences storage (`:built_in` / `:external`). Preferences disabled for `:none` mode (no persistent user object).
3. **`user_menu` in menu.yml** — consistent with existing menu configuration pattern.
4. **Built-in actions as a new menu item type** — cleaner than custom URLs for platform-provided behaviors.
5. **Auto-generate default user menu** — zero-config experience for the common case.
6. **Providable concern for external auth** — `LcpRuby::UserPreferences` mixin keeps the contract simple.
7. **Custom preference fields supported** — host apps customize the generated presenter YAML to add/remove fields. The generated presenter is the single source of truth for available fields — no duplicate list in engine configuration.
8. **Platform provides light/dark theme** — built-in CSS theme support (light/dark/auto). Host app can override or extend via standard CSS/asset pipeline. The `theme` preference drives a CSS class on `<body>` (e.g., `lcp-theme-light`, `lcp-theme-dark`). When theme is `auto`, **no theme class** is set on `<body>`, and the platform stylesheet uses `@media (prefers-color-scheme: dark)` to apply dark theme variables — this is pure CSS, requires no JS, and avoids flash-of-wrong-theme on page load. The platform ships a single stylesheet with both theme definitions gated by the class selector and the media query fallback.
9. **Notification preferences extensibility** — the preference system must be designed to accommodate future notification preferences (email, in-app, webhook channels). Adding fields to the generated presenter YAML is straightforward.
10. **Hybrid preference defaults** — resolution chain: `presenter default_value` → `Rails/system default` → `platform hardcoded fallback`. For `locale`: `I18n.default_locale` ?? `"en"`. For `timezone`: `Time.zone.name` ?? `"UTC"`. For `items_per_page`: `25`. For `theme`: `"auto"`. Custom fields use `default_value` from presenter config or `nil`.
11. **No keyboard shortcut for user menu in v1** — standard click/hover interaction is sufficient. Can be added later if needed.
12. **Theme switching via form submit** — consistent with other preferences. Same save flow, page reload applies the new theme CSS class.
13. **`UserMenuItem` as a separate class from `MenuItem`** — user menu items support `action` (not `view_group` or `children`), so a separate class avoids polluting the navigation menu parser. Detection priority: `separator` > `action` > `url`.
14. **"Stop impersonation" bypasses visibility rules** — when `impersonating?` is true, the "Stop impersonation" item is unconditionally shown regardless of `visible_when` or the impersonated role. This prevents the user from getting stuck in a low-privilege impersonated role that can't see the menu item.
15. **Generator-based actions auto-hidden when not run** — `action: preferences` and `action: profile` are auto-hidden if their respective generator has not been run. No boot-time error, no broken links.

## Open Questions

None at this time. All major design questions have been resolved.
