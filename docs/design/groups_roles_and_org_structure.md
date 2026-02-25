# Groups, Roles & Organizational Structure — Design Document

## Overview

This document describes how LCP Ruby should represent **organizational structure**,
**group definitions** (e.g., synchronized from AD/LDAP), and their **relationship
to role-based authorization**. The focus is on patterns common in enterprise
environments where identity comes from external directories and authorization
must integrate with corporate IAM.

### Design Principles

1. **Three configuration sources** — every concept (groups, group-role mapping,
   org units) must be definable via static files (YAML/DSL), DB records, or
   host application contract API.
2. **Separation of identity and authorization** — groups represent *membership*
   (who belongs where), roles represent *capabilities* (what users can do).
   The mapping between them is explicit and configurable.
3. **Reuse existing building blocks** — PermissionEvaluator, ScopeBuilder,
   Roles::Registry, Events::Dispatcher, ConditionEvaluator.
4. **External-sync friendly** — design for LDAP/AD/SCIM sync from day one,
   even if not implemented immediately. The data model and contracts must not
   assume local-only management.
5. **Organizational units are user-defined models** — the platform does not
   impose a fixed org hierarchy. OUs are regular LCP models; the platform
   provides scope integration patterns.

### Scope

| In scope | Out of scope (for now) |
|---|---|
| Group model + membership | LDAP/SCIM sync adapter implementation |
| Group → Role mapping | Nested group resolution (flatten at sync) |
| Effective role resolution (direct + group-derived) | Group-based UI personalization |
| Three configuration sources for all concepts | Group lifecycle workflows |
| Org unit scope integration patterns | Multi-tenant org isolation |
| Host application contract API | Visual org chart editor |
| Management UI (generated presenters) | |

---

## 1. Terminology

In enterprise IAM, three concepts are frequently conflated but serve distinct
purposes:

| Concept | What it represents | Examples | Lifecycle |
|---|---|---|---|
| **Organizational Unit (OU)** | Where a user sits in the hierarchy | Division, Department, Team, Location | Managed by HR / org admin |
| **Group** | A named set of users | `GRP_Finance_Prague`, `GRP_All_Managers` | Managed by IT / synced from AD |
| **Role** | A permission profile — what a user can *do* | `admin`, `editor`, `viewer` | Managed by app admin |

### How They Relate

```
Identity Source             Authorization Layer          Data Access
(AD/LDAP/Local)             (LCP Ruby)                   (LCP Ruby)
──────────────────          ─────────────────────        ──────────────
User ── member_of ──→ Group ── maps_to ──→ Role ──→ CRUD + field access
User ── belongs_to ──→ OU ────────────────────────→ Scope (record filtering)
User ──────────── direct_role ──→ Role ──→ override / exception
```

A group defines *who* gets a role. An OU defines *which records* a role applies
to. A direct role assignment handles exceptions without touching the group system.

### Enterprise Flow Example

```
AD Group                   →  maps to  →  Role(s) + Scope
─────────────────────────────────────────────────────────
GRP_Sales_Managers         →  role: manager,  scope: sales department
GRP_HR_Staff               →  role: editor,   scope: HR department
GRP_IT_Admins              →  role: admin,     scope: all
GRP_All_Employees          →  role: viewer,    scope: own department
```

---

## 2. Common Enterprise Models

### Model A: Group → Role Mapping (most common)

```
User ── belongs_to ──→ OrgUnit (department / team)
User ── has_many ────→ GroupMemberships ──→ Groups
Group ── has_many ───→ GroupRoleMappings ──→ Roles
```

AD groups are synced into the system. Each group maps to one or more roles.
The user's effective permissions = union of roles from all their groups.
Local role assignments are not used.

### Model B: Group = Role (simple)

AD groups directly serve as role names: `GRP_Sales_Admin` → role `sales_admin`.
Simple but inflexible — every permission change requires an AD modification
(which typically involves IT/ops and change management approval).

### Model C: Hybrid (pragmatic enterprise, recommended)

```
User ── belongs_to ──→ OrgUnit          (synced from AD OU tree)
User ── has_many ────→ Groups            (synced from AD)
Group ── maps_to ───→ Role(s)            ← local mapping table
User ── has_many ───→ RoleAssignments    ← local override/addition
```

Groups provide the baseline authorization. Local role assignments allow
exceptions without touching AD. This is what most enterprise IS implementations
end up with, because:

- Group sync covers 90% of users automatically
- Direct assignments handle the remaining 10% (contractors, temporary access,
  cross-department projects)
