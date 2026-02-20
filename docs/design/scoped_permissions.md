# Scoped Permission Definitions — Design Document

## Overview

Currently, each LCP Ruby model has **one** permission definition (looked up by
model name). This works well for standard resources but breaks down for
**polymorphic sub-resources** — models that serve multiple parent contexts and
need different permission profiles per context.

The motivating case is `custom_field_definition`: one model stores field
definitions for all parent models (project, contact, deal, ...), but
enterprises need per-model control — "manager can create custom fields for
project but can only view them for contact."

This is a general pattern. Any polymorphic sub-resource could benefit:

| Sub-resource model | Context field | Example need |
|---|---|---|
| `custom_field_definition` | `target_model` | Different CRUD per parent model |
| `comment` (future) | `commentable_type` | Restrict who can comment on which entity |
| `attachment` (future) | `attachable_type` | Different file permissions per entity |
| `audit_log_entry` (future) | `auditable_type` | Different read access per entity |
| `approval_step` (future) | workflow context | Different approval permissions per workflow |

### Design Principles

1. **Three configuration sources** — YAML/DSL, DB, Host API (same as all
   platform concepts).
2. **Backward compatible** — unscoped permissions keep working unchanged.
   Scoped permissions are opt-in.
3. **General mechanism** — not custom-field-specific. Any model can use scoped
   permissions.
4. **Simple lookup** — the consumer (controller) knows the context and requests
   a specific permission. No runtime condition matching.

### Current State

`CustomFieldsController` hardcodes the permission lookup:

```ruby
# app/controllers/lcp_ruby/custom_fields_controller.rb:122-128
def current_evaluator
  perm_def = LcpRuby.loader.permission_definition("custom_field_definition")
  user = impersonating? ? impersonated_user : current_user
  Authorization::PermissionEvaluator.new(perm_def, user, "custom_field_definition")
end
```

All custom field operations — regardless of whether the parent is `project`,
`contact`, or `deal` — use the same permission definition. The only
differentiation possible today is `record_rules`, which can only **deny**
operations conditionally, not grant different permission profiles.

---

## 1. Why `record_rules` Are Insufficient

`record_rules` evaluate conditions against a record and **deny** specific CRUD
operations. They cannot:

| Need | `record_rules` | Scoped permissions |
|---|---|---|
| Different CRUD per context | Deny-only (start permissive, block down) | Full independent CRUD list per context |
| Different readable/writable fields per context | No | Yes |
| Different custom actions per context | No | Yes |
| Different scope per context | No | Yes |
| Grant a role access in one context but not another | No (deny can't grant) | Yes |
| Per-context default_role | No | Yes |

**Example that `record_rules` cannot express:**

> "manager can create+update custom fields for project, but can only view
> custom fields for contact."

With `record_rules` you'd start from the most permissive base (allow
create+update) and try to deny for contact:

```yaml
record_rules:
  - condition: { field: target_model, operator: eq, value: contact }
    effect:
      deny_crud: [create, update]
      except_roles: [admin]
```

This works for two contexts but becomes unmanageable at scale — every new model
needs a new deny rule. And it still can't differentiate field access, actions,
or scope per context. It's the wrong abstraction.

---

## 2. Approaches Considered

### Approach A: Qualified Permission Keys (recommended)

The `model:` field in permissions becomes a **permission key** that can include
a context prefix using dot-notation:

```yaml
# permissions/custom_field_definition.yml — global fallback
permissions:
  model: custom_field_definition
  roles:
    admin: { crud: [index, show, create, update, destroy] }
    viewer: { crud: [index, show] }

# permissions/project__custom_field_definition.yml — project-specific
permissions:
  model: project.custom_field_definition
  roles:
    admin: { crud: [index, show, create, update, destroy] }
    manager: { crud: [index, show, create, update] }
    viewer: { crud: [] }
```

**Lookup logic:** the consumer constructs a qualified key and the resolver
tries it first, falls back to the unqualified key:

```ruby
# Controller requests:
perm_def = LcpRuby.loader.permission_definition(
  "custom_field_definition",
  context: "project"
)
# Resolver tries: "project.custom_field_definition" → "custom_field_definition" → "_default"
```

### Approach B: Explicit `context` Attribute

Instead of encoding the context in the `model:` field, add an explicit
`context:` attribute:

```yaml
permissions:
  model: custom_field_definition
  context:
    field: target_model
    value: project
  roles: ...
```

