# Impersonation ("View as Role X")

Impersonation allows authorized users (e.g., admins) to view the application as if they had a different role, without changing their actual identity. This is useful for testing permissions, debugging access issues, and verifying what other roles see.

## Setup

Enable impersonation by setting `impersonation_roles` in your initializer:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.impersonation_roles = ["admin"]
end
```

Only users whose real role includes one of the listed roles can activate impersonation. When the list is empty (default), impersonation is disabled entirely.

## How It Works

1. **Activation:** An authorized user selects a role from the "View as" dropdown in the navigation bar, or sends a POST request to `/impersonate` with `role` parameter.

2. **Effect:** The permission system evaluates all access checks using the impersonated role instead of the user's real role. This affects:
   - Presenter access (which pages are visible)
   - CRUD permissions
   - Field-level access (readable/writable fields)
   - Custom action availability
   - Row-level scopes
   - Menu filtering

3. **Identity preserved:** The user's real identity is never changed. Only the role used for permission evaluation is overridden. Audit logs still record the real user.

4. **Deactivation:** Click "Stop impersonation" in the yellow banner, or send a DELETE request to `/impersonate`.

## UI Elements

When impersonation is available but not active, a "View as" dropdown appears in the navigation bar listing all roles defined across permission files. Selecting a role and clicking "Impersonate" activates impersonation.

When impersonation is active, a yellow banner appears at the top of every page showing:
- The impersonated role name
- A "Stop impersonation" button

## Routes

The engine adds two routes for impersonation:

| Method | Path | Action |
|--------|------|--------|
| POST | `/impersonate` | Set impersonation (param: `role`) |
| DELETE | `/impersonate` | Clear impersonation |

Both routes redirect back to the root path with a flash message.

## Security

- Only users with a real role in `config.impersonation_roles` can impersonate
- The real user identity is never changed — only the permission evaluator's role is overridden
- All authorization still runs server-side via Pundit
- If a user impersonates a role that cannot access the current page, they are redirected with an access denied message
- Impersonation state is stored in the session (`session[:lcp_impersonate_role]`)

## Example

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.impersonation_roles = ["admin", "super_admin"]
end
```

With this configuration, users with the `admin` or `super_admin` role can impersonate any other role. A `viewer` or `sales_rep` user will not see the impersonation controls.

Source: `app/controllers/lcp_ruby/impersonation_controller.rb`, `lib/lcp_ruby/authorization/impersonated_user.rb`, `lib/lcp_ruby/configuration.rb`