- App admins can grant access without waiting for AD ticket resolution

---

## 3. Design for LCP Ruby

### 3.1 Configuration Source Pattern

Following the platform's configuration source principle, each concept supports
three sources. All sources produce the same internal representation — the
source is just a loader.

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  YAML / DSL  │    │   DB Model   │    │  Host API    │
│  (static)    │    │  (dynamic)   │    │  (contract)  │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       ▼                   ▼                   ▼
   ┌─────────────────────────────────────────────┐
   │         Unified Internal Representation     │
   │   (GroupDefinition, MembershipSet, etc.)    │
   └─────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────┐
   │         Effective Role Resolver             │
   │   direct_roles ∪ group_derived_roles        │
   └─────────────────────────────────────────────┘
                          │
                          ▼
   ┌─────────────────────────────────────────────┐
   │         PermissionEvaluator (existing)      │
   └─────────────────────────────────────────────┘
```

### 3.2 Groups

#### 3.2.1 YAML / DSL Source

For small deployments or testing — groups and mappings are defined in static
files.

**YAML format:**

```yaml
# config/lcp_ruby/groups.yml
groups:
  - name: sales_team
    label: "Sales Team"
    description: "All sales department staff"
    roles: [sales_rep, viewer]

  - name: sales_managers
    label: "Sales Managers"
    description: "Sales department managers"
    roles: [sales_rep, manager]

  - name: it_admins
    label: "IT Administrators"
    roles: [admin]

  - name: all_employees
    label: "All Employees"
    roles: [viewer]
```

**DSL format:**

```ruby
# config/initializers/lcp_ruby.rb  or  config/lcp_ruby/groups.rb
LcpRuby.define_groups do
  group :sales_team do
    label "Sales Team"
    roles [:sales_rep, :viewer]
  end

  group :sales_managers do
    label "Sales Managers"
    roles [:sales_rep, :manager]
  end

  group :it_admins do
    label "IT Administrators"
    roles [:admin]
  end
end
```

When using YAML/DSL, group membership is managed through the host application's
user model (see 3.2.3 Host API) or through a DB membership table with static
group definitions.

#### 3.2.2 DB Model Source

For runtime-managed groups with a management UI. Follows the same pattern as
`role_source: :model`.

**Configuration:**

```ruby
LcpRuby.configure do |config|
  config.group_source = :model

  config.group_model = "group"
  config.group_model_fields = {
    name: "name",         # required, string, unique identifier
    label: "label",       # optional, string, display name
    active: "active"      # optional, boolean, filter inactive groups
  }

  config.group_membership_model = "group_membership"
  config.group_membership_fields = {
    group: "group_id",    # FK to group model
    user: "user_id"       # FK to host user model
  }

  # Optional — omit for membership-only groups (no role derivation from groups).
  # When nil, groups serve as organizational memberships only (for scoping,
  # filtering, notifications) without affecting role resolution.
  config.group_role_mapping_model = "group_role_mapping"
  config.group_role_mapping_fields = {
    group: "group_id",    # FK to group model
    role: "role_name"     # role name string (matches permission YAML keys)
  }
end
```

**Model definitions (YAML):**

```yaml
# config/lcp_ruby/models/group.yml
model:
  name: group
  fields:
    - name: name
      type: string
      required: true
      unique: true
    - name: label
      type: string
    - name: description
      type: text
    - name: external_id
      type: string
      unique: true
      description: "External identifier (e.g. AD objectGUID) for sync"
    - name: source
      type: enum
      values: { local: "Local", external: "External (synced)" }
      default: local
    - name: active
      type: boolean
      default: true
```

```yaml
# config/lcp_ruby/models/group_membership.yml
model:
  name: group_membership
  fields:
    - name: user_id
      type: integer
      required: true
    - name: source
      type: enum
      values: { local: "Local", external: "External (synced from directory)" }
      default: local
  associations:
    - name: group
      type: belongs_to
      target_model: group
  validations:
    - type: uniqueness
      fields: [group_id, user_id]
```

```yaml
# config/lcp_ruby/models/group_role_mapping.yml
model:
  name: group_role_mapping
  fields:
    - name: role_name
      type: string
      required: true
  associations:
    - name: group
      type: belongs_to
      target_model: group
  validations:
    - type: uniqueness
      fields: [group_id, role_name]
