# Authorization and Access Control — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Role-Based Access Control (RBAC)

- [x] Role definitions in metadata (admin, editor, viewer, custom roles...)
- [ ] Role hierarchy (role inherits permissions from parent role)
- [x] Multiple roles per user — effective roles = direct roles ∪ group-derived roles
- [x] User groups (team / organizational unit) with their own permissions — Groups subsystem with YAML, DB, and host adapter sources
- [ ] Contextual roles — role valid only within a specific module / project / record
- [ ] Permission delegation (user can temporarily transfer their rights to another)
- [ ] Time-limited permissions (role validity from–to)

## Column-Based Access (field-level permissions)

- [x] Field visibility by role (field not displayed at all)
- [x] Read-only field by role (field displayed but not editable)
- [x] Value masking by role (e.g., displaying "***" for sensitive data)
- [x] Conditional field visibility based on record state (e.g., field locks after approval) — `visible_when` + `disable_when`
- [ ] Different default field values by role
- [ ] Restricted allowed field values by role (different selection range for different roles)

## Row-Based Access (record-level permissions)

- [x] Record filtering by role (user sees only "their" records) — scope in permissions YAML
- [x] Filtering by organizational unit / team — via scope with field_match or association
- [x] Filtering by record owner — scope with field_match on owner field
- [ ] Record sharing with specific users / groups
- [x] Access based on workflow state (e.g., "in progress" visible only to author, "approved" visible to all) — record_rules with conditions
- [x] Dynamic metadata-driven filters (rules like: `role = 'manager' AND department = record.department`) — ConditionEvaluator with 12 operators

## Action and Button Permissions

- [x] CRUD permissions per entity per role (create / read / update / delete separately)
- [x] Button / action visibility by role — ActionSet with permission checks
- [x] Button / action visibility by record state (workflow state) — record_rules + `action_permitted_for_record?`
- [x] Button / action visibility by role + state combination
- [x] Custom actions with their own permissions (export, approve, reject, escalate...) — `can_execute_action?`
- [ ] Bulk actions — permissions for batch operations
- [x] Action confirmation (confirm dialog) for destructive operations by role — `confirm: true` on actions
- [ ] Action rate limiting per user / role (abuse protection)

## View and Navigation Permissions

- [x] Menu item visibility by role — menu.yml with `visible_to` roles
- [x] Page / view access by role — presenter-level `presenters` permission
- [ ] Dashboard and widget visibility by role
- [ ] Filter and export access restriction by role
- [ ] Custom landing page by role (different dashboard for admin vs. regular user)

## Audit and Tracking

- [ ] Logging all access (who, when, what was viewed / changed)
- [x] Logging denied access (who attempted unauthorized action) — Pundit denial raises, can be logged
- [ ] Permission change history (who added / removed a role from whom)
- [ ] Audit log export capability
- [ ] Suspicious activity notification (unusual access pattern)

## Permission Management

- [~] UI for role and permission management (admin panel) — permission_source: :model enables DB-backed editing
- [x] Permissions driven purely by metadata (without deployment) — YAML + DB sources
- [x] Permission matrix — role × entity × action overview — rake task `lcp_ruby:permissions`
- [x] Test mode "view as role X" (impersonation for admins)
- [ ] Permission configuration versioning (rollback on error)
- [ ] Permission configuration import / export between environments (dev → staging → prod)

## Security Principles

- [x] Deny by default — what is not explicitly allowed is denied
- [x] Backend enforcement (not just UI hiding) — Pundit policies on every controller action
- [x] API endpoints respect same rules as UI
- [ ] Privilege escalation prevention (user cannot grant themselves permissions)
- [ ] Data separation between tenants (multi-tenant isolation)
- [ ] Token / session management — expiration, revocation, refresh strategy

---

## Key Points

- **Deny by default and backend enforcement** — in low-code platforms there's a strong temptation to handle permissions just by hiding UI elements, which is a security hole.
- **Contextual roles** — in enterprise environments it's common for a user to be admin in one module and viewer in another. Classic flat RBAC doesn't handle this.
- **Impersonation / "view as"** — huge time saver for testing and support. Without it, permissions are hard to debug.
