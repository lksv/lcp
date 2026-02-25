# Groups Reference

Groups map organizational units (departments, teams, project groups) to authorization roles. Users gain roles through group membership rather than (or in addition to) direct role assignment.

## Configuration

```ruby
LcpRuby.configure do |config|
  # Source: :none (default), :yaml, :model, :host
  config.group_source = :yaml

  # Method called on user to get group names (for :yaml source only;
  # ignored when group_source is :model — memberships are queried by user.id)
  config.group_method = :lcp_groups  # default

  # How direct roles and group-derived roles combine
  # :merged (default) — union of direct + group roles
  # :groups_only      — only group-derived roles
  # :direct_only      — only direct roles (groups ignored)
  config.role_resolution_strategy = :merged

  # DB-backed groups (:model source)
  config.group_model = "group"                          # default
  config.group_model_fields = { name: "name", active: "active" }
  config.group_membership_model = "group_membership"    # default
  config.group_membership_fields = { group: "group_id", user: "user_id" }
  config.group_role_mapping_model = "group_role_mapping" # nil by default (opt-in)
  config.group_role_mapping_fields = { group: "group_id", role: "role_name" }

  # Host adapter (:host source)
  config.group_adapter = MyLdapGroupAdapter.new
end
```

## Complexity Levels

| Level | `group_source` | Role mapping | Use case |
|-------|---------------|--------------|----------|
| 0 | `:none` | — | No groups needed |
| 1 | `:yaml` | Static in YAML | Small team with fixed groups |
| 2 | `:model` | Membership only (`group_role_mapping_model: nil`) | Runtime group management, roles assigned directly |
| 3 | `:model` | Full (with role mapping) | Groups map to roles dynamically |
| 4 | `:host` | Via adapter | AD/LDAP integration |

## Source: YAML

Define groups in `config/lcp_ruby/groups.yml`:

```yaml
groups:
  - name: sales_team
    label: "Sales Team"
    description: "Sales department staff"
    roles:
      - sales_rep
      - viewer

  - name: it_admins
    label: "IT Administrators"
    roles:
      - admin
```

The user model must respond to `group_method` (default: `lcp_groups`) returning an array of group name strings:

```ruby
class User < ApplicationRecord
  def lcp_groups
    %w[sales_team]  # from whatever source — DB column, LDAP, etc.
  end
end
```

## Source: Model (DB)

Run the generator to create the required models:

```bash
rails generate lcp_ruby:groups
```

This creates three models:
- **group** — name, label, description, external_id, source, active
- **group_membership** — group_id, user_id, source
- **group_role_mapping** — group_id, role_name

### Model Contracts

**Group model** requires:
- `name` field: type `string`, uniqueness validation recommended
- `active` field: type `boolean` (optional — all groups treated as active if missing)

**Membership model** requires:
- `group_id` field or belongs_to association with matching FK
- `user_id` field or belongs_to association with matching FK

**Role mapping model** requires:
- `group_id` field or belongs_to association with matching FK
- `role_name` field: type `string`

### Membership-Only Mode

Membership-only is the default configuration (`group_role_mapping_model` defaults to `nil`). In this mode, `roles_for_group` returns `[]` and groups serve only as organizational units. Users still get their roles through `role_method`. To enable role mapping, explicitly set `group_role_mapping_model`.

## Source: Host Adapter

For AD/LDAP or custom group providers:

```ruby
class LdapGroupAdapter
  def all_group_names
    # Query LDAP for all group CNs
  end

  def groups_for_user(user)
    # Query LDAP for user's group memberships
  end

  def roles_for_group(group_name)
    # Map LDAP group to application roles
  end

  # Optional: optimized single-query implementation
  def roles_for_user(user)
    # Single LDAP query for all roles
  end
end

LcpRuby.configure do |config|
  config.group_source = :host
  config.group_adapter = LdapGroupAdapter.new
end
```

The adapter must respond to `all_group_names`, `groups_for_user(user)`, and `roles_for_group(group_name)`. An optional `roles_for_user(user)` method provides an optimized path.

## Role Resolution Strategy

The `role_resolution_strategy` controls how direct roles (from `role_method`) combine with group-derived roles:

| Strategy | Direct roles | Group roles | Result |
|----------|-------------|-------------|--------|
| `:merged` | Yes | Yes | Union of both (default) |
| `:groups_only` | No | Yes | Only group-derived |
| `:direct_only` | Yes | No | Only direct |

When `group_source: :none`, the Groups::Registry is not available, so `resolve_group_roles` returns `[]`. With `:merged` strategy this means only direct roles are used — safe default.

## Cache Invalidation

- **YAML source**: Group definitions are loaded once at boot. Restart the server to pick up changes.
- **Model source**: `after_commit` callbacks on group, membership, and mapping models automatically call `Groups::Registry.reload!` and `Authorization::PolicyFactory.clear!`.
- **Host source**: No automatic caching. The adapter controls its own cache.

## Impersonation

When using role impersonation (`ImpersonatedUser`), group-derived roles are suppressed. The `group_method` returns `[]`, ensuring only the impersonated role is active.

## Registry API

```ruby
# Check if groups subsystem is configured
LcpRuby::Groups::Registry.available?  # => true/false

# All known group names (cached)
LcpRuby::Groups::Registry.all_group_names  # => ["admins", "editors"]

# Groups for a specific user (not cached)
LcpRuby::Groups::Registry.groups_for_user(user)  # => ["editors"]

# Roles mapped to a group
LcpRuby::Groups::Registry.roles_for_group("editors")  # => ["editor", "viewer"]

# All roles derived from user's groups
LcpRuby::Groups::Registry.roles_for_user(user)  # => ["editor", "viewer"]
```
