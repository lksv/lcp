# Feature Specification: Saved Filters & Parameterized Scopes

**Status:** Implemented
**Date:** 2026-03-02

## Problem / Motivation

Users build complex filters in the advanced search UI (multiple conditions, nested groups, association traversal) and then lose them when they navigate away. Every return to the index page requires re-building the same filter from scratch. There is no mechanism to name, persist, share, or preset user-created filter combinations.

Separately, the existing scope system is limited to fire-and-forget named scopes (`scope.send(scope_name)`) with no parameters. A scope like "items created in the last N days" or "assigned to user X" cannot be exposed to end-users because there is no UI for entering scope arguments.

### Concrete Pain Points

- **Repetitive filter construction.** A sales manager who checks "overdue deals > $10k in my region" daily must re-build 3+ conditions every time.
- **No filter sharing.** A team lead discovers a useful filter combination but cannot share it with the team except by sharing a URL.
- **No default views.** Users cannot set their preferred "landing" filter for a presenter. Everyone sees the unfiltered list.
- **No role-specific pre-built filters.** Configurators can define `predefined_filters` (scope buttons) but these are static, hard-coded in YAML, and require developer involvement to change. End-users and power-users cannot contribute their own.
- **Scopes are all-or-nothing.** The `@active` scope in QL works, but `@created_recently(days: 30)` does not. Parameterized scopes — one of the most powerful filtering mechanisms — are invisible to the filter UI.

### What Works Today

| Feature | Status | Notes |
|---------|--------|-------|
| Visual filter builder | Working | Condition tree with nested groups, all operators |
| Query Language (QL) | Working | Bidirectional: visual <-> QL text |
| Predefined filter buttons | Working | Static scope buttons from presenter YAML |
| Presets (advanced_filter) | Working | Static condition trees in presenter YAML |
| URL-based filter state | Working | Filters encoded as `?f[...]` URL params |
| Scope references in QL | Working | `@scope_name` (no parameters) |

## User Scenarios

### Scenario 1: Personal saved filter

A customer support agent frequently checks "Open tickets assigned to me, priority High or Critical." They build this filter once in the visual builder, click "Save filter", name it "My urgent tickets", and choose visibility "Personal." From now on, a button/link for this filter appears on the tickets index page. Clicking it applies the saved conditions instantly.

### Scenario 2: Role-shared filter

A sales manager creates a filter "Pipeline > $50k, stage = Negotiation or Proposal" and saves it with visibility "Role: manager." All users with the manager role see this filter on the deals index page. Regular sales reps do not.

### Scenario 3: Global filter

An admin creates "All records modified this week" as a global filter. Every user sees it on the relevant index page regardless of role.

### Scenario 4: Group-shared filter

In a multi-team setup (Groups feature enabled), a project lead saves "Sprint 12 open items" with visibility "Group: Team Alpha." Only members of Team Alpha see this filter.

### Scenario 5: Default filter

A user sets their "My active deals" personal filter as the default. When they navigate to the deals index without any explicit filter, this saved filter is automatically applied. They see a visual indicator that a default filter is active and can clear it with one click.

### Scenario 6: Editing a saved filter

A user notices their saved filter "This quarter's deals" needs an additional condition. They activate the filter, modify the conditions in the visual builder, and click "Update filter" (instead of "Save as new"). The existing saved filter is updated in place.

### Scenario 7: Parameterized scope in the filter builder

A model defines a `created_recently` scope that accepts a `days` parameter. In the filter builder, the user selects "Created recently" from the field picker (under a "Scopes" group), sees a number input for "Days back" (default: 7), enters 30, and applies. In QL mode, this appears as `@created_recently(days: 30)`.

### Scenario 8: Model-select scope parameter

A model defines a `by_assigned_user` scope with a `user_id` parameter of type `model_select`. In the filter builder, selecting this scope shows a select dropdown populated with user records. The user picks "John Smith" and applies. The scope receives `user_id: 42`.

### Scenario 9: Stale filter graceful degradation