```

**Contract for DB models:**

| Model | Required fields | Validations | Required? |
|---|---|---|---|
| Group | `name` (string, unique) | `active` (boolean) if present | Yes |
| GroupMembership | `group_id` (integer), `user_id` (integer) | uniqueness on [group_id, user_id] | Yes |
| GroupRoleMapping | `group_id` (integer), `role_name` (string) | uniqueness on [group_id, role_name] | No — omit for membership-only groups |

#### 3.2.3 Host Application Contract API

The host application provides its own group/membership/role-mapping
implementation. The platform consumes it through adapter interfaces.

**Contract interfaces:**

```ruby
# The host app registers an adapter that implements this contract.
# LcpRuby calls these methods — it never touches group tables directly.

module LcpRuby
  module Groups
    module Contract
      # Returns all active group names.
      # @return [Array<String>]
      def all_group_names
        raise NotImplementedError
      end

      # Returns group names for a given user.
      # @param user [Object] the current user object
      # @return [Array<String>]
      def groups_for_user(user)
        raise NotImplementedError
      end

      # Returns role names mapped to a given group.
      # @param group_name [String]
      # @return [Array<String>]
      def roles_for_group(group_name)
        raise NotImplementedError
      end

      # Returns all role names derived from a user's group memberships.
      # Default implementation composes groups_for_user + roles_for_group.
      # Host app can override for performance (single query).
      # @param user [Object]
      # @return [Array<String>]
      def roles_for_user(user)
        groups_for_user(user).flat_map { |g| roles_for_group(g) }.uniq
      end
    end
  end
end
```

**Registration in host app:**

```ruby
# app/lcp_services/my_group_adapter.rb
class MyGroupAdapter
  include LcpRuby::Groups::Contract

  def all_group_names
    # Could query AD via LDAP, hit a SCIM endpoint, or read from cache
    CompanyDirectory.active_groups.pluck(:name)
  end

  def groups_for_user(user)
    user.directory_groups.pluck(:name)
  end

  def roles_for_group(group_name)
    GroupRoleMappingTable.where(group: group_name).pluck(:role)
  end

  # Optional performance override — single query instead of N+1
  def roles_for_user(user)
    GroupRoleMappingTable
      .joins(:group)
      .where(groups: { name: user.directory_groups.select(:name) })
      .pluck(:role)
      .uniq
  end
end

# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.group_source = :host
  config.group_adapter = MyGroupAdapter.new
end
```

**When to use each source:**

| Source | Use case |
|---|---|
| YAML/DSL | Small deployment, static teams, testing, development |
| DB Model | Self-service group management, admin UI, moderate scale |
| Host API | AD/LDAP integration, SCIM sync, existing identity system, large enterprise |

### 3.3 Effective Role Resolution

The core change: `PermissionEvaluator.resolve_roles` must compose roles from
multiple sources.

**Resolution order:**

```
1. Direct roles        ← user.lcp_role (existing mechanism)
2. Group-derived roles ← user's groups → group-role mappings → role names
3. Union               ← effective_roles = direct ∪ group_derived
4. Validation          ← filter against Roles::Registry (if role_source == :model)
5. Fallback            ← if empty, use default_role
```

**Configuration:**

```ruby
LcpRuby.configure do |config|
  # How to combine direct roles and group-derived roles
  config.role_resolution_strategy = :merged  # default

  # Options:
  #   :merged        — direct_roles ∪ group_derived_roles (recommended)
  #   :groups_only   — only group-derived roles as the source (ignores direct assignments)
  #   :direct_only   — only direct roles, ignore groups (current behavior)
  #
  # Note: all strategies share the same fallback — if no matching roles are found
  # after filtering, the user gets default_role (typically "viewer"). This is
  # intentionally fail-open. For true fail-closed behavior, set default_role to
  # a role with crud: [] (no permissions).
end
```

**Updated resolve_roles pseudocode:**

```ruby
def resolve_roles(user)
  return [permission_definition.default_role] unless user

  strategy = LcpRuby.configuration.role_resolution_strategy

  direct = resolve_direct_roles(user)      # existing: user.lcp_role
  group_derived = resolve_group_roles(user) # new: groups → mappings → roles

  combined = case strategy
             when :merged      then (direct + group_derived).uniq
             when :groups_only then group_derived
             when :direct_only then direct
             end

  # existing: validate against DB registry if role_source == :model
  combined = validate_against_registry(combined)

  # existing: filter to roles with permission configs, fallback to default.
  # This fallback applies to ALL strategies — including :groups_only.
  # If this fail-open behavior is undesirable, configure default_role
  # with crud: [] to deny all access.
  matching = combined.select { |r| permission_definition.roles.key?(r) }
  matching.empty? ? [permission_definition.default_role] : matching
