# Role Source Reference

By default, roles in LCP Ruby are **implicit** — they exist only as string keys in permissions YAML files. There is no validation that a role name actually exists before it is used in authorization checks. The role source feature adds optional DB-backed role management: role definitions are stored in a database table, validated at boot, and cached at runtime.

## Configuration

Configure role source in `config/initializers/lcp_ruby.rb`:

```ruby
LcpRuby.configure do |config|
  config.role_source = :model
  config.role_model = "role"               # optional, default: "role"
  config.role_model_fields = {             # optional, default shown below
    name: "name",
    active: "active"
  }
end
```

### `role_source`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:implicit` |
| **Allowed values** | `:implicit`, `:model` |

Controls where role definitions come from.

| Value | Behavior |
|-------|----------|
| `:implicit` | Roles are string keys in permissions YAML. No validation against a role registry. This is the default and preserves backward compatibility. |
| `:model` | Roles are records in a DB-backed model. Role names are validated against the registry during authorization. Unknown roles are filtered out and logged as warnings. |

### `role_model`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"role"` |

Name of the LCP Ruby model that stores role definitions. The model must be defined in your `models/` YAML directory and must satisfy the [Model Contract](#model-contract).

### `role_model_fields`

| | |
|---|---|
| **Type** | `Hash` |
| **Default** | `{ name: "name", active: "active" }` |

Maps the contract's logical fields to actual field names on your model. Use this when your role model uses different column names.

```ruby
# Example: custom field names
config.role_model_fields = { name: "role_key", active: "enabled" }
```

| Key | Purpose | Default |
|-----|---------|---------|
| `name` | Field containing the role identifier string | `"name"` |
| `active` | Boolean field filtering active roles | `"active"` |

## Model Contract

When `role_source` is `:model`, the role model must satisfy these requirements:

### Required

| Requirement | Detail |
|-------------|--------|
| Name field exists | The field mapped as `name` must exist on the model |
| Name field type is `string` | Must be type `string` |

### Recommended

| Recommendation | Detail |
|----------------|--------|
| Uniqueness validation on name | Logged as a warning if missing |

### Optional

| Requirement | Detail |
|-------------|--------|
| Active field | If the field mapped as `active` exists, it must be type `boolean`. If the field does not exist, all roles are treated as active. |

Contract validation runs at boot time. Violations raise `LcpRuby::MetadataError` and prevent the application from starting.

## Registry

`LcpRuby::Roles::Registry` is a thread-safe singleton that caches active role names from the database.

### Methods

#### `Registry.all_role_names`

Returns a sorted `Array<String>` of active role names from the database. Results are cached until `reload!` is called.

```ruby
LcpRuby::Roles::Registry.all_role_names
# => ["admin", "manager", "viewer"]
```

#### `Registry.valid_role?(name)`

Returns `true` if the given name exists in the cached role list.

```ruby
LcpRuby::Roles::Registry.valid_role?("admin")   # => true
LcpRuby::Roles::Registry.valid_role?("ghost")    # => false
```

#### `Registry.reload!`

Clears the cache, forcing the next `all_role_names` call to re-query the database.

#### `Registry.available?`

Returns `true` after boot-time setup completes. When `false` (e.g., `role_source` is `:implicit`), the registry is not used and all methods return empty results.

### Error Handling

If a database error occurs during cache load (e.g., table doesn't exist yet, connection failure), the registry returns an empty array and logs a warning. This prevents boot failures in edge cases.

## Cache Invalidation

An `after_commit` callback is installed on the role model class. Whenever a role record is created, updated, or destroyed, the registry cache is automatically cleared. The next authorization check triggers a fresh database query.

## Effect on Authorization

When `role_source` is `:model` and the registry is available, the `PermissionEvaluator.resolve_roles` method adds an extra filtering step:

1. User's role names are read via `role_method` (e.g., `user.lcp_role`)
2. **New step:** Role names are filtered to only those present in `Registry.all_role_names`
3. Unknown role names are logged as warnings: `[LcpRuby::Roles] User #42 has unknown roles: ghost_role`
4. Remaining roles are matched against permission definition keys
5. If no roles match, the `default_role` from the permission definition is used

When `role_source` is `:implicit`, step 2 is skipped entirely and behavior is unchanged from the default.

## Boot Sequence

`Roles::Setup.apply!(loader)` runs during engine initialization, after models are built and custom fields are set up:

1. Returns immediately if `role_source != :model`
2. Verifies the role model exists in loaded model definitions (raises `MetadataError` if missing)
3. Runs `ContractValidator` against the model definition (raises `MetadataError` on failure)
4. Logs any contract warnings (e.g., missing uniqueness validation)
5. Marks the registry as available
6. Installs the `after_commit` change handler on the role model class

## Configuration Validation

The `ConfigurationValidator` (run via `rake lcp_ruby:validate`) performs these checks when `role_source` is `:model`:

- **Error:** Role model is not defined in `models/` YAML
- **Error:** Role model contract violations (missing name field, wrong types)
- **Warning:** Name field lacks uniqueness validation

## Generator

A Rails generator scaffolds the role model with recommended defaults:

```bash
rails generate lcp_ruby:role_model
```

This creates four YAML files and updates the initializer:

| File | Purpose |
|------|---------|
| `config/lcp_ruby/models/role.yml` | Role model with name, label, description, active, position fields |
| `config/lcp_ruby/presenters/roles.yml` | CRUD presenter with table, show, form, search, actions |
| `config/lcp_ruby/permissions/role.yml` | Admin (full CRUD) and viewer (read-only) |
| `config/lcp_ruby/views/roles.yml` | View group with navigation position 90 |

The generator also adds `config.role_source = :model` to `config/initializers/lcp_ruby.rb`.

### Generated Model Fields

| Field | Type | Validations | Purpose |
|-------|------|------------|---------|
| `name` | string | presence, uniqueness, format | Role identifier (e.g., `admin`, `sales_rep`) |
| `label` | string | — | Human-readable display name |
| `description` | text | — | Optional description |
| `active` | boolean | — | Whether role is active (default: `true`) |
| `position` | integer | — | Sort order (default: `0`) |

The `name` field has a format validation enforcing lowercase identifiers: `\A[a-z][a-z0-9_]*\z`.

## Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| `Roles::Registry` | `lib/lcp_ruby/roles/registry.rb` | Thread-safe cache of active role names |
| `Roles::ContractValidator` | `lib/lcp_ruby/roles/contract_validator.rb` | Boot-time model contract validation |
| `Roles::ChangeHandler` | `lib/lcp_ruby/roles/change_handler.rb` | `after_commit` → `Registry.reload!` |
| `Roles::Setup` | `lib/lcp_ruby/roles/setup.rb` | Boot orchestration |

### Data Flow

```
config/lcp_ruby/models/role.yml
  │
  ├── Engine boot
  │   ├── ModelFactory::Builder → LcpRuby::Dynamic::Role (AR class + DB table)
  │   └── Roles::Setup.apply!(loader)
  │       ├── ContractValidator.validate(model_def) → errors/warnings
  │       ├── Registry.mark_available!
  │       └── ChangeHandler.install!(model_class) → after_commit callback
  │
  ├── Runtime: PermissionEvaluator.resolve_roles(user)
  │   ├── user.lcp_role → ["admin", "ghost_role"]
  │   ├── Registry.valid_role?("admin") → true
  │   ├── Registry.valid_role?("ghost_role") → false, log warning
  │   └── result: ["admin"]
  │
  └── Runtime: Role CRUD
      └── after_commit → Registry.reload! → cache cleared
```

## See Also

- [Permissions Reference](permissions.md) — role-based CRUD, fields, scopes, record rules
- [Engine Configuration Reference](engine-configuration.md) — all `LcpRuby.configure` options
- [Role Source Guide](../guides/role-source.md) — step-by-step setup tutorial

Source: `lib/lcp_ruby/roles/registry.rb`, `lib/lcp_ruby/roles/contract_validator.rb`, `lib/lcp_ruby/roles/change_handler.rb`, `lib/lcp_ruby/roles/setup.rb`, `lib/lcp_ruby/configuration.rb`