**Lookup logic:** the resolver matches model name + context when available:

```ruby
perm_def = LcpRuby.loader.permission_definition(
  "custom_field_definition",
  context: { target_model: "project" }
)
```

### Approach C: Permission Inheritance with Context Override

Define a base permission and per-context overlays that inherit and selectively
override:

```yaml
# Base
permissions:
  model: custom_field_definition
  roles:
    admin: { crud: [index, show, create, update, destroy], fields: { readable: all, writable: all } }
    viewer: { crud: [index, show], fields: { readable: all, writable: [] } }

# Override (inherits base, overrides specific roles)
permissions:
  model: custom_field_definition
  context:
    field: target_model
    value: project
  inherits: custom_field_definition
  roles:
    manager: { crud: [index, show, create, update] }   # added
    viewer: { crud: [] }                                # overridden
    # admin: inherited from base (not redefined)
```

### Comparison

| Criterion | A: Qualified keys | B: Explicit context | C: Inheritance |
|---|---|---|---|
| Simplicity | High — just a naming convention | Medium — new attribute, matching logic | Low — merge semantics, cycle detection |
| YAML clarity | Key encodes context implicitly | Context is explicit and self-documenting | Most expressive but complex |
| Validation | Cannot validate context field exists on model | Can validate field + value against model | Complex: base + overlay validation |
| Multi-field context | Nested dots: `dept.project.cfd` | Natural: `{ target_model: project, dept: sales }` | Same as B + merge |
| DB source | Permission record with `model: "project.custom_field_definition"` | Separate `context_field` + `context_value` columns | Additional `inherits` column |
| Host API | `adapter.permission_for("project.custom_field_definition")` | `adapter.permission_for("cfd", context: {...})` | Complex adapter interface |
| File naming | `project__custom_field_definition.yml` | Same file name, different attribute | Same + `inherits` |
| Programmatic discovery | Grep for `*.custom_field_definition` | Query by model + context | Walk inheritance chain |
| Backward compatible | Fully — unqualified keys work as before | Fully — context is optional | Fully — inherits is optional |

---

## 3. Recommended Design: Qualified Permission Keys (Approach A)

Approach A is recommended because:

1. **Minimal new concepts** — it's just a naming convention on an existing field.
2. **Works identically across all three sources** — YAML key, DB record key,
   or host adapter method parameter.
3. **No new YAML attributes** — `model:` already exists; its semantics expand
   naturally from "model name" to "permission key".
4. **Simple resolver logic** — try specific key, fall back to generic key.
   No condition matching, no merge semantics.
5. **Covers the real use cases** — enterprise deployments define 5-10 parent
   models, each with an explicit permission file. The few-files approach is
   manageable and auditable.

Approach B's explicitness is valuable, but the matching logic adds complexity
that isn't justified by the use cases. Approach C's inheritance is powerful but
introduces merge semantics that are hard to reason about and debug.

### 3.1 Permission Key Format

```
[context.]model_name
```

- `custom_field_definition` — unscoped (global fallback)
- `project.custom_field_definition` — scoped to project context
- `contact.custom_field_definition` — scoped to contact context

The context prefix is a **free-form string** — it does not need to be a model
name (though it usually will be). This allows non-model contexts like
`public.document` vs `internal.document`.

### 3.2 YAML Source

**File naming convention:** replace the dot with double underscore in
filenames (dots are problematic in file names on some systems):

```
config/lcp_ruby/permissions/
  custom_field_definition.yml               # global fallback
  project__custom_field_definition.yml      # project-scoped
  contact__custom_field_definition.yml      # contact-scoped
```

The `model:` field inside the YAML uses the dot-notation:

```yaml
# permissions/project__custom_field_definition.yml
permissions:
  model: project.custom_field_definition
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions: all
    manager:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [field_name, field_type, label, required, position]
    viewer:
      crud: []
  default_role: viewer
```

**DSL format:**

```ruby
LcpRuby.define_permissions do
  permissions "project.custom_field_definition" do
    role :admin do
      crud [:index, :show, :create, :update, :destroy]
      fields readable: :all, writable: :all
    end

    role :manager do
      crud [:index, :show, :create, :update]
      fields readable: :all,
             writable: [:field_name, :field_type, :label, :required, :position]
    end

    default_role :viewer
  end
end
```

### 3.3 DB Source

When `permission_source == :model`, the permission record stores the full
qualified key in the model field:

| id | model | roles_json | ... |
|---|---|---|---|
| 1 | `custom_field_definition` | `{...}` | global fallback |
| 2 | `project.custom_field_definition` | `{...}` | project-scoped |
| 3 | `contact.custom_field_definition` | `{...}` | contact-scoped |

No schema changes needed — the `model` column already stores a string.

### 3.4 Host Application Contract API

The host adapter receives the full qualified key:

```ruby
module LcpRuby
  module Permissions
    module Contract
      # Returns a PermissionDefinition for the given permission key.
      # @param permission_key [String] e.g. "project.custom_field_definition"
      # @return [Metadata::PermissionDefinition, nil]
      def permission_for(permission_key)
        raise NotImplementedError
      end
    end
  end
end
```

**Example host adapter:**

```ruby
class MyPermissionAdapter
  include LcpRuby::Permissions::Contract

  def permission_for(permission_key)
    # Look up from corporate IAM system, external service, etc.
    raw = IamService.fetch_permissions(permission_key)
    return nil unless raw

    LcpRuby::Metadata::PermissionDefinition.from_hash(raw)
  end
end

# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.permission_source = :host
  config.permission_adapter = MyPermissionAdapter.new
end
```

The adapter can implement its own fallback logic internally, or return `nil`
to let the platform's default fallback chain handle it.

### 3.5 Resolver Changes

`Permissions::SourceResolver` gains a context-aware lookup:

```ruby
module LcpRuby
  module Permissions
    class SourceResolver
      # @param model_name [String] the base model name
      # @param loader [Metadata::Loader]
      # @param context [String, nil] optional context prefix
      # @return [Metadata::PermissionDefinition]
      def self.for(model_name, loader, context: nil)
        candidates = build_candidates(model_name, context)

        candidates.each do |key|
          result = resolve_single(key, loader)
          return result if result
        end

        # Final fallback: _default
        resolve_single("_default", loader) ||
          raise(MetadataError, "No permission definition found for '#{model_name}'")
      end

      private

      # Build ordered list of permission keys to try.
      #
      # For model_name="custom_field_definition", context="project":
      #   ["project.custom_field_definition", "custom_field_definition"]
      #
      # For model_name="custom_field_definition", context=nil:
      #   ["custom_field_definition"]
      def self.build_candidates(model_name, context)
        candidates = []
        candidates << "#{context}.#{model_name}" if context.present?
        candidates << model_name
        candidates
      end

      def self.resolve_single(key, loader)
        case LcpRuby.configuration.permission_source
        when :host
          adapter = LcpRuby.configuration.permission_adapter
          adapter&.permission_for(key)
        when :model
          return Registry.for_model(key) if Registry.available?
          loader.yaml_permission_definition(key)
        else # :yaml
          loader.yaml_permission_definition(key)
        end
      end
    end
  end
end
```

### 3.6 Loader Changes

`Metadata::Loader` must index permission definitions by their full `model:`
key (which now may contain dots):

```ruby
# lib/lcp_ruby/metadata/loader.rb
def yaml_permission_definition(key)
  @permission_definitions[key.to_s] || @permission_definitions["_default"]
end
```

No change needed — `@permission_definitions` is already a hash keyed by the
`model:` value from YAML. A YAML file with `model: project.custom_field_definition`
will be indexed under that key automatically.

### 3.7 Controller Changes

`CustomFieldsController` passes the parent context:

```ruby
# app/controllers/lcp_ruby/custom_fields_controller.rb
def current_evaluator
  @current_evaluator ||= begin
    context = @parent_model_definition.name
    perm_def = LcpRuby.loader.permission_definition(
      "custom_field_definition",
      context: context
    )
    user = impersonating? ? impersonated_user : current_user
    Authorization::PermissionEvaluator.new(perm_def, user, "custom_field_definition")
  end
end
```

And correspondingly for `policy` and `policy_scope`:

```ruby
def policy(record)
  context = @parent_model_definition.name
  perm_def = LcpRuby.loader.permission_definition(
    "custom_field_definition",
    context: context
  )
  policy_class = Authorization::PolicyFactory.policy_for_definition(perm_def, "custom_field_definition")
  policy_class.new(current_user, record)
end
```

Note: `PolicyFactory` gains a new method `policy_for_definition` that accepts
an already-resolved `PermissionDefinition` instead of looking it up by model
name. This avoids double-lookup and ensures the scoped definition is used.