end
```

### 3.4 Direct Role Assignments

For the hybrid model (Model C), users can have direct role assignments
independent of groups. This is the existing `role_method` mechanism.

When `group_source` is active, the platform also supports a dedicated
direct-assignment model for cases where the host user model shouldn't be
modified:

```ruby
LcpRuby.configure do |config|
  config.direct_role_assignment_model = "user_role_assignment"  # optional
  config.direct_role_assignment_fields = {
    user: "user_id",
    role: "role_name"
  }
end
```

```yaml
# config/lcp_ruby/models/user_role_assignment.yml
model:
  name: user_role_assignment
  fields:
    - name: user_id
      type: integer
      required: true
    - name: role_name
      type: string
      required: true
    - name: reason
      type: string
      description: "Why this direct assignment was granted"
    - name: granted_by
      type: string
    - name: expires_at
      type: datetime
      description: "Temporary access expiration"
  validations:
    - type: uniqueness
      fields: [user_id, role_name]
```

When `direct_role_assignment_model` is configured, `resolve_direct_roles`
behaviour depends on a separate config option (to be defined at implementation
time):

- **`:replace`** — queries only the assignment table, ignoring `user.lcp_role`.
  Use when the host user model should not carry role data at all.
- **`:merge`** — unions roles from both the assignment table and
  `user.lcp_role`. Use when the assignment table supplements roles already
  present on the user model (e.g., temporary overrides alongside HR-managed
  base roles).

The default will be `:replace` to avoid ambiguity — one canonical source of
direct roles. This config will be finalised when the feature is implemented.

### 3.5 Organizational Units

OUs remain **user-defined models** — the platform does not provide a built-in
OU model because organizational hierarchies vary too much across enterprises.
However, the platform provides integration patterns:

**Typical OU model:**

```yaml
# config/lcp_ruby/models/department.yml
model:
  name: department
  fields:
    - name: name
      type: string
      required: true
    - name: code
      type: string
      unique: true
    - name: level
      type: integer
      description: "Hierarchy depth (0 = root)"
    - name: external_id
      type: string
      description: "AD OU distinguishedName for sync"
  associations:
    - name: parent
      type: belongs_to
      target_model: department
      optional: true
    - name: children
      type: has_many
      target_model: department
      foreign_key: parent_id
```

**OU-based scoping in permissions (existing mechanism, no changes needed):**

```yaml
# Scope by user's department
scope:
  type: field_match
  field: department_id
  value: current_user_department_id

# Scope by user's department tree (multiple departments)
scope:
  type: association
  field: department_id
  method: accessible_department_ids    # user method returns [1, 3, 5, 12]

# Complex hierarchical scope
scope:
  type: custom
  method: visible_in_org_tree          # model scope, full flexibility
```

The `accessible_department_ids` method on the user model handles hierarchy
traversal (self + descendants). This is intentionally left to the host app
because traversal strategy (recursive CTE, materialized path, nested set)
depends on the database and scale.

---

## 4. Module Structure

```
lib/lcp_ruby/groups/
  ├── contract.rb              # Host API interface definition
  ├── registry.rb              # Thread-safe cache of groups + mappings
  ├── contract_validator.rb    # Boot-time model contract validation
  ├── change_handler.rb        # after_commit cache invalidation
  ├── setup.rb                 # Boot orchestration (like Roles::Setup)
  ├── yaml_loader.rb           # Loads groups from YAML/DSL
  ├── model_loader.rb          # Loads groups from DB models
  └── host_loader.rb           # Delegates to host adapter
```

**Setup boot sequence (called after Roles::Setup):**

```
Groups::Setup.apply!(loader)
  ├── if group_source == :yaml   → YamlLoader.load(loader)
  ├── if group_source == :model  → ContractValidator.validate(...)
  │                                 Registry.mark_available!
  │                                 ChangeHandler.install!(group_model, membership_model, mapping_model)
  └── if group_source == :host   → validate adapter responds to Contract methods
                                    Registry.mark_available!
