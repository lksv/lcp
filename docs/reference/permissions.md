# Permissions Reference

File: `config/lcp_ruby/permissions/<name>.yml`

Permission YAML defines role-based access control: who can perform which CRUD operations, which fields they can read and write, which custom actions they can execute, which records they can see, and which presenters they can access.

## Top-Level Attributes

```yaml
permissions:
  model: <model_name>
  roles: {}
  default_role: <role_name>
  field_overrides: {}
  record_rules: []
```

### `model`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Name of the [model](models.md) these permissions apply to. Use `_default` to define fallback permissions applied when no model-specific permission file exists.

```yaml
# Model-specific permissions
permissions:
  model: deal

# Default fallback permissions
permissions:
  model: _default
```

### `roles`

| | |
|---|---|
| **Required** | yes |
| **Type** | hash of role configs |

Each key is a role name (matched against the values returned by `user.<role_method>`). A user can have multiple roles — see [Multiple Roles](#multiple-roles). See [Role Configuration](#role-configuration) below.

> **DB-Backed Roles:** When `role_source` is set to `:model`, role names are validated against a database-backed registry before permission evaluation. Unknown roles are filtered out and logged. See [Role Source Reference](role-source.md) for setup details.

### `default_role`

| | |
|---|---|
| **Default** | `"viewer"` |
| **Type** | string |

The role assigned to users whose `role_method` does not match any key in `roles`, or when no user is present. This ensures every request has a defined permission set.

### `field_overrides`

| | |
|---|---|
| **Default** | `{}` |
| **Type** | hash |

Per-field access overrides that take precedence over the role's general `fields` setting. See [Field Overrides](#field-overrides).

### `record_rules`

| | |
|---|---|
| **Default** | `[]` |
| **Type** | array |

Rules that deny CRUD operations on records matching a condition, with optional role exceptions. See [Record Rules](#record-rules).

## Role Configuration

Each role is a hash with the following attributes:

```yaml
roles:
  admin:
    crud: [index, show, create, update, destroy]
    fields:
      readable: all
      writable: all
    actions: all
    scope: all
    presenters: all
```

### `crud`

| | |
|---|---|
| **Required** | yes |
| **Type** | array of strings |
| **Allowed values** | `index`, `show`, `create`, `update`, `destroy` |

CRUD operations this role can perform. The permission system automatically resolves action aliases:

| Alias | Resolves To |
|-------|-------------|
| `edit` | `update` |
| `new` | `create` |

You only need to list `create` and `update` — `new` and `edit` are inferred.

```yaml
# Full access
crud: [index, show, create, update, destroy]

# Read-only
crud: [index, show]

# Create and read, but no update or delete
crud: [index, show, create]
```

### `fields`

| | |
|---|---|
| **Required** | no |
| **Type** | hash with `readable` and `writable` keys |

Controls field-level access.

```yaml
fields:
  readable: all          # Can read all fields
  writable: all          # Can write all fields

fields:
  readable: [title, stage, value]   # Can only read these fields
  writable: [title, stage]          # Can only write these fields

fields:
  readable: all
  writable: []           # Read-only: can read everything, write nothing
```

- `"all"` — grants access to every field defined in the model (including `custom_data` if the model has `custom_fields: true`)
- Array of field names — grants access to only those fields
- `[]` (empty array) — no access

> **Custom Fields:** For models with `custom_fields: true`, the virtual field name `custom_data` controls access to all custom fields. Include `custom_data` in the `readable`/`writable` list to grant access, or use `all` which includes it automatically. See [Custom Fields Reference](custom-fields.md#permissions) for details.

> **Positioning:** For models with [`positioning`](models.md#positioning), the position field (e.g., `position`) must be included in the `writable` list for the user to reorder records via drag-and-drop. Reordering requires **both** `update` in `crud` **and** the position field in `writable`. This allows roles that can edit record data but cannot change ordering:
>
> ```yaml
> roles:
>   manager:
>     crud: [index, show, create, update, destroy]
>     fields:
>       writable: [name, description, position]    # can reorder
>   editor:
>     crud: [index, show, update]
>     fields:
>       writable: [name, description]              # can edit but NOT reorder
>   viewer:
>     crud: [index, show]
>     fields:
>       readable: all                              # no drag handles (no update permission)
> ```

### `actions`

| | |
|---|---|
| **Required** | no |
| **Type** | string or hash |

Controls which custom actions the role can execute.

```yaml
# Can execute all custom actions
actions: all

# Granular control
actions:
  allowed: [close_won, reopen]
  denied: [force_delete]

# Allow all except specific ones
actions:
  allowed: all
  denied: [force_delete]

# No custom actions
actions:
  allowed: []
```

The `denied` list takes precedence: if an action appears in both `allowed` and `denied`, it is denied.

### `scope`

| | |
|---|---|
| **Required** | no |
| **Default** | all records visible |
| **Type** | string or hash |

Controls which records the role can see (row-level security). Set to `"all"` for unrestricted access, or use one of four scope types.

#### Scope Type: `field_match`

Filters records where a field matches a value derived from the current user.

```yaml
scope:
  type: field_match
  field: owner_id
  value: current_user_id
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Column name to filter on |
| `value` | string | Value reference (see below) |

**Value references:**
- `current_user_id` — resolves to `user.id`
- `current_user_<method>` — resolves to `user.<method>` (e.g., `current_user_department_id` calls `user.department_id`)
- Any other string — used as a literal value

#### Scope Type: `association`

Filters records where a field's value is in a collection returned by a user method.

```yaml
scope:
  type: association
  field: department_id
  method: department_ids
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Column name to filter on |
| `method` | string | Method on the user object that returns an array of allowed values |

Use this when users belong to multiple groups (e.g., departments, teams) and should see records from any of their groups.

#### Scope Type: `where`

Applies a static `WHERE` clause.

```yaml
scope:
  type: where
  conditions: { active: true }
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `conditions` | hash | Hash of column/value pairs passed to `ActiveRecord::Base.where` |

Use this for role-based static filtering (e.g., viewers can only see active records).

#### Scope Type: `custom`

Delegates to a named scope method on the model, passing the current user as an argument.

```yaml
scope:
  type: custom
  method: visible_to_user
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `method` | string | Scope method name on the model class |

The model must define this scope accepting a user parameter:

```ruby
scope :visible_to_user, ->(user) { where(region: user.region) }
```

Use this for complex filtering logic that cannot be expressed with the other scope types.

### `presenters`

| | |
|---|---|
| **Required** | no |
| **Type** | string or array |

Controls which presenters the role can access.

```yaml
# Can access all presenters for this model
presenters: all

# Can only access specific presenters
presenters: [deal, deal_pipeline]
```

## Field Overrides

Override field-level access per role, independent of the role's general `fields` setting. These take precedence over the `readable`/`writable` lists in the role config.

```yaml
field_overrides:
  value:
    readable_by: [admin, sales_rep]
    writable_by: [admin]
  ssn:
    readable_by: [admin]
    masked_for: [sales_rep, viewer]
```

### Override Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `readable_by` | array of role names | Only these roles can read this field |
| `writable_by` | array of role names | Only these roles can write this field |
| `masked_for` | array of role names | These roles see a masked value instead of the actual data |

**How it works:**
- If `readable_by` is set on a field, the role must be in that list to read it — even if the role's `fields.readable` is set to `all`.
- If `writable_by` is set, the role must be in that list to write it.
- `masked_for` is a display-level flag. The `PermissionEvaluator.field_masked?` method returns `true` for roles in the list, and the UI layer can choose how to mask (e.g., show "***").

## Record Rules

Rules that conditionally deny CRUD operations based on record field values.

```yaml
record_rules:
  - name: closed_deals_readonly
    condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

### Record Rule Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | Human-readable rule identifier |
| `condition` | object | [Condition](condition-operators.md) evaluated against each record |
| `effect` | object | What happens when the condition matches |

### Effect Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `deny_crud` | array | CRUD operations to deny (e.g., `[update, destroy]`) |
| `except_roles` | array | Roles exempt from the denial |

**Evaluation order:**
1. The role's `crud` list is checked first (`can?`)
2. Then each record rule's condition is evaluated against the specific record (`can_for_record?`) using [all 12 condition operators](condition-operators.md)
3. If the condition matches and the action is in `deny_crud` and the role is not in `except_roles`, the action is denied

Action aliases are resolved before checking `deny_crud`: `edit` maps to `update` and `new` maps to `create`. A rule with `deny_crud: [update]` also denies `edit`.

This enables patterns like "closed deals are read-only for everyone except admins."

**Action button visibility:** Record rules automatically hide action buttons on index pages. When `can_for_record?` denies `update` or `destroy` for a record, the corresponding `edit`/`destroy` buttons are hidden for that row — no need to duplicate the condition in the presenter's `visible_when`. The `show` action is not affected by record rules (if a record is visible in the list, its show link remains clickable).

Both record rules and `visible_when` apply simultaneously (AND semantics). Use `visible_when` for additional UI-only conditions beyond what record rules cover.

## Complete Example

```yaml
permissions:
  model: deal

  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all
      presenters: all

    sales_rep:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [title, stage, company_id, contact_id]
      actions:
        allowed: [close_won]
        denied: []
      scope: all
      presenters: [deal]

    viewer:
      crud: [index, show]
      fields: { readable: [title, stage, value], writable: [] }
      actions: { allowed: [] }
      scope: all
      presenters: [deal_pipeline]

  default_role: viewer

  field_overrides:
    value:
      writable_by: [admin]
      readable_by: [admin, sales_rep]

  record_rules:
    - name: closed_deals_readonly
      condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
      effect:
        deny_crud: [update, destroy]
        except_roles: [admin]
```

## Multiple Roles

Users can have multiple roles simultaneously. The `role_method` (default: `lcp_role`) must return an **array of role name strings** (e.g., `["admin", "sales_rep"]`).

When a user has multiple roles, permissions are merged using **union (most-permissive) semantics**:

| Aspect | Merge Rule |
|--------|------------|
| `crud` | Union of all roles' CRUD lists |
| `fields.readable` | Union — if any role has `"all"`, result is `"all"` |
| `fields.writable` | Union — if any role has `"all"`, result is `"all"` |
| `actions.allowed` | Union — if any role has `"all"`, result is `"all"` |
| `actions.denied` | Intersection — denied only if denied by all roles |
| `scope` | If any role has `"all"`, result is `"all"`; otherwise uses the first role's scope (see note below) |
| `presenters` | Union — if any role has `"all"`, result is `"all"` |

**Scope merge note:** When multiple roles define different non-"all" scopes (e.g., one role uses `field_match` and another uses `where`), only the first role's scope is used and the others are silently discarded. A warning is logged at `Rails.logger.warn` level to help identify this situation. If you need users with multiple roles to have a combined scope, use a `custom` scope type that handles the logic explicitly.

**Field overrides** with multiple roles:
- `readable_by` / `writable_by` — access granted if the user has **any** matching role
- `masked_for` — masked only if **all** of the user's roles are in the `masked_for` list

**Record rules** with multiple roles:
- `except_roles` — the user is exempt if **any** of their roles is in the exception list

```ruby
# User model example
class User < ApplicationRecord
  def lcp_role
    roles.pluck(:name)  # => ["admin", "sales_rep"]
  end
end
```

## Menu Filtering

The navigation menu automatically filters out presenters the current user cannot access. If a role's `presenters` list does not include a given presenter, that presenter's menu item is hidden. This uses the same `can_access_presenter?` check as the controller-level authorization.

## Audit Logging

Every authorization denial is logged with details including the user ID, roles, action, resource, and IP address:

```
[LcpRuby::Auth] Access denied: user=42 roles=viewer action=update resource=deal detail=not authorized
```

Additionally, an `ActiveSupport::Notifications` event is published for each denial:

```ruby
ActiveSupport::Notifications.subscribe("authorization.lcp_ruby") do |name, start, finish, id, payload|
  # payload contains: user_id, roles, action, resource, detail, ip
  AuditLog.create!(
    user_id: payload[:user_id],
    action: "access_denied",
    details: payload.except(:ip)
  )
end
```

This allows host applications to implement custom audit logging, alerting, or metrics collection.

## Custom Field Permissions

When a model has `custom_fields: true`, individual custom field names can be used in `fields.readable`, `fields.writable`, and `field_overrides`.

The aggregate `custom_data` key still works as a catch-all for all custom fields. Individual field names provide per-field granularity:

```yaml
permissions:
  model: project
  roles:
    admin:
      fields:
        readable: all           # all fields including all custom fields
        writable: all
    editor:
      fields:
        readable: [name, website, phone]  # specific custom fields
        writable: [name, website]          # only website writable
    support:
      fields:
        readable: [name, custom_data]      # name + ALL custom fields
        writable: []
  field_overrides:
    internal_notes:                         # per-custom-field override
      readable_by: [admin, manager]
      writable_by: [admin]
```

See [Custom Fields Reference](custom-fields.md#permissions) for details.

## DB-Backed Permissions

Permissions can be stored in a database model instead of YAML files, enabling runtime editing. See [Permission Source Reference](permission-source.md) for setup and configuration.

Source: `lib/lcp_ruby/metadata/permission_definition.rb`, `lib/lcp_ruby/authorization/permission_evaluator.rb`, `lib/lcp_ruby/authorization/scope_builder.rb`