### 3.8 PolicyFactory Changes

```ruby
module LcpRuby
  module Authorization
    class PolicyFactory
      class << self
        # Existing: lookup by model name (unchanged, backward compatible)
        def policy_for(model_name)
          policies[model_name.to_s] ||= build_policy_from_name(model_name)
        end

        # New: build policy from an already-resolved PermissionDefinition.
        # Not cached — the caller is responsible for caching if needed.
        def policy_for_definition(perm_def, model_name)
          build_policy(perm_def, model_name)
        end

        private

        def build_policy_from_name(model_name)
          perm_def = load_permission_definition(model_name)
          build_policy(perm_def, model_name)
        end

        def build_policy(perm_def, model_name)
          # ... existing dynamic policy class creation ...
        end
      end
    end
  end
end
```

---

## 4. Usage Beyond Custom Fields

### 4.1 Any Controller Can Use Context

The `context:` parameter on `permission_definition` is a general mechanism.
Any controller that manages a polymorphic resource can pass a context:

```ruby
# A hypothetical CommentsController
def current_evaluator
  perm_def = LcpRuby.loader.permission_definition(
    "comment",
    context: @commentable_type  # "project", "deal", etc.
  )
  Authorization::PermissionEvaluator.new(perm_def, user, "comment")
end
```

### 4.2 Nested Contexts

For deeply nested contexts (rare but possible), use chained dots:

```yaml
permissions:
  model: sales.project.custom_field_definition
```

The resolver tries in order:
1. `sales.project.custom_field_definition`
2. `project.custom_field_definition`
3. `custom_field_definition`
4. `_default`

To support this, `build_candidates` peels off context segments:

```ruby
def self.build_candidates(model_name, context)
  candidates = []
  if context.present?
    # Full qualified key
    candidates << "#{context}.#{model_name}"
    # If context itself has dots, try progressively shorter prefixes
    parts = context.split(".")
    while parts.size > 1
      parts.shift
      candidates << "#{parts.join('.')}.#{model_name}"
    end
  end
  candidates << model_name
  candidates
end
```

### 4.3 Validation

`ConfigurationValidator` should validate scoped permission keys:

- The part after the last dot must be a valid model name (or `_default`).
- The context prefix should produce a warning if it doesn't match any known
  model name (it might be intentional — e.g., `public.document` — but a warning
  helps catch typos).
- Scoped definitions must not duplicate role names with incompatible structures.

---

## 5. Examples

### 5.1 Custom Fields: Full Example

```yaml
# permissions/custom_field_definition.yml
# Global fallback: admin full access, everyone else read-only
permissions:
  model: custom_field_definition
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
  default_role: viewer

# permissions/project__custom_field_definition.yml
# Project custom fields: managers can also create/edit
permissions:
  model: project.custom_field_definition
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
    manager:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [field_name, field_type, label, required, position, default_value]
    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
  default_role: viewer

# permissions/contact__custom_field_definition.yml
# Contact custom fields: only admin, no one else
permissions:
  model: contact.custom_field_definition
  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
  default_role: viewer
  # viewer role not defined → falls back to default_role config
  # which has no crud → effectively no access
```

**Result:**

| Role | Project CF | Contact CF | Other CF (fallback) |
|---|---|---|---|
| admin | full CRUD | full CRUD | full CRUD |
| manager | index, show, create, update | no access | index, show (fallback viewer) |
| viewer | index, show | no access | index, show |

### 5.2 Future: Comments Per Entity

```yaml
# permissions/comment.yml
permissions:
  model: comment
  roles:
    admin: { crud: [index, show, create, update, destroy] }
    user: { crud: [index, show, create] }

# permissions/deal__comment.yml
# Deal comments: users can also edit their own (via record_rules)
permissions:
  model: deal.comment
  roles:
    admin: { crud: [index, show, create, update, destroy] }
    user: { crud: [index, show, create, update] }
  record_rules:
    - condition: { field: author_id, operator: not_eq, value: current_user_id }
      effect:
        deny_crud: [update, destroy]
        except_roles: [admin]
```

---

## 6. Migration Path

This is a **non-breaking, additive** change:

1. `SourceResolver.for` gains an optional `context:` parameter. Existing
   callers pass no context → behavior unchanged.
2. `CustomFieldsController` starts passing `context: @parent_model_definition.name`.
3. If no scoped permission file exists, fallback to the unscoped definition
   works exactly as today.