```

**Registry responsibilities:**

| Method | Purpose |
|---|---|
| `all_group_names` | Active group names (cached) |
| `groups_for_user(user)` | User's group memberships |
| `roles_for_user(user)` | Effective roles from groups |
| `reload!` | Clear cache (on DB change or sync event) |
| `available?` | Whether group resolution is active |

The Registry delegates to the appropriate loader based on `group_source`.

---

## 5. Configuration Summary

```ruby
LcpRuby.configure do |config|
  # === Existing role config (unchanged) ===
  config.role_method = :lcp_role
  config.role_source = :model                  # :implicit | :model
  config.role_model = "role"

  # === New: Group config ===
  config.group_source = :none                  # :none | :yaml | :model | :host
                                               # :none preserves current behavior — no groups

  # When group_source == :model
  config.group_model = "group"
  config.group_model_fields = { name: "name", active: "active" }
  config.group_membership_model = "group_membership"
  config.group_membership_fields = { group: "group_id", user: "user_id" }
  config.group_role_mapping_model = "group_role_mapping"  # optional — nil for membership-only groups
  config.group_role_mapping_fields = { group: "group_id", role: "role_name" }

  # When group_source == :host
  config.group_adapter = MyGroupAdapter.new    # must implement Groups::Contract

  # === New: Role resolution strategy ===
  config.role_resolution_strategy = :merged    # :merged | :groups_only | :direct_only

  # === New: Optional direct role assignment model ===
  config.direct_role_assignment_model = nil    # model name or nil
  config.direct_role_assignment_fields = { user: "user_id", role: "role_name" }
end
```

---

## 6. Complexity Levels

The design supports progressive complexity — from zero configuration (current
behavior) to full enterprise integration. Each level builds on the previous one
without requiring changes to permission YAML, scope definitions, or other
existing platform concepts.

| Level | Configuration | What changes | Use case |
|---|---|---|---|
| **0 — No groups** | `group_source: :none` (default) | Nothing. Current behavior preserved. | Simple apps, prototypes |
| **1 — Static groups** | `group_source: :yaml` | Groups + role mappings defined in YAML. No DB tables. | Small deployments, testing |
| **2 — Membership-only groups** | `group_source: :model`, no `group_role_mapping_model` | Groups + memberships in DB. No role derivation — groups used for organizational filtering/scoping only. | Organizational structure, record filtering |
| **3 — Full DB groups** | `group_source: :model` with all 3 models | Groups, memberships, and role mappings in DB with management UI. | Self-service group administration |
| **4 — Enterprise integration** | `group_source: :host` | Host adapter provides groups from AD/LDAP/SCIM. | Corporate IAM integration |

### Key Properties Across All Levels

- **Permission YAML is unchanged at all levels.** Groups are transparent to
  the permission layer. A configurator working with permissions never needs to
  know whether groups exist.
- **OU models are independent of group source.** Organizational units are
  regular user-defined models at every level — they do not require groups.
- **Role resolution strategy is orthogonal.** `role_resolution_strategy` can be
  set independently of `group_source` — even at level 3, setting
  `:direct_only` disables group-derived roles while keeping groups for
  organizational purposes.

### Level 2: Membership-Only Groups

When `group_source == :model` and `group_role_mapping_model` is not configured
(`nil`), groups exist as organizational memberships without affecting role
resolution. This is useful when:

- Groups represent teams, projects, or organizational units for record filtering
- Scope rules reference group membership (e.g., `accessible_group_ids` method
  on the user model)
- The host app uses groups for non-authorization purposes (notifications,
  assignment queues, dashboards)

In this mode, `resolve_group_roles` always returns an empty array (because
there is no role mapping model to query), so effective roles come solely from
direct assignments regardless of `role_resolution_strategy`. This is not
because the strategy is forced to `:direct_only` — the strategy setting is
still orthogonal — but because group-derived roles are structurally empty
without a mapping table. Groups still fire membership events and support
custom fields if they are LCP models. Upgrading from level 2 to level 3
requires only adding the `group_role_mapping` model and configuring it — no
changes to existing groups or memberships.

---

## 7. Interaction with Existing Systems

### 7.1 Permission Evaluation (no changes to permission YAML)

Permission YAML stays the same. Role names in permission files are matched
against effective roles regardless of how they were resolved (direct, group,
or both). This is the key benefit — groups are transparent to the
permission layer.

### 7.2 Scope Resolution (no changes)

ScopeBuilder already supports `field_match`, `association`, `where`, and
`custom`. OU-based scoping uses these existing mechanisms. No changes needed.

### 7.3 Impersonation

The existing impersonation system (`ImpersonatedUser`) overrides roles.
With groups, impersonation should override the *effective* roles (after
group resolution), not the group memberships. The current design already
works because impersonation replaces the role list that feeds into
`PermissionEvaluator`.

### 7.4 Events

Group membership changes should fire events through the existing
`Events::Dispatcher`:

| Event | Payload |
|---|---|
| `group_membership.created` | `{ user_id:, group_name:, source: }` |
| `group_membership.destroyed` | `{ user_id:, group_name:, source: }` |
| `group_role_mapping.created` | `{ group_name:, role_name: }` |
| `group_role_mapping.destroyed` | `{ group_name:, role_name: }` |

These allow host apps to react (audit log, notification, cache invalidation).

### 7.5 Custom Fields on Groups

If `group_source == :model`, groups are regular LCP models — they
automatically support custom fields, presenters, and permissions like any
other model.

---

## 8. External Sync Contract

Even without implementing LDAP/SCIM now, the design must not prevent it.
The sync contract is a host-side interface:

```ruby
# app/lcp_services/ldap_sync_adapter.rb
class LdapSyncAdapter
  # Called by a scheduled job or webhook in the host app.
  # The platform provides a bulk import API on the Groups::Registry.
  def sync!
    external_groups = fetch_from_ldap

    LcpRuby::Groups::BulkSync.call(
      groups: external_groups.map { |g|
        { name: g.cn, label: g.display_name, external_id: g.object_guid }
      },
      memberships: external_groups.flat_map { |g|
        g.member_dns.map { |dn| { group_name: g.cn, user_external_id: dn } }
      },
      source: :external,
      # Deactivate groups/memberships not in this sync payload
      prune_missing: true
    )
  end
