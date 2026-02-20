# Role Source Guide

This guide walks through setting up DB-backed role management. By default, roles in LCP Ruby are implicit string keys in permissions YAML. With `role_source: :model`, roles become database records with a management UI, validation, and automatic cache invalidation.

## When to Use DB-Backed Roles

Use `role_source: :model` when:

- Administrators need to create, rename, or deactivate roles at runtime
- You want validation that role names in user records actually exist
- You need a management UI for role definitions (CRUD, search, active/inactive toggle)
- You want to audit which roles exist and when they were created

Stick with `role_source: :implicit` (the default) when:

- Roles are static and change only during development
- You don't need runtime role management
- You want the simplest possible setup

## Quick Start

### Step 1: Run the Generator

```bash
rails generate lcp_ruby:role_model
```

This creates:

```
config/lcp_ruby/
  models/role.yml          # Role model definition
  presenters/roles.yml     # CRUD presenter
  permissions/role.yml     # Admin/viewer permissions
  views/roles.yml          # Navigation entry
```

And adds `config.role_source = :model` to your initializer.

### Step 2: Start the Application

```bash
rails s
```

The engine automatically creates the `roles` table and registers the model.

### Step 3: Create Roles

Navigate to `/roles` in your browser (or wherever the engine is mounted). Create roles matching the names used in your permissions YAML files:

| Name | Label | Description |
|------|-------|-------------|
| `admin` | Administrator | Full system access |
| `manager` | Manager | Create and edit, no delete |
| `viewer` | Viewer | Read-only access |

Role names must match exactly — they are the same strings used as keys in your `permissions/*.yml` files.

### Step 4: Verify

After creating roles, the authorization system automatically filters user role names against the registry. If a user has a role that doesn't exist in the database, it is silently ignored (with a warning logged).

## Custom Model Setup

If you don't want to use the generator, you can define the role model manually.

### Minimal Model

The only requirement is a `name` field of type `string`:

```yaml
# config/lcp_ruby/models/role.yml
model:
  name: role
  fields:
    - name: name
      type: string
      validations:
        - type: presence
        - type: uniqueness
  options:
    timestamps: true
```

### Custom Field Names

If your model uses different column names, configure the field mapping:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.role_source = :model
  config.role_model = "access_level"
  config.role_model_fields = { name: "role_key", active: "enabled" }
end
```

```yaml
# config/lcp_ruby/models/access_level.yml
model:
  name: access_level
  fields:
    - name: role_key
      type: string
      validations:
        - type: presence
        - type: uniqueness
    - name: enabled
      type: boolean
      default: true
  options:
    timestamps: true
```

### Active/Inactive Roles

If your model has an `active` (or mapped equivalent) boolean field, only roles with `active: true` are included in the registry. This lets you deactivate a role without deleting it — useful for preserving audit history.

If the active field is not present on the model, all roles are treated as active.

## How Role Validation Works

### Authorization Flow

When `role_source: :model`:

```
User logs in
  │
  ├── user.lcp_role returns ["admin", "old_role"]
  │
  ├── PermissionEvaluator filters through Registry:
  │   ├── "admin"    → exists in DB → kept
  │   └── "old_role" → NOT in DB    → removed, warning logged
  │
  ├── Remaining roles: ["admin"]
  │
  └── Normal permission evaluation continues with ["admin"]
```

When `role_source: :implicit` (default), no filtering happens — all role names from the user are passed directly to the permission evaluator.

### Warning Logs

When a user has a role name that doesn't exist in the database:

```
[LcpRuby::Roles] User #42 has unknown roles: old_role, ghost_role
```

This helps identify stale role assignments after roles are renamed or deactivated.

## Relationship to Permissions

Role source and permissions are independent systems:

- **Role source** answers: "Which role names exist?"
- **Permissions YAML** answers: "What can each role do?"

You still define permissions in YAML files. The role source only validates that role names are real. If a role exists in the database but has no permissions YAML entry, it falls back to `default_role`. If a role exists in permissions YAML but not in the database, users with that role name are filtered to `default_role`.

For consistency, ensure the roles defined in your database match the role keys in your `permissions/*.yml` files.

## Cache Behavior

The role registry caches all active role names in memory. The cache is:

- **Populated** on the first authorization check after boot
- **Invalidated** automatically when any role record is created, updated, or destroyed (via `after_commit`)
- **Thread-safe** using `Monitor` synchronization
- **Resilient** — returns an empty array on database errors instead of crashing

### Manual Cache Control

```ruby
# Force cache refresh
LcpRuby::Roles::Registry.reload!

# Check current cache contents
LcpRuby::Roles::Registry.all_role_names
# => ["admin", "manager", "viewer"]

# Check a specific role
LcpRuby::Roles::Registry.valid_role?("admin")
# => true
```

## Boot-Time Validation

At application boot, the engine validates the role model contract:

| Check | Severity | Message |
|-------|----------|---------|
| Model exists | Error | `role_source is :model but model 'role' is not defined` |
| Name field exists | Error | `Role model 'role' must have a 'name' field` |
| Name field is string type | Error | `'name' field must be type 'string'` |
| Active field is boolean (if present) | Error | `'active' field must be type 'boolean'` |
| Name field has uniqueness validation | Warning | `'name' field should have a uniqueness validation` |

Errors prevent the application from starting. Warnings are logged but don't block startup.

You can also run these checks offline:

```bash
bundle exec rake lcp_ruby:validate
```

## Customizing the Generated Presenter

The generator creates a standard CRUD presenter at `config/lcp_ruby/presenters/roles.yml`. You can customize it like any other presenter — add columns, change layouts, add custom actions, etc.

Common customizations:

```yaml
# Add a "deactivate" custom action
actions:
  single:
    - { name: show, type: built_in, icon: eye }
    - { name: edit, type: built_in, icon: pencil }
    - name: deactivate
      type: custom
      icon: ban
      label: "Deactivate"
      confirm: true
      visible_when: { field: active, operator: eq, value: true }
```

## Programmatic Role Management

```ruby
role_model = LcpRuby.registry.model_for("role")

# Create a role
role_model.create!(
  name: "support_agent",
  label: "Support Agent",
  description: "Can view and update support tickets",
  active: true,
  position: 5
)
# Cache is automatically invalidated via after_commit

# Query roles
role_model.where(active: true).order(:position)

# Check registry
LcpRuby::Roles::Registry.valid_role?("support_agent")
# => true
```

## Testing

In integration tests, configure `role_source` after loading metadata (since `LcpRuby.reset!` clears the configuration):

```ruby
before(:each) do
  load_integration_metadata!("your_fixture")
  LcpRuby.configuration.role_source = :model
  LcpRuby::Roles::Registry.mark_available!
  LcpRuby::Roles::ChangeHandler.install!(
    LcpRuby.registry.model_for("role")
  )
end
```

For unit tests that need to mock the registry:

```ruby
before do
  LcpRuby.configuration.role_source = :model
  LcpRuby::Roles::Registry.mark_available!
  allow(LcpRuby::Roles::Registry).to receive(:valid_role?) do |name|
    %w[admin viewer].include?(name)
  end
end

after do
  LcpRuby.configuration.role_source = :implicit
  LcpRuby::Roles::Registry.clear!
end
```

## See Also

- [Role Source Reference](../reference/role-source.md) — complete attribute and API reference
- [Permissions Reference](../reference/permissions.md) — role-based CRUD, fields, scopes
- [Engine Configuration Reference](../reference/engine-configuration.md) — all `LcpRuby.configure` options