4. Platform users opt in by creating `<context>__<model>.yml` files.

No existing YAML files, DB records, or host adapters need changes.

---

## 7. Implementation Priority

| Priority | Item | Scope |
|---|---|---|
| 1 | `SourceResolver.for` — add `context:` parameter with fallback chain | Small change |
| 2 | `Loader` — verify dot-keys are indexed correctly (likely works already) | Verification |
| 3 | `CustomFieldsController` — pass parent model as context | Small change |
| 4 | `PolicyFactory.policy_for_definition` — accept pre-resolved definition | Small change |
| 5 | `ConfigurationValidator` — validate scoped permission keys | Medium |
| 6 | Documentation — reference + guide updates | Medium |
| 7 | Tests — scoped permission resolution, controller context passing | Medium |

---

## 8. Reusability for Future Platform Features

The qualified-key pattern is a **generic context-dispatch mechanism** on top of
the existing permission system. It does not introduce new permission semantics
— just a way to select which permission definition applies. This makes it
reusable wherever the platform needs "same model, different rules per context."

Below is an analysis of planned and likely future features, and how (or
whether) scoped permissions apply.

### 8.1 Applicability Matrix

| Feature | Context dimension | Scoped permissions useful? | Notes |
|---|---|---|---|
| **Custom field definitions** | `target_model` | **Yes — primary use case** | `project.custom_field_definition` |
| **Audit log** | `auditable_type` | **Yes** | Who can view audit trail per entity type |
| **Change history / versions** | `versionable_type` | **Yes** | Who can view/revert per entity type |
| **Comments / notes** | `commentable_type` | **Yes** | CRUD per entity type (see §5.2) |
| **Attachments** | `attachable_type` | **Yes** | Upload/download/delete per entity type |
| **Notifications** | `notifiable_type` | **Possibly** | Manage notification rules per entity |
| **Workflow transitions** | workflow name | **Yes** | Who can trigger transitions per workflow |
| **Approval steps** | workflow / entity | **Yes** | Who can approve per workflow context |
| **Tags / labels** | `taggable_type` | **Marginal** | Usually uniform access; scoping rarely needed |
| **Exports / reports** | report type | **Possibly** | Different export permissions per entity |
| **Imports** | target model | **Yes** | Who can bulk-import into which model |

### 8.2 Audit Log

An audit log model stores entries for all entity types. Without scoped
permissions, either everyone who can view audit logs can view all of them, or
you need `record_rules` to deny per type (fragile, deny-only).

With scoped permissions:

```yaml
# permissions/audit_log_entry.yml — global fallback
permissions:
  model: audit_log_entry
  roles:
    admin: { crud: [index, show], fields: { readable: all } }
    auditor: { crud: [index, show], fields: { readable: all } }
    viewer: { crud: [] }

# permissions/employee__audit_log_entry.yml — HR data audit is restricted
permissions:
  model: employee.audit_log_entry
  roles:
    admin: { crud: [index, show], fields: { readable: all } }
    hr_manager: { crud: [index, show], fields: { readable: all } }
    auditor: { crud: [] }   # general auditor cannot see HR audit trail
```

The audit log controller passes the audited entity type as context:

```ruby
# AuditLogController
def current_evaluator
  perm_def = LcpRuby.loader.permission_definition(
    "audit_log_entry",
    context: @auditable_type   # "employee", "project", etc.
  )
  Authorization::PermissionEvaluator.new(perm_def, user, "audit_log_entry")
end
```

**What scoped permissions add here:** The ability to make HR audit trails
visible only to HR, financial audit trails only to finance, etc. — without
maintaining a growing list of deny rules.

### 8.3 Change History / Versions

Similar to audit log but focused on record snapshots and revert capability.
The key difference: history may have a `destroy` action (revert/purge) that
needs per-entity control.

```yaml
# permissions/project__version.yml
permissions:
  model: project.version
  roles:
    admin: { crud: [index, show, destroy] }     # can purge old versions
    manager: { crud: [index, show] }            # read-only history
    viewer: { crud: [index] }                   # list only, no detail

# permissions/contract__version.yml
permissions:
  model: contract.version
  roles:
    admin: { crud: [index, show] }              # even admin can't purge contract history
    legal: { crud: [index, show] }              # legal team has access
    viewer: { crud: [] }                        # no access to contract history
```

