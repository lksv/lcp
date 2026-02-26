# Dynamic Presenters — Design Document

> **Status:** Proposed
> **Date:** 2026-02-26

## Problem

Presenters currently exist only as static YAML/DSL definitions, version-controlled and deployed with the application. This means that any change to what users see — which fields appear on an index page, how form sections are organized, which columns are visible — requires a code change and redeployment.

In practice, different users and roles have different needs. A sales manager wants to see deal value and close date on the index page; a support agent wants to see priority and SLA status. Today, the only way to serve both is to create separate static presenters and wire them into view groups — which requires developer involvement for every configuration change.

The platform's [Configuration Source Principle](../../CLAUDE.md) states that every configuration concept must support three input sources: DSL/YAML, dynamic table (DB), and host application contract API. Presenters currently only support the first.

## Goals

- Allow users to customize **which fields they see and in what order** on index, show, and form pages — without code changes or redeployment
- Support three scoping levels: system-wide (all users), per-role, and per-user personalization
- Preserve all safety guarantees: the permission system remains the final authority on field visibility, regardless of presenter configuration
- Integrate cleanly with existing view groups, custom fields, and the permission system
- Keep the YAML presenter as the authoritative "base" that defines the full set of available fields, their renderers, input types, validations, and behavioral rules

## Non-Goals

- Dynamically changing **how** fields behave (renderers, input types, validators, transforms) — that stays in YAML
- Dynamically changing **actions** (create, edit, destroy, custom actions) — that stays in YAML and permissions
- Dynamically changing **visible_when / disable_when conditions** — that stays in YAML
- Replacing static presenters — dynamic presenters are an override layer, not a replacement
- Dynamic models or dynamic fields — those are separate concerns (custom fields covers the latter)

## Design Decisions

### Override model, not standalone

Two approaches were considered:

| Approach | Pro | Con |
|----------|-----|-----|
| **Override** — YAML base + DB overrides | Safe: YAML controls behavior, DB controls layout. Simple validation. | Cannot create entirely new presenters at runtime |
| **Standalone** — full presenter in DB | Maximum flexibility | User can create broken configs (invalid renderer, wrong input_type). Hard to validate. |

**Decision:** Override model. A dynamic presenter always references a base YAML presenter by slug. It can only reorder, show/hide, and reorganize fields that exist in the base. All behavioral properties (renderer, input_type, visible_when, validations) come from the base and cannot be overridden.

This means the YAML author controls the "what is possible" boundary, and the dynamic presenter controls "what I want to see" within that boundary.

### Three scope levels with priority resolution

| Scope | Created by | Applies to | Priority |
|-------|-----------|------------|----------|
| **user** | Any user (for themselves) | That user only | Highest |
| **role** | Admin | All users with that role | Medium |
| **system** | Admin | All users | Lowest |

Resolution order: look for a user-specific override → if none, look for a role-specific override → if none, look for a system override → if none, use the YAML base as-is.

Only one override is applied — they do not stack/merge. If a user has a personal override, it completely replaces any role or system override for that page type. This keeps the mental model simple: "what you configured is exactly what you see."

### Per-page-type configuration

Each dynamic presenter config targets exactly one page type: `index`, `show`, or `form`. A user might customize their index columns but leave the form layout as default. This allows granular control without forcing users to configure everything at once.

### Permission system as final filter

This is the most critical safety property. Regardless of what a dynamic presenter configuration says, the permission system has the final word:

```
displayed_fields = dynamic_presenter_fields ∩ readable_fields(user_role)
editable_fields  = dynamic_presenter_fields ∩ writable_fields(user_role)
```

If a user adds a field to their dynamic presenter that their role cannot read, it simply does not appear. No error, no leak — the field is silently filtered out at render time.

This means dynamic presenters cannot be used for privilege escalation. The worst case is a user configuring fields they cannot see — they just get a shorter list than expected.

### Validation at save time, graceful degradation at render time

**At save time:** Validate that all referenced field names exist in the base model (including custom fields). Reject unknown field names with a clear error. This catches typos and stale references early.

**At render time:** If a previously valid field no longer exists (model changed, custom field deleted), skip it silently and log a warning. The page renders correctly with the remaining fields. No crashes, no broken pages.

This two-layer approach ensures that configurations are correct when created, but the system degrades gracefully if the underlying model evolves.

## Design

### Data Model

A single table `lcp_dynamic_presenter_configs`:

| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint PK | |
| `base_presenter_slug` | string, NOT NULL | References the YAML presenter's slug (e.g., `"deals"`, `"contacts"`) |
| `scope_type` | enum, NOT NULL | `system`, `role`, or `user` |
| `scope_identifier` | string, NULL | Role name for `role` scope, user identifier for `user` scope, NULL for `system` |
| `page_type` | enum, NOT NULL | `index`, `show`, or `form` |
| `configuration` | jsonb, NOT NULL | The override configuration (structure depends on page_type) |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Unique index on `[base_presenter_slug, scope_type, scope_identifier, page_type]` — at most one override per combination.

### Configuration JSON Structure

#### Index page

Controls which columns appear and in what order:

```json
{
  "columns": [
    { "name": "title", "width": "3" },
    { "name": "status" },
    { "name": "priority" },
    { "name": "cf_custom_deadline" }
  ]
}
```

Each entry in `columns` references a field name from the base model. The `width` property is optional (Bootstrap grid units). Only fields listed here appear on the index page; unlisted fields are hidden.

#### Show page

Controls field grouping into sections and field order within each section:

```json
{
  "sections": [
    {
      "label": "Overview",
      "fields": ["title", "status", "priority", "assigned_to_id"]
    },
    {
      "label": "Details",
      "collapsed": true,
      "fields": ["description", "cf_custom_deadline", "cf_internal_notes"]
    }
  ]
}
```

Each section has a `label` and a list of `fields` (by name). The optional `collapsed: true` renders the section initially collapsed. Fields not listed in any section are hidden.

#### Form page

Same structure as show page — sections with fields:

```json
{
  "sections": [
    {
      "label": "Basic Info",
      "fields": ["title", "status", "priority"]
    },
    {
      "label": "Additional",
      "collapsed": true,
      "fields": ["description", "cf_custom_deadline"]
    }
  ]
}
```

On forms, the permission system additionally filters by `writable_fields` — a field listed here but not writable for the user's role appears as read-only or is hidden entirely (following existing form behavior).

### Merge Pipeline

The resolution process when rendering a page:

```
1. Load YAML base PresenterDefinition (as today)
2. Query DB for the highest-priority dynamic override:
   → user override for (slug, page_type, current_user) ?
   → role override for (slug, page_type, current_role) ?
   → system override for (slug, page_type) ?
3. If no override found → use YAML base as-is (no change)
4. If override found → merge:
   a. Take field definitions from YAML base (renderers, input_types, all behavior)
   b. Apply dynamic config's field selection and ordering
   c. Apply dynamic config's section grouping (for show/form)
   d. Silently skip any fields in dynamic config that don't exist in the model
   e. Silently skip any fields the user's role cannot read/write
5. Pass the merged result to LayoutBuilder (existing pipeline, no changes needed)
```

The key property: everything **after** the merge is unchanged. LayoutBuilder, views, and JavaScript receive a PresenterDefinition that looks exactly like one loaded from YAML. They don't know or care that it was dynamically assembled.

### Custom Fields Integration

Custom fields (fields prefixed with `cf_`) are dynamically added to models at runtime. Dynamic presenters can reference custom fields by name, just like static fields. Since custom field definitions are loaded before presenter resolution, they are available for validation and merge.

When a custom field is deleted, any dynamic presenter configs referencing it degrade gracefully (field is skipped at render time).

### View Groups Integration

View groups allow switching between multiple presenters for the same model. Each presenter in a view group has its own slug. Dynamic overrides are keyed by slug, so each presenter in a view group can have independent dynamic overrides.

The view group switcher works unchanged — it switches between base presenters. The dynamic override for each base presenter is resolved independently.

### Caching

Dynamic presenter configs are cached in memory with invalidation on change:

- **Cache key:** `[base_presenter_slug, scope_type, scope_identifier, page_type]`
- **Invalidation:** `after_commit` callback clears the relevant cache entry (same pattern as custom fields and DB permissions)
- **System/role overrides:** Shared across users — one cache entry per combination
- **User overrides:** Per-user cache entries, but only for users who have created overrides. Users without overrides hit the shared system/role cache or skip to YAML base

### UI for Configuration

The platform generates its own management UI for dynamic presenter configs, following the same pattern as custom fields management. The configuration screen would show:

- Available fields from the base presenter (source list)
- Current configuration (target list with ordering)
- Ability to add/remove/reorder fields
- Section management for show/form pages (create sections, name them, assign fields)
- Preview of the result

The initial implementation can use a standard form-based UI (select fields, set order via position numbers). Drag-and-drop can be added as an enhancement.

### Permissions for Configuration Management

Two levels of access control:

| Action | Who can do it |
|--------|--------------|
| Edit **own** user-level override | Any authenticated user |
| Edit **role-level** overrides | Admin (or configurable permission) |
| Edit **system-level** overrides | Admin (or configurable permission) |
| Delete any override | Same as edit for that scope level |

