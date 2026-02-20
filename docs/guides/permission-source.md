# Permission Source Guide

This guide walks through setting up DB-backed permission management, where permission definitions are stored as JSON documents in a database model and can be edited at runtime.

## When to Use

- Runtime permission management without deploying code changes
- Per-deployment permission configuration
- Admin self-service permission editing via the platform UI
- Different environments need different permission sets

If your permissions are static and only change during development, YAML is simpler. Use DB-backed permissions when you need runtime editability.

## Quick Start

### Step 1: Generate permission config metadata

```bash
cd your-app
rails generate lcp_ruby:permission_source
```

This generates model, presenter, permissions, and view group files.

### Step 2: Add the configuration

If the generator didn't auto-inject it, add to your initializer:

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.permission_source = :model
end
```

### Step 3: Start the server and create a permission config

Navigate to `/permission-configs` and create a new record:

- **Target Model**: `project` (or whatever model you want to manage)
- **Definition**: paste a JSON permission definition
- **Active**: checked

### Step 4: Test it

The DB definition now takes precedence over any YAML `permissions/project.yml` file. Edit the JSON to change permissions in real-time.

## JSON Definition Format

The JSON definition uses the same structure as YAML permissions, without the `model` key:

```json
{
  "roles": {
    "admin": {
      "crud": ["index", "show", "create", "update", "destroy"],
      "fields": {
        "readable": "all",
        "writable": "all"
      },
      "actions": "all",
      "scope": "all",
      "presenters": "all"
    },
    "editor": {
      "crud": ["index", "show", "update"],
      "fields": {
        "readable": "all",
        "writable": ["title", "description", "status"]
      },
      "actions": {
        "allowed": ["approve"],
        "denied": ["delete_all"]
      },
      "scope": "all",
      "presenters": "all"
    },
    "viewer": {
      "crud": ["index", "show"],
      "fields": {
        "readable": ["title", "status", "created_at"],
        "writable": []
      },
      "actions": { "allowed": [] },
      "scope": "all",
      "presenters": "all"
    }
  },
  "default_role": "viewer",
  "field_overrides": {
    "salary": {
      "readable_by": ["admin", "hr"],
      "writable_by": ["hr"]
    }
  }
}
```

## Custom Field Names in Permissions

When a model has `custom_fields: true`, individual custom field names can appear in permission definitions:

```json
{
  "roles": {
    "admin": {
      "fields": { "readable": "all", "writable": "all" }
    },
    "editor": {
      "fields": {
        "readable": ["title", "status", "website", "phone"],
        "writable": ["title", "website"]
      }
    }
  }
}
```

In this example, `website` and `phone` are custom field names. The editor can read both but only write to `website`.

The aggregate `custom_data` key still works as a catch-all:
- `"readable": ["title", "custom_data"]` — title + ALL custom fields readable
- `"readable": ["title", "website"]` — title + only the "website" custom field

`field_overrides` also work for individual custom fields:

```json
{
  "field_overrides": {
    "internal_notes": {
      "readable_by": ["admin", "manager"],
      "writable_by": ["admin"]
    }
  }
}
```

## Mixing YAML and DB Permissions

In `:model` mode, the resolution order is:

1. DB record for the specific model
2. DB `_default` record
3. YAML file for the specific model

This is **not merging** — the first source that has a definition wins entirely. Keep YAML files as a safety net; they activate only when no DB record exists for that model.

**Example scenario:**
- DB has permission config for `project` and `_default`
- YAML has `project.yml`, `task.yml`, `_default.yml`
- `project` → uses DB (YAML project.yml ignored)
- `task` → uses DB `_default` (YAML task.yml ignored)
- If DB `_default` is deleted → `task` falls back to YAML task.yml

## Testing with DB Permissions

In integration tests, set up permission source after loading metadata:

```ruby
before(:each) do
  load_integration_metadata!("your_fixture")
  LcpRuby.configuration.permission_source = :model
  LcpRuby::Permissions::Registry.mark_available!
  LcpRuby::Permissions::ChangeHandler.install!(perm_model)
  LcpRuby::Permissions::DefinitionValidator.install!(perm_model)
end

let(:perm_model) { LcpRuby.registry.model_for("permission_config") }

it "uses DB permissions" do
  perm_model.create!(
    target_model: "task",
    definition: {
      "roles" => { "admin" => { "crud" => %w[index show] } },
      "default_role" => "admin"
    }
  )

  perm_def = LcpRuby.loader.permission_definition("task")
  expect(perm_def.roles).to have_key("admin")
end
```

## Troubleshooting

**"permission_source is :model but model 'permission_config' is not defined"**
Run the generator: `rails generate lcp_ruby:permission_source`

**Invalid JSON errors on save**
The definition field is validated on save. Check for:
- `roles` must be a Hash (not a string or array)
- `crud` values must be valid: `index`, `show`, `create`, `update`, `destroy`
- `fields.readable`/`writable` must be `"all"` or an Array

**Changes not taking effect**
Cache is cleared automatically via `after_commit`. If testing in a console, call `LcpRuby::Permissions::Registry.reload!` manually.

**PolicyFactory stale**
The `ChangeHandler` clears `PolicyFactory` on every DB change. If you modify the DB directly (bypassing ActiveRecord callbacks), call `LcpRuby::Authorization::PolicyFactory.clear!` manually.

## See Also

- [Permission Source Reference](../reference/permission-source.md) — Full configuration and API reference
- [Permissions Reference](../reference/permissions.md) — YAML permission format
- [Role Source Guide](role-source.md) — Similar pattern for DB-backed roles