This is a case where `record_rules` would be particularly inadequate — the
need is not just to deny CRUD but to provide entirely different field visibility
(e.g., contract version might show `changed_by` to legal but hide it from
others).

### 8.4 Workflow Transitions

The workflow design document (see `docs/design/workflow_and_approvals.md`)
defines transition guards with role-based `allowed_roles`. Scoped permissions
offer a complementary layer: instead of (or in addition to) per-transition
role checks, the entire workflow permission profile can vary by entity type.

```yaml
# permissions/workflow_transition.yml — default: only admin
permissions:
  model: workflow_transition
  roles:
    admin: { crud: [index, show, create] }

# permissions/purchase_order__workflow_transition.yml
# PO workflow: managers and procurement can trigger transitions
permissions:
  model: purchase_order.workflow_transition
  roles:
    admin: { crud: [index, show, create] }
    manager: { crud: [index, show, create] }
    procurement: { crud: [index, show, create] }
```

This does not replace the per-transition guard (`allowed_roles` on individual
transitions) but controls **who can interact with the workflow system at all**
for a given entity type — a coarser-grained check that runs before
transition-specific guards.

### 8.5 Approval Steps

Approval permissions could be scoped by the workflow or entity they belong to:

```yaml
# permissions/purchase_order__approval_step.yml
permissions:
  model: purchase_order.approval_step
  roles:
    admin: { crud: [index, show, create, update] }
    finance_approver: { crud: [index, show, update] }   # can approve/reject

# permissions/leave_request__approval_step.yml
permissions:
  model: leave_request.approval_step
  roles:
    admin: { crud: [index, show, create, update] }
    hr_manager: { crud: [index, show, update] }
    team_lead: { crud: [index, show, update] }          # team leads approve leave
```

### 8.6 Imports

Bulk import is a high-risk operation. Scoped permissions allow per-model
import control:

```yaml
# permissions/project__import.yml
permissions:
  model: project.import
  roles:
    admin: { crud: [create] }
    manager: { crud: [create] }

# permissions/employee__import.yml — restricted to HR
permissions:
  model: employee.import
  roles:
    admin: { crud: [create] }
    hr_admin: { crud: [create] }
```

### 8.7 Pattern: When Scoped Permissions Are the Right Tool

Scoped permissions fit when **all** of the following hold:

1. **One model serves multiple parent contexts** — polymorphic or shared
   sub-resource.
2. **Different contexts need different permission profiles** — not just
   deny-tweaks but fundamentally different CRUD, field access, or roles.
3. **The controller knows the context at request time** — it can construct
   the qualified key.
4. **The number of contexts is bounded and known** — typically entity types
   in the system (5-20), not arbitrary user data.

When the context is **unbounded or user-defined** (e.g., per-record ownership),
`record_rules` and `scope` remain the right tools. Scoped permissions are
about **structural context** (entity type, workflow type), not **data-level
context** (who owns this record).

### 8.8 What Does NOT Need Scoped Permissions

Some features look similar but don't benefit from this pattern:

| Feature | Why scoped permissions don't fit | Better mechanism |
|---|---|---|
| **Row-level ownership** ("I can only edit my records") | Context is per-record, not per-type | `scope: field_match` + `record_rules` |
| **Time-based access** ("read-only after 30 days") | Context is temporal, not structural | `record_rules` with date conditions |
| **Feature flags** ("beta users see this model") | Context is user attribute, not parent type | Role-based presenter access |
| **Multi-tenancy** ("tenant A can't see tenant B") | Context is tenant, applied globally | Scope at middleware/DB level |

---

## 9. Open Questions

1. **Should the fallback chain be configurable?** Currently hardcoded as
   `qualified → unqualified → _default`. Some deployments might want
   `qualified → _default` (skip unqualified fallback to enforce explicit
   scoped definitions).

2. **Caching for PolicyFactory:** `policy_for_definition` is not cached
   because the same model name can have different definitions per context.
   Should we cache by qualified key instead? The performance impact depends on
   how many unique contexts exist (typically < 20, so likely negligible).

3. **Scope in scoped permissions:** When `project.custom_field_definition`
   defines a `scope:`, should it automatically include
   `where(target_model: "project")`, or must the controller handle that
   separately (as it does today)? Auto-adding the scope would be convenient
   but couples the permission system to the `target_model` field convention.
   Recommendation: keep the controller responsible for parent scoping
   (separation of concerns).