User-level overrides are "personalization" — low risk, any user can do it. Role and system overrides affect others, so they require elevated permissions.

## Usage Examples

### Admin creates a system-wide index override

All users see a simplified deal index with just three columns:

```
base_presenter_slug: "deals"
scope_type: system
scope_identifier: NULL
page_type: index
configuration: {
  "columns": [
    { "name": "title" },
    { "name": "status" },
    { "name": "value", "width": "2" }
  ]
}
```

### Admin creates a role-specific form layout

Support agents get a form focused on support-relevant fields:

```
base_presenter_slug: "deals"
scope_type: role
scope_identifier: "support_agent"
page_type: form
configuration: {
  "sections": [
    {
      "label": "Ticket Info",
      "fields": ["title", "priority", "status", "assigned_to_id"]
    },
    {
      "label": "Customer",
      "fields": ["company_id", "contact_id"]
    }
  ]
}
```

### User personalizes their own index view

A sales manager adds custom fields to their personal index view:

```
base_presenter_slug: "deals"
scope_type: user
scope_identifier: "42"
page_type: index
configuration: {
  "columns": [
    { "name": "title" },
    { "name": "value", "width": "2" },
    { "name": "cf_close_probability" },
    { "name": "cf_next_action_date" },
    { "name": "status" }
  ]
}
```

## Implementation Phases

### Phase 1: Data model and resolution

- Define the `DynamicPresenterConfig` model with validations
- Implement the priority resolution logic (user → role → system → YAML base)
- Implement the merge logic (apply field selection/ordering from DB override onto YAML base)
- Add save-time validation (field names exist in model)
- Add runtime graceful degradation (skip unknown fields)

**Value:** The core mechanism works. Configs can be created via console or seeds.

### Phase 2: Caching and invalidation

- Add in-memory caching for resolved configs
- Add `after_commit` cache invalidation
- Ensure cache keys correctly segment by scope

**Value:** Production-ready performance.

### Phase 3: Management UI

- Generate a presenter and model for `DynamicPresenterConfig`
- Build the configuration screen (field picker, section organizer, ordering)
- Add user-level personalization entry point (e.g., "Customize view" button on index/show pages)
- Add admin-level management for role and system overrides

**Value:** Users can self-service their view configuration.

### Phase 4: Enhanced configuration options

- Add label overrides (user can rename a column header without changing the base)
- Add column width configuration for index pages
- Add section collapse defaults for show/form pages
- Consider drag-and-drop for field ordering

**Value:** Richer personalization capabilities.

## Related Documents

- **[Context-Aware Presenters](context_aware_presenters.md):** Selects which base presenter to use based on parent context (e.g., `deal.note` vs `contact.note`). Dynamic presenters apply their override layer on top of whichever base presenter context-aware resolution selects. These two designs are independent and compose naturally.
- **[Scoped Permissions](scoped_permissions.md):** The permission counterpart of context-aware presenters — same qualified-key pattern for permissions. Both use the same context string from the controller.
- **[Presenters Reference](../reference/presenters.md):** Defines the YAML presenter format that serves as the base for dynamic overrides.
- **[Custom Fields](../reference/custom-fields.md):** Dynamic fields that can be referenced in dynamic presenter configurations.
- **[View Groups](../reference/view-groups.md):** Multi-presenter navigation that coexists with dynamic overrides.
- **[Permission Source](../reference/permission-source.md):** DB-backed permissions follow the same pattern (static YAML base + DB overrides, cache + invalidation).

## Open Questions

1. **Label overrides in Phase 1 or Phase 4?** — Users may want to rename columns (e.g., "Company" → "Client") without changing the base presenter. This is low complexity but expands the configuration surface. Recommendation: defer to Phase 4.

2. **Reset to default:** Should users have a "Reset to default" action that deletes their override and falls back to the role/system/YAML base? Recommendation: yes, simple delete operation.

3. **Copy/share user overrides:** Should a user be able to share their personal configuration with others (promote to role or system level)? Recommendation: nice to have, not needed for initial release.

4. **Stacking vs. replacement:** The current design uses replacement (user override completely replaces role override). An alternative is stacking (user override merges with role override). Stacking is more powerful but harder to reason about — users cannot predict what they will see without understanding the full merge chain. Recommendation: keep replacement for simplicity.

5. **Form page: field addition risk.** A user could add a field to their form that the YAML base deliberately excluded (e.g., an internal field not meant for form input). The permission system's `writable_fields` prevents actual writes, but the field might still render as read-only. Is showing a read-only field on a form confusing? Recommendation: on forms, filter by both `readable_fields` AND presence in the YAML base's form sections — a field can only appear on a form if the base presenter intended it to be there.