end
```

`BulkSync` is a platform service (to be implemented) that:
1. Creates/updates groups matching by `external_id`
2. Creates/removes memberships
3. Marks stale memberships as `source: :external` + removed (not deleting
   locally-added memberships with `source: :local`)
4. Fires events for each change
5. Clears the Registry cache once at the end

This is out of scope for initial implementation but the data model
(`external_id`, `source` fields on groups and memberships) supports it.

---

## 9. Generator

Similar to `rails generate lcp_ruby:role_model`, a generator creates the
full group infrastructure:

```bash
rails generate lcp_ruby:groups
```

**Creates:**
- `config/lcp_ruby/models/group.yml`
- `config/lcp_ruby/models/group_membership.yml`
- `config/lcp_ruby/models/group_role_mapping.yml`
- `config/lcp_ruby/presenters/group.yml` (management UI)
- `config/lcp_ruby/permissions/group.yml`
- Menu entry for group management
- Sets `config.group_source = :model` in initializer

---

## 10. Open Questions

1. **Should group-role mappings support scope override?** E.g., group
   `GRP_Sales_Prague` maps to role `sales_rep` *with scope limited to
   Prague office*. Currently scope is defined in permissions YAML per role,
   not per group-role mapping. Adding scope to the mapping would allow the
   same role with different scopes per group — powerful but complex.
   Answer: No. It is not necessary.

2. **Group hierarchy (nested groups)?** AD supports nested groups.
   Recommended approach: flatten at sync time. The membership table stores
   the effective (flattened) memberships. Avoids recursive resolution at
   authorization time.
   Answer: flatten at sync time.

3. **Temporal group memberships?** `valid_from` / `valid_until` on
   memberships for time-limited access. Useful for project-based groups,
   contractor access. Adds query complexity to membership resolution.
   Answer: yes, but it is sufficient to check it once per session or cache it
   during the session (not necessary to check it during each permissision check)

4. **Group-based presenter visibility?** Currently presenters are filtered
   by role. Should groups directly control presenter access, or is
   group → role → presenter sufficient?
   Answer: group → role → presenter is sufficient for now.

---

## 11. Implementation Priority

| Priority | Item | Depends on |
|---|---|---|
| 1 | `Groups::Contract` interface | — |
| 2 | `Groups::Registry` (cache + delegation) | Contract |
| 3 | `Groups::YamlLoader` | Registry |
| 4 | Effective role resolution in `PermissionEvaluator` | Registry |
| 5 | `Groups::ContractValidator` + `Setup` | Registry |
| 6 | `Groups::ModelLoader` + `ChangeHandler` | Registry, ContractValidator |
| 7 | `Groups::HostLoader` (adapter delegation) | Contract |
| 8 | Generator (`lcp_ruby:groups`) | All above |
| 9 | `BulkSync` service | ModelLoader |
| 10 | Direct role assignment model | PermissionEvaluator |
