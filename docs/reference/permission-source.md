# Permission Source Reference

By default, permissions are defined in YAML files (`config/lcp_ruby/permissions/`). The **permission source** feature allows storing permission definitions in a database model instead, making them editable at runtime through the platform UI.

## Configuration

```ruby
LcpRuby.configure do |config|
  config.permission_source = :model            # :yaml (default) or :model
  config.permission_model = "permission_config" # model name (default)
  config.permission_model_fields = {            # field mapping (defaults shown)
    target_model: "target_model",
    definition: "definition",
    active: "active"
  }
end
```

### `permission_source`

| | |
|---|---|
| **Type** | Symbol |
| **Values** | `:yaml` (default), `:model` |

- `:yaml` — permissions loaded from YAML files only (default behavior, no change)
- `:model` — permissions resolved from DB first, with YAML as fallback

### `permission_model`

| | |
|---|---|
| **Type** | String |
| **Default** | `"permission_config"` |

Name of the LCP Ruby model that stores permission definitions. Must be defined in your models metadata.

### `permission_model_fields`

| | |
|---|---|
| **Type** | Hash |
| **Default** | `{ target_model: "target_model", definition: "definition", active: "active" }` |

Maps logical field roles to actual column names on your permission config model.

| Key | Purpose | Required Type |
|-----|---------|---------------|
| `target_model` | Which model this permission applies to | `string` |
| `definition` | JSON document with the permission definition | `json` |
| `active` | Whether this definition is active | `boolean` (optional) |

## Model Contract

The permission config model must satisfy these requirements (validated at boot):

| Field | Type | Required |
|-------|------|----------|
| `target_model` | `string` | Yes |
| `definition` | `json` | Yes |
| `active` | `boolean` | No (if absent, all records are treated as active) |

## JSON Definition Structure

The `definition` field holds a JSON document with the same structure as the `permissions` key in YAML, minus the `model` key (since that comes from `target_model`):

```json
{
  "roles": {
    "admin": {
      "crud": ["index", "show", "create", "update", "destroy"],
      "fields": { "readable": "all", "writable": "all" },
      "actions": "all",
      "scope": "all",
      "presenters": "all"
    },
    "viewer": {
      "crud": ["index", "show"],
      "fields": { "readable": "all", "writable": [] },
      "actions": { "allowed": [] },
      "scope": "all",
      "presenters": "all"
    }
  },
  "default_role": "viewer",
  "field_overrides": {
    "salary": { "readable_by": ["admin", "hr"], "writable_by": ["hr"] }
  },
  "record_rules": [
    {
      "name": "closed_not_editable",
      "condition": { "field": "status", "operator": "eq", "value": "closed" },
      "effect": { "deny_crud": ["update", "destroy"], "except_roles": ["admin"] }
    }
  ]
}
```

### Definition Validation

On model save, the `definition` field is validated:

- `roles` must be a Hash
- Each role's `crud` must be an Array of valid actions (`index`, `show`, `create`, `update`, `destroy`)
- `fields.readable` and `fields.writable` must be `"all"` or an Array
- `default_role` must be a String
- `field_overrides` must be a Hash
- `record_rules` must be an Array

Invalid definitions are rejected with validation errors on the `definition` field.

## Source Priority

In `:model` mode, permission definitions are resolved using first-found-wins (no merging):

```
1. DB record where target_model = "<model_name>"  → use if found
2. DB record where target_model = "_default"       → use if found
3. YAML file for <model_name>                      → fallback
```

If DB has a definition for "project", it is used entirely. The YAML "project" definition is ignored. DB and YAML are never combined for the same model.

In `:yaml` mode, only YAML files are consulted (step 3 only).

## Registry API

`LcpRuby::Permissions::Registry` provides a thread-safe, per-model cache:

| Method | Description |
|--------|-------------|
| `for_model(name)` | Returns cached `PermissionDefinition` or `nil` |
| `all_definitions` | Returns all active DB definitions (for impersonation role listing) |
| `reload!(name = nil)` | Clears one or all cache entries |
| `clear!` | Full reset (called from `LcpRuby.reset!`) |
| `available?` | Whether the registry is ready to query |
| `mark_available!` | Mark registry as available (called after boot) |

## Cache Invalidation

An `after_commit` callback on the permission config model automatically:

1. Clears the registry cache for the affected `target_model`
2. Clears the `PolicyFactory` cache (policies capture permission definitions in closures)

No manual cache management is needed. Changes take effect immediately after the DB transaction commits.

## Generator

Generate the permission config model, presenter, permissions, and view group:

```bash
rails generate lcp_ruby:permission_source          # DSL format (default)
rails generate lcp_ruby:permission_source --format=yaml  # YAML format
```

Generated files:
- `config/lcp_ruby/models/permission_config.{rb,yml}`
- `config/lcp_ruby/presenters/permission_configs.{rb,yml}`
- `config/lcp_ruby/permissions/permission_config.yml`
- `config/lcp_ruby/views/permission_configs.{rb,yml}`

The generator also injects `config.permission_source = :model` into your initializer.

## Architecture

```
Setup.apply!(loader)
  ├── ContractValidator.validate(model_def)  → fail-fast on contract errors
  ├── Registry.mark_available!               → enable DB lookups
  ├── ChangeHandler.install!(model_class)    → after_commit cache invalidation
  └── DefinitionValidator.install!(model_class) → validate JSON on save

SourceResolver.for(model_name, loader)
  ├── Registry.for_model(model_name)         → DB lookup (cached)
  ├── Registry.for_model("_default")         → DB _default fallback
  └── loader.yaml_permission_definition()    → YAML fallback
```

## See Also

- [Permissions Reference](permissions.md) — YAML permission format
- [Role Source Reference](role-source.md) — DB-backed role management (similar pattern)
- [Custom Fields Reference](custom-fields.md) — Per-field permissions with `custom_data`