A saved filter references a `category.name` field, but the `category` association was later removed from the model. When the user activates this filter, the system skips the invalid condition, applies the remaining valid conditions, and shows a warning: "1 condition was skipped because the field 'category.name' no longer exists."

## Configuration & Behavior

### Presenter YAML Configuration

```yaml
# config/lcp_ruby/presenters/deals.yml
search:
  enabled: true
  advanced_filter:
    enabled: true
    saved_filters:
      enabled: true                              # master switch (default: false)
      visibility_options: [personal, role, global] # which types offered in save dialog
      # add 'group' when groups feature is enabled for this entity
      max_per_user: 50                           # personal filter cap per user per presenter
      max_per_role: 20                           # role filter cap per role per presenter
      max_global: 30                             # global filter cap per presenter
      allow_pinning: true                        # can users pin filters to the toolbar?
      allow_default: true                        # can users set a default filter?
      display: inline                            # inline | dropdown | sidebar
      max_visible_pinned: 5                      # pinned filters shown before overflow
      show_counts: false                         # show record count badges (expensive)
```

**Display modes:**

- **`inline`** (default) — Saved filters appear as buttons alongside predefined filters. Pinned filters show first, the rest in a "More" dropdown.
- **`dropdown`** — A single "Saved Filters" dropdown button that lists all available filters, grouped by visibility scope.
- **`sidebar`** — A collapsible sidebar panel on the left of the index table. Good for applications with many saved filters.

**Visibility options:**

| Visibility | Who sees it | Who can edit/delete | Requires |
|------------|-------------|---------------------|----------|
| `personal` | Only the creator | Only the creator | Nothing |
| `role` | All users with `target_role` | Creator + permission-based | Roles feature |
| `global` | Everyone with index access | Creator + permission-based | Nothing |
| `group` | Members of `target_group` | Creator + permission-based | Groups feature (`group_source != :none`) |

The `visibility_options` array controls which choices appear in the save dialog. An app that does not need role-based or global filters simply omits them. The `group` option is automatically hidden if `group_source: :none`.

### Saved Filter Data Model

The saved filter is a **regular LCP dynamic model** — not a special internal table. A generator creates the full YAML stack:

```bash
bundle exec rails generate lcp_ruby:saved_filters
```

This generates:

| File | Purpose |
|------|---------|
| `config/lcp_ruby/models/saved_filter.yml` | Model definition |
| `config/lcp_ruby/presenters/saved_filters.yml` | Admin management presenter |
| `config/lcp_ruby/permissions/saved_filter.yml` | Default permission rules |

**Generated model fields:**

```yaml
name: saved_filter
table_name: lcp_saved_filters
fields:
  - { name: name, type: string, required: true }
  - { name: description, type: text }
  - { name: target_presenter, type: string, required: true }
  - { name: condition_tree, type: json, required: true }
  - { name: ql_text, type: text }
  - { name: visibility, type: enum, values: [personal, role, global, group], default: personal }
  - { name: owner_id, type: integer, required: true }
  - { name: target_role, type: string }
  - { name: target_group, type: string }
  - { name: position, type: integer }
  - { name: icon, type: string }
  - { name: color, type: string }
  - { name: pinned, type: boolean, default: false }
  - { name: default_filter, type: boolean, default: false }
userstamps: true
```

The configurator can then customize this YAML freely — add fields (tags, expiration date), change permissions, add custom actions (duplicate, share, export), modify the management presenter, etc.

**QL text synchronization:** Both `condition_tree` and `ql_text` are stored. The `ql_text` is regenerated from the tree on every save (via `QueryLanguageSerializer`) to keep them consistent. The QL text serves as a human-readable summary displayed in tooltips and filter lists.

### Saved Filter Permissions

The generated permissions YAML provides sensible defaults:

```yaml
# config/lcp_ruby/permissions/saved_filter.yml
admin:
  crud: [create, read, update, delete]
  # Full access to all filters

manager:
  crud: [create, read, update, delete]
  fields:
    writable: [name, description, condition_tree, visibility, pinned, default_filter, position, icon, color, target_role, target_group]
  record_rules:
    - deny: [update, delete]
      when:
        visibility: { not_eq: personal }
        owner_id: { not_eq: "{current_user.id}" }
      # Managers can only edit non-personal filters they own

user:
  crud: [create, read, update, delete]
  record_rules:
    - deny: [update, delete]
      when:
        visibility: { not_eq: personal }
      # Users can only edit their own personal filters
    - deny: [create]
      when:
        visibility: { in: [global, role] }
      # Users cannot create global or role filters
```

**Permission-controlled visibility creation:** Which `visibility_options` a user can actually choose when saving is intersected with their permissions. A `user` role that is denied creating `global` filters won't see "Global" in the save dialog, even if the presenter allows it.

### Default Filter Priority

When multiple `default_filter: true` entries exist for the same presenter, resolution order:

1. **Personal** default (user's own)
2. **Group** default (user's group)
3. **Role** default (user's role)
4. **Global** default

Only the highest-priority default applies. If a user has a personal default, all others are ignored.

A default filter is only applied when the user navigates to the index with **no** explicit filter parameters. Any `?f[...]`, `?filter=`, `?qs=`, or `?saved_filter=` param overrides the default.

### Name Uniqueness

Filter names are unique within the scope `(target_presenter, visibility, owner_id)`:

- Two personal filters for the same presenter by the same user cannot share a name.
- Different users can each have a personal filter named "My Important Items."
- Global filters: unique within `(target_presenter, visibility: global)`.
- Role filters: unique within `(target_presenter, visibility: role, target_role)`.
- Group filters: unique within `(target_presenter, visibility: group, target_group)`.

### URL Representation

Two modes for applying a saved filter:

1. **By reference:** `?saved_filter=<id>` — The controller loads the condition tree from DB and applies it. Compact URL. Breaks if the filter is deleted.
2. **By value:** `?f[...]=...` — Full conditions inlined in the URL. Long URL. Works independently of the saved filter record.

The default is **by reference**. A "Copy filter link" action generates a **by value** URL (so the link works for recipients who may not have access to the saved filter record).

### Index Page Display

#### Inline Mode (default)

```
[All] [Active] [Published] | [My Urgent ★] [Q1 Pipeline ★] [▼ Saved...] [+ Save]
                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^
                             pinned saved filters            overflow
```

- Pinned filters appear as buttons, up to `max_visible_pinned`.
- Remaining filters in a dropdown, grouped by visibility: "My Filters", "Team Filters", "Global."
- Active saved filter gets the `active` CSS class.
- A "Save" button appears when the visual builder has active conditions.

#### Dropdown Mode

```
[All] [Active] [Published]   [Saved Filters ▼]   [+ Save]
                               ┌─────────────────────┐
                               │ My Filters           │
                               │   My urgent tickets  │
                               │   High priority      │
                               │ Team Filters         │
                               │   Q1 Pipeline        │
                               │ Global               │
                               │   All open deals     │
                               └─────────────────────┘
```

#### Sidebar Mode

A collapsible panel on the left side of the index table with a tree/list of saved filters, expandable by visibility group. Good for apps with many saved filters.

#### Save Dialog

When the user clicks "Save filter" (with active conditions in the visual builder):

- **Name** (required, text input)
- **Description** (optional, text input)
- **Visibility** (select: personal/role/global/group — choices restricted by permission)
- **Target role** (shown only when visibility = role; select from available roles)
- **Target group** (shown only when visibility = group; select from available groups)
- **Pin to toolbar** (checkbox, if `allow_pinning: true`)
- **Set as default** (checkbox, if `allow_default: true`)
- **Icon** (optional, icon picker or text input)
- **Color** (optional, color picker)

#### Edit Flow

When a saved filter is active, the filter panel shows "Editing: [filter name]" with "Update" and "Save as new" buttons (instead of the normal "Apply" button). "Update" modifies the existing record. "Save as new" opens the save dialog pre-filled.

### Predefined Filters vs Saved Filters Interaction

Predefined filters (static scope buttons from YAML) and saved filters are **mutually exclusive at activation time**:

- Clicking a predefined filter deactivates any active saved filter.
- Activating a saved filter deactivates any active predefined filter.
- However, a saved filter CAN include a scope reference (`@active`) in its condition tree, effectively combining scope + conditions.
- Predefined filters and saved filters appear in the same toolbar area, visually separated by a divider.

---

## Parameterized Scopes

This is a separate enhancement to the advanced search system that enables custom AR scopes with user-provided arguments.

### Model YAML Configuration

```yaml
# config/lcp_ruby/models/deal.yml
scopes:
  # Simple scope (existing behavior, no change)
  active:
    where: { status: active }

  # Parameterized scope (NEW)
  created_recently:
    type: parameterized
    parameters:
      - name: days
        type: integer
        default: 7
        min: 1
        max: 365

  by_assigned_user:
    type: parameterized
    parameters:
      - name: user_id
        type: model_select
        model: user
        display_field: name
        filter_scope: active        # optional: prefilter the select options
        required: true
      - name: include_delegated
        type: boolean
        default: false

  in_date_range:
    type: parameterized
    parameters:
      - name: start_date
        type: date
        required: true
      - name: end_date
        type: date
        required: true

  by_category:
    type: parameterized
    parameters:
      - name: category
        type: enum
        values: [electronics, clothing, food, services]
        required: true
      - name: include_subcategories
        type: boolean
        default: true
```

The YAML defines **parameter metadata** (what the UI renders). The actual filtering logic is implemented in Ruby — either as a standard AR scope or a `filter_*` interceptor method.

### Parameter Types

| Type | UI Widget | YAML Options |
|------|-----------|-------------|
| `boolean` | Checkbox | `default` |
| `string` | Text input | `default`, `placeholder` |
| `integer` | Number input | `default`, `min`, `max`, `step` |
| `float` | Number input | `default`, `min`, `max`, `step` |
| `enum` | Select dropdown | `values: [...]`, `default` |
| `date` | Date picker | `default` |
| `datetime` | Datetime picker | `default` |
| `model_select` | Select populated from model records | `model`, `display_field`, `filter_scope`, `multiple` |

The `model_select` type deserves detail:

- `model` — the LCP model name to query for options (e.g., `user`, `category`)
- `display_field` — which field to show as the option label (default: first string field)
- `filter_scope` — optional named scope to prefilter the options (e.g., only active users)
- `multiple: true` — allow multi-select (scope receives an array)

### Ruby Side

The actual scope is defined in Ruby. The YAML `parameters` block only describes the UI.

```ruby
# Option A: Standard AR scope (in a model mixin or DSL extension)
scope :created_recently, ->(days: 7) { where("created_at >= ?", days.to_i.days.ago) }

# Option B: filter_* interceptor (more flexible, receives evaluator)
def self.filter_created_recently(scope, params, evaluator)
  days = params["days"]&.to_i || 7
  scope.where("created_at >= ?", days.days.ago)
end

# Option C: Scope with model_select parameter
scope :by_assigned_user, ->(user_id:, include_delegated: false) {
  base = where(assigned_to_id: user_id)
  include_delegated ? base.or(where(delegated_to_id: user_id)) : base
}
```

When `type: parameterized` is set in YAML, the platform skips the normal `scope.send(scope_name)` invocation. Instead, it extracts parameter values from the request, casts them according to the declared types, and passes them as keyword arguments.

### Appearance in Advanced Search

In the visual filter builder, parameterized scopes appear as a separate group in the field picker:

```
Field picker:
  ├── Direct Fields
  │   ├── Name
  │   ├── Status
  │   └── ...
  ├── Category (association)
  │   ├── Name
  │   └── ...
  └── Scopes                    ← NEW group
      ├── Created recently
      ├── By assigned user
      └── In date range
```

Selecting a scope replaces the normal operator+value UI with the scope's parameter inputs. Each parameter renders its appropriate widget (number input, date picker, select, etc.).

### QL Syntax for Parameterized Scopes

```
@created_recently(days: 30)
@by_assigned_user(user_id: 42, include_delegated: true)
@in_date_range(start_date: '2026-01-01', end_date: '2026-03-31')
status = 'active' and @created_recently(days: 7)
```

The parser recognizes `@identifier(key: value, ...)` as a parameterized scope reference. String values are quoted, numbers and booleans are bare.

### URL Parameter Format

```
?scope[created_recently][days]=30
?scope[by_assigned_user][user_id]=42&scope[by_assigned_user][include_delegated]=true
```

A new `scope` param namespace, separate from `f[...]` (Ransack) and `cf[...]` (custom fields).

### Pipeline Integration

A new step in `apply_advanced_search` (between the current step 2 "predefined filter scope" and step 3 "sanitize params"):

1. Extract `params[:scope]` hash
2. For each key, look up the scope definition in model YAML
3. Validate that the scope is `type: parameterized` and the parameters match declared types
4. Cast parameter values according to type definitions
5. Call the scope with cast keyword arguments (or delegate to `filter_*` interceptor)
6. Remove processed entries from `params[:scope]`

### Saved Filters with Parameterized Scopes

A saved filter's `condition_tree` can include parameterized scope nodes:

```json
{
  "combinator": "and",
  "children": [
    { "field": "@created_recently", "operator": "scope", "params": { "days": 30 } },
    { "field": "status", "operator": "eq", "value": "active" }
  ]
}
```

The `params` key on a scope condition node stores the parameter values. On save, these are validated against the scope's parameter definitions. On load, they're used to invoke the scope.

---

## General Implementation Approach

### Saved Filters

The saved filter feature has two distinct parts:

1. **Data layer** — A standard LCP dynamic model (`saved_filter`) with CRUD, permissions, and a management presenter. Created by a generator. No special infrastructure needed — uses the existing model/presenter/permission stack.

2. **Integration layer** — Platform code that connects saved filters to the index page: loading visible filters for the current user/role/group, rendering them in the toolbar, handling the save/update dialog, and applying a saved filter's condition tree through the existing `apply_advanced_search` pipeline.

**Loading visible filters:** A query that unions: (a) personal filters where `owner_id = current_user.id`, (b) role filters where `target_role = current_role`, (c) global filters, and (d) group filters where `target_group` is in the user's groups. All scoped to `target_presenter = current_slug`. Ordered by `pinned DESC, position ASC`.

**Applying a saved filter:** When `?saved_filter=<id>` is in the URL, the controller loads the record, verifies the user has visibility access, extracts the `condition_tree`, and feeds it through `FilterParamBuilder` to generate Ransack params + custom field params. These then flow through the normal pipeline (steps 3-7).

**Save flow:** The JS collects the current filter state (condition tree from the visual builder), opens a dialog for metadata (name, visibility, etc.), and POSTs to a new endpoint. The server validates, serializes the QL text, and creates/updates the record.

**Stale field validation:** On filter application, each condition in the tree is validated against current `FilterMetadataBuilder` fields. Invalid conditions (referencing removed fields, inaccessible fields, deactivated custom fields) are silently excluded from the query. A list of skipped conditions is returned to the JS for a warning toast.

### Parameterized Scopes

The parameterized scope feature extends three existing subsystems:

1. **Model metadata** — `ScopeDefinition` gains a `type: parameterized` variant with a `parameters` array. Each parameter has a name, type, default, and type-specific options (min/max, enum values, model reference).

2. **Filter UI** — `FilterMetadataBuilder` emits scope entries in the fields list with `type: "scope"` and a `parameters` array. The JS renders parameter-specific inputs when a scope is selected.

3. **Controller pipeline** — A new step extracts `params[:scope]`, validates and casts arguments, and invokes the scope. The `filter_*` interceptor pattern is reused for scopes that need custom logic.

### Record Count Badges (Optional)

When `show_counts: true`, the index page asynchronously fetches record counts for each visible saved filter. This is an N+1 concern (one query per filter), so counts are:

- Loaded asynchronously via a JS fetch after the page renders
- Cached per user/role with a short TTL (configurable)
- Only computed for visible (pinned / dropdown-rendered) filters, not all saved filters

---

## Decisions

**Saved filter as a regular LCP model (not internal table).**
Rationale: Follows the Configuration Source Principle. Configurators get full control via YAML customization. The model gets standard features (permissions, auditing, custom fields, admin management UI) for free. No special-case code paths.

**Generator-based setup (not auto-created).**
Rationale: The saved filter model is opt-in. Not every app needs it. The generator approach matches the existing patterns (custom fields generator, role source generator). The configurator runs the generator and then customizes the output.

**Condition tree stored as JSON, QL text as a derived convenience.**
Rationale: The condition tree is the canonical representation (it's what `FilterParamBuilder` consumes). The QL text is derived via `QueryLanguageSerializer` and stored for display/search convenience. Keeping both avoids re-serialization on every render.

**Mutual exclusivity between predefined filters and saved filters at activation time.**
Rationale: Predefined filters activate named scopes; saved filters apply condition trees. Allowing both simultaneously would create confusing overlapping behavior. A saved filter can include `@scope_name` in its condition tree if the user wants the combination.

**`?saved_filter=<id>` as the primary URL format.**
Rationale: Saved filters can be arbitrarily complex. Inlining the full condition tree as URL params can exceed URL length limits. The by-reference approach keeps URLs compact. The "Copy filter link" action generates a by-value URL for sharing.

**Parameterized scope parameters defined in YAML, logic in Ruby.**
Rationale: The YAML defines what the UI needs to render (parameter names, types, defaults, constraints). The actual query logic is in Ruby (AR scopes or `filter_*` methods). This separation follows the platform's metadata-for-UI, code-for-logic principle.

**No filter expiration for the initial version.**
Rationale: An `expires_at` field is over-engineering. If needed later, it can be added as a custom field on the saved filter model or via a YAML model extension.

**Filter versioning handled by auditing, not a custom mechanism.**
Rationale: If the configurator enables `auditing: true` on the saved filter model, condition tree changes are tracked automatically via the existing audit log. No dedicated versioning system needed.

**No bulk filter management UI in the initial version.**
Rationale: The inline edit/delete in the dropdown and the admin management presenter are sufficient. A dedicated "Manage my filters" page can be added later if demand arises.

**Strictly one filter per presenter (no cross-presenter filters).**
Rationale: Keeps the model simple (`target_presenter` is a single string). Filters like "created this week" that apply to multiple presenters can be duplicated — or a future extension could add `target_model` as an alternative to `target_presenter`.

**Sidebar mode: saved filters coexist with predefined filter buttons.**
Rationale: Predefined filters are static, configurator-defined quick-access buttons. Saved filters are user-created. Both serve different purposes and should be visible simultaneously. Visual hierarchy: predefined filters at the top of the sidebar, saved filters below.

**model_select caching for scope parameters deferred.**
Rationale: Loading options for `model_select` parameter dropdowns will use the simplest approach first (eager load with filter metadata). Lazy loading and caching can be optimized later if performance becomes an issue.

**Parameterized scopes called directly as AR scopes.**
Rationale: Standard AR scopes with matching parameter signatures are invoked directly — no need to wrap every scope in a `filter_*` interceptor. The `filter_*` interceptor remains available for scopes that need access to the evaluator or complex logic, but simple scopes just work.

**No notify-on-match in the initial version.**
Rationale: Notification is a separate feature with its own complexity (scheduling, delivery, subscription management). The saved filter model is kept minimal. If needed later, it can be extended via custom fields or a dedicated notification model.

## Open Questions

1. **Filter analytics.** Track usage counts and last-used timestamps for saved filters? Useful for admins to curate global filters and deprecate unused ones. Adds a DB write on every filter activation — nice to have, not required for the initial version.

## Related Documents

- **[Page Layouts & View Slots](page_layout_and_slots.md)** — Slot registry that saved filters will use to inject into the `:filter_bar` slot on index pages (Phase 1 implemented)
- **[View Slots Reference](../reference/view-slots.md)** — API reference for registering slot components
- **[Advanced Search & Filter Builder](advanced_search.md)** — The existing filter pipeline that saved filters build on
