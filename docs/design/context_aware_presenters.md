# Context-Aware Presenter Resolution — Design Document

> **Status:** Proposed
> **Date:** 2026-02-26

## Problem

The platform has polymorphic models — models that belong to multiple parent entities. A `Note` model can belong to a `Deal`, a `Contact`, or a `Company`. An `Attachment` can belong to a `Contract`, a `Deal`, or a `Project`. When viewing these sub-resources in the context of different parents, users need different layouts:

- Notes under a deal → show `note_type`, `next_action` with badge renderer, meeting-focused search filters
- Notes under a contact → show `priority`, `assigned_to` with different sections on the show page
- Notes at top level (no parent) → generic fallback layout

Today, presenter resolution is context-blind. One model maps to one presenter (or multiple via view groups, but those are manually switched by the user, not automatically selected by context). There is no way to say "when this model is viewed under that parent, use this presenter."

This is the **presenter counterpart** of the [Scoped Permissions](scoped_permissions.md) design, which solves the identical problem for permissions. Scoped permissions allow `deal.note` to have different CRUD rules than `contact.note`. Context-aware presenters allow `deal.note` to have a different layout than `contact.note`. Both use the same qualified-key pattern with dot-notation and fallback chain.

## Goals

- Allow the same model to have different presenter layouts depending on the parent context
- Use the same qualified-key pattern as [Scoped Permissions](scoped_permissions.md) for consistency — dot-notation in `model:` field, double-underscore in filenames, fallback chain
- Maintain backward compatibility — existing presenters without context work unchanged
- Each contextual presenter is a full, standalone presenter — not a fragment or patch

## Non-Goals

- Nested routing implementation — the platform may or may not have nested routes; context-aware resolution works regardless of how the controller obtains the parent context
- Dynamic presenter personalization (user/role/system overrides stored in DB) — that is covered by [Dynamic Presenters](dynamic_presenters.md) and layers on top of this design
- Automatic generation of contextual presenters — developers explicitly create them when needed

## Relationship to Scoped Permissions

The [Scoped Permissions](scoped_permissions.md) design document introduces qualified permission keys:

```
"deal.custom_field_definition" → "custom_field_definition" → "_default"
```

Context-aware presenters follow **the same pattern exactly**:

| Aspect | Scoped Permissions | Context-Aware Presenters |
|--------|-------------------|--------------------------|
| Problem | Same model, different CRUD/field access per parent context | Same model, different layout/columns per parent context |
| Key format | `deal.note` | `deal.note` |
| Filename | `deal__note.yml` | `deal__notes.yml` |
| Fallback chain | qualified → unqualified → `_default` | qualified → unqualified |
| Controller API | `context: @parent_model_definition.name` | `context: @parent_model_definition.name` |

When a controller renders notes in the context of a deal, it passes the same `context: "deal"` string to both the permission resolver and the presenter resolver. The developer defines both side by side:

```
config/lcp_ruby/
  permissions/
    note.yml                  # default permissions
    deal__note.yml            # deal-context permissions
    contact__note.yml         # contact-context permissions
  presenters/
    notes.yml                 # default presenter
    deal__notes.yml           # deal-context presenter
    contact__notes.yml        # contact-context presenter
```

## Design Decisions

### Standalone presenters, not overrides

A contextual presenter is a **complete, self-contained presenter** — it has its own slug, its own index/show/form definitions, its own actions, its own search configuration. It is not a patch or diff applied to a default presenter.

Two approaches were considered:

| Approach | Pro | Con |
|----------|-----|-----|
| **Standalone** — each contextual presenter is complete | Simple mental model: open file, see exactly what renders. No merge logic. Consistent with view groups. | Duplication when contexts share 90% of layout |
| **Override** — contextual presenter patches the default | Less YAML duplication | Merge semantics are complex. Hard to reason about what the final result looks like. |

**Decision:** Standalone. The duplication tradeoff is acceptable because:
- Most models have 2–3 parent contexts, not 20
- The DSL with presenter inheritance addresses duplication for those who prefer DRY
- Explicit is better than implicit — opening a file shows exactly what the user sees

### Context is a free-form string

The context prefix in the qualified key is a free-form string. It does not need to be a model name, though it usually will be. This allows non-model contexts like `public.document` vs `internal.document`, or workflow-based contexts like `onboarding.task` vs `maintenance.task`.

### Controller provides context, not the URL

The presenter resolver receives `context:` as a parameter from the controller. The controller derives the context from whatever source is appropriate — URL (nested routing), polymorphic association field, query parameter, or explicit configuration. The resolver does not parse URLs or understand routing.

This decoupling means context-aware resolution works with or without nested routing.

### Slugs must be unique

Each contextual presenter has its own unique slug (`deal-notes`, `contact-notes`). The slug is an identifier used in URLs, view groups, and the rest of the system. Two presenters cannot share a slug, even if they serve the same model.

## Design

### Qualified Key Format

```
[context.]model_name
```

Examples:
- `note` — unscoped (default fallback)
- `deal.note` — scoped to deal context
- `contact.note` — scoped to contact context

### Filename Convention

The dot in the `model:` field is replaced with double underscore in the filename (dots are problematic in filenames on some systems). This is the same convention as [Scoped Permissions](scoped_permissions.md):

| `model:` value | Presenter file |
|-----------------|----------------|
| `note` | `presenters/notes.yml` |
| `deal.note` | `presenters/deal__notes.yml` |
| `contact.note` | `presenters/contact__notes.yml` |

### Resolution Logic

```
PresenterResolver.find("note", context: "deal")
  1. look for presenter with model: "deal.note"   → found? use it
  2. look for presenter with model: "note"         → found? use it (fallback)
  3. error: no presenter found for model "note"
```

The fallback is important — contextual presenters are opt-in. If only 2 out of 5 parent contexts need a custom layout, the other 3 fall back to the default presenter. No need to define presenters for every possible context.

### Full Configuration Examples

#### Default presenter (fallback for all contexts without a specific presenter)

```yaml
# presenters/notes.yml
presenter:
  name: notes
  model: note
  label: "Notes"
  slug: notes
  icon: sticky-note

  index:
    default_sort: { field: created_at, direction: desc }
    per_page: 25
    table_columns:
      - { field: title, width: "30%", link_to: show, sortable: true }
      - { field: content, width: "50%" }
      - { field: created_at, width: "20%", sortable: true }

  show:
    layout:
      - section: "Note"
        fields:
          - { field: title, renderer: heading }
          - { field: content }
          - { field: created_at }

  form:
    sections:
      - title: "Note"
        fields:
          - { field: title, placeholder: "Note title...", autofocus: true }
          - { field: content, input_type: rich_text }

  actions:
    collection:
      - { name: create, type: built_in, label: "New Note", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

#### Deal-context presenter

When notes are viewed under a deal (`/deals/123/notes`), this presenter is selected. It emphasizes deal-relevant fields: `note_type` with badge renderer, `next_action`, a conditional "Follow-up" section for meeting notes, and meeting-specific search filters.

```yaml
# presenters/deal__notes.yml
presenter:
  name: deal_notes
  model: deal.note
  label: "Deal Notes"
  slug: deal-notes
  icon: sticky-note

  index:
    default_sort: { field: created_at, direction: desc }
    per_page: 10
    table_columns:
      - { field: title, width: "25%", link_to: show, sortable: true }
      - { field: note_type, width: "15%", renderer: badge, sortable: true }
      - { field: next_action, width: "25%" }
      - { field: created_at, width: "15%", sortable: true }

  show:
    layout:
      - section: "Deal Note"
        columns: 2
        fields:
          - { field: title, renderer: heading }
          - { field: note_type, renderer: badge }
          - { field: content }
          - { field: next_action }
      - section: "Follow-up"
        visible_when: { field: note_type, operator: eq, value: meeting }
        fields:
          - { field: follow_up_date }
          - { field: assigned_to_id }

  form:
    sections:
      - title: "Deal Note"
        columns: 2
        fields:
          - { field: title, placeholder: "Note title...", autofocus: true }
          - { field: note_type, input_type: select }
          - { field: content, input_type: rich_text }
          - field: next_action
            placeholder: "Next step..."
            visible_when: { field: note_type, operator: not_eq, value: info }

  search:
    enabled: true
    searchable_fields: [title, content]
    predefined_filters:
      - { name: all, label: "All", default: true }
      - { name: meetings, label: "Meetings", scope: meetings_only }

  actions:
    collection:
      - { name: create, type: built_in, label: "Add Note", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

#### Contact-context presenter

When notes are viewed under a contact (`/contacts/456/notes`), this presenter is selected. It emphasizes contact-relevant fields: `priority` with badge renderer, `assigned_to` with association select, and sorts by priority instead of date.

```yaml
# presenters/contact__notes.yml
presenter:
  name: contact_notes
  model: contact.note
  label: "Contact Notes"
  slug: contact-notes
  icon: sticky-note

  index:
    default_sort: { field: priority, direction: desc }
    table_columns:
      - { field: title, width: "30%", link_to: show, sortable: true }
      - { field: priority, width: "15%", renderer: badge, sortable: true }
      - { field: assigned_to_id, width: "20%", label: "Assigned To" }
      - { field: created_at, width: "15%", sortable: true }

  show:
    layout:
      - section: "Contact Note"
        columns: 2
        fields:
          - { field: title, renderer: heading }
          - { field: priority, renderer: badge }
          - { field: content }
          - { field: assigned_to_id }

  form:
    sections:
      - title: "Contact Note"
        columns: 2
        fields:
          - { field: title, placeholder: "Note title...", autofocus: true }
          - { field: priority, input_type: select }
          - { field: content, input_type: rich_text }
          - field: assigned_to_id
            input_type: association_select

  actions:
    collection:
      - { name: create, type: built_in, label: "Add Note", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

#### Another example: Attachments

The same pattern works for any polymorphic model. Attachments in a contract context show version tracking and legal fields. Attachments in a deal context show categorization fields.

```yaml
# presenters/contract__attachments.yml
presenter:
  name: contract_attachments
  model: contract.attachment
  label: "Contract Documents"
  slug: contract-attachments
  icon: file-text

  index:
    default_sort: { field: version, direction: desc }
    table_columns:
      - { field: filename, width: "25%", link_to: show, sortable: true }
      - { field: version, width: "10%", renderer: badge, sortable: true }
      - { field: signed, width: "10%", renderer: boolean_icon }
      - { field: valid_until, width: "15%", sortable: true }
      - { field: uploaded_by_id, width: "15%", label: "Uploaded By" }
      - { field: created_at, width: "15%", sortable: true }

  show:
    layout:
      - section: "Document Details"
        columns: 2
        fields:
          - { field: filename, renderer: heading }
          - { field: version, renderer: badge }
          - { field: signed, renderer: boolean_icon }
          - { field: valid_until }
          - { field: uploaded_by_id }
      - section: "Legal"
        visible_when: { field: signed, operator: eq, value: true }
        fields:
          - { field: signed_by }
          - { field: signed_at }

# presenters/deal__attachments.yml
presenter:
  name: deal_attachments
  model: deal.attachment
  label: "Deal Files"
  slug: deal-attachments
  icon: paperclip

  index:
    default_sort: { field: created_at, direction: desc }
    table_columns:
      - { field: filename, width: "30%", link_to: show, sortable: true }
      - { field: category, width: "15%", renderer: badge, sortable: true }
      - { field: uploaded_by_id, width: "20%", label: "Uploaded By" }
      - { field: created_at, width: "15%", sortable: true }
```

### DSL with Presenter Inheritance

For cases where contextual presenters share most of their configuration with the default, the DSL supports inheritance to reduce duplication:

```ruby
# Default presenter
LcpRuby.define_presenter :notes do
  model "note"
  slug "notes"
  label "Notes"
  icon "sticky-note"

  index do
    default_sort field: :created_at, direction: :desc
    per_page 25
    table_column :title, width: "30%", link_to: :show, sortable: true
    table_column :content, width: "50%"
    table_column :created_at, width: "20%", sortable: true
  end

  # ... show, form, actions ...
end

# Deal-context — inherits everything, overrides only what differs
LcpRuby.define_presenter :deal_notes, parent: :notes do
  model "deal.note"
  slug "deal-notes"
  label "Deal Notes"

  index do
    per_page 10
    table_column :title, width: "25%", link_to: :show, sortable: true
    table_column :note_type, width: "15%", renderer: :badge, sortable: true
    table_column :next_action, width: "25%"
    table_column :created_at, width: "15%", sortable: true
  end

  # show and form sections are inherited from :notes unless overridden
end
```

The DSL inheritance is a convenience for authors. The resulting PresenterDefinition is still a complete, standalone object — the resolver does not need to know about inheritance at runtime.

### Permissions and Presenters Share Context

When a controller renders a polymorphic resource in a parent context, it passes the same context string to both resolvers:

```
Request: /deals/123/notes

Controller:
  context = "deal"

  # Presenter resolution
  presenter = PresenterResolver.find("note", context: "deal")
  # tries "deal.note" → deal__notes.yml ✓

  # Permission resolution
  permissions = SourceResolver.for("note", context: "deal")
  # tries "deal.note" → deal__note.yml ✓
```

This ensures that the layout and access rules are always aligned — a contextual presenter shows fields that the contextual permission allows.

### View Groups Integration

View groups serve two purposes: **navigation** (which entries appear in the menu) and **view switching** (tabs to switch between presenters for the same model). Context-aware resolution interacts with both.

#### Context-aware view group resolution (qualified `model:` key)

View groups gain the same qualified-key resolution as presenters and permissions. The `model:` field in a view group can contain a context prefix:

```yaml
# views/deal_notes.yml — explicit view group for deal context
view_group:
  name: deal_notes
  model: deal.note          # qualified key
  primary: deal_notes
  navigation: false          # sub-resource, not in top-level menu
  views:
    - presenter: deal_notes
      label: "Detailed"
    - presenter: deal_notes_compact
      label: "Compact"
```

The view group resolver uses the same fallback chain as presenters:

```
ViewGroupResolver.find("note", context: "deal")
  1. look for view group with model: "deal.note"   → found? use it
  2. look for view group with model: "note"         → found? use it (fallback)
```

This means:
- If an explicit `deal.note` view group exists → use it (with its own views and navigation config)
- If not → fall back to the default `note` view group

#### Auto-creation excludes contextual presenters

The existing auto-creation logic groups presenters by their `model:` value. Without any change, contextual presenters would create unwanted auto-generated view groups:

| Presenter | `model:` | Auto-created view group | Problem |
|-----------|----------|------------------------|---------|
| `notes` | `note` | `note_auto` ✓ | Correct — default presenter in navigation |
| `deal_notes` | `deal.note` | `deal.note_auto` ✗ | Wrong — sub-resource should not appear in top-level menu |
| `contact_notes` | `contact.note` | `contact.note_auto` ✗ | Wrong — same problem |

**Decision:** Auto-creation skips presenters whose `model:` contains a dot (contextual presenters). Only non-contextual presenters participate in auto-creation. This is a single condition: `next if model_name.include?(".")`.

After this exclusion:
- `note` has 1 non-contextual presenter → auto-create `note_auto` ✓
- `deal.note` and `contact.note` are skipped — no auto-created view groups ✓

#### Fallback to default view group

When no explicit view group exists for a context, the resolver falls back to the default (non-contextual) view group. This fallback provides the essential metadata that the platform needs:

| Feature | Fallback to default view group | Works? |
|---------|-------------------------------|--------|
| **Navigation** | Contextual presenters are sub-resources, not top-level menu items. The default view group handles the menu entry for the base model. | ✓ |
| **Public access check** | Inherited from the default view group's `public:` flag. | ✓ |
| **Breadcrumbs** | Inherited from the default view group's `breadcrumb:` config. | ✓ |

This means **most contextual presenters do not need an explicit view group** — the fallback to the default view group provides everything they need.

#### View switcher behavior

The view switcher (tabs for switching between presenters in a group) has a nuance with the fallback:

**With explicit contextual view group** — the switcher shows the context-specific views:

```yaml
# views/deal_notes.yml
view_group:
  model: deal.note
  views:
    - presenter: deal_notes           # ← "Detailed" tab
    - presenter: deal_notes_compact   # ← "Compact" tab
```

The user sees two tabs, both deal-context presenters. Switching between them stays within the deal context. This is the expected behavior.

**Without explicit contextual view group (fallback)** — the default view group is found, but it contains non-contextual presenters. Since the default view group typically has a single presenter (auto-created), the view switcher simply does not appear (single view = no tabs). This is the correct behavior for the common case — a contextual presenter used alone without variants.

**When a view switcher is needed in context** — create an explicit view group with `model: deal.note` listing the contextual presenter variants. The fallback is a convenience for the simple case; explicit view groups handle the multi-view case.

#### Summary: three scenarios

| Scenario | View group needed? | View switcher? |
|----------|-------------------|----------------|
| Single contextual presenter (`deal_notes` only) | No — fallback to `note_auto` | No switcher (single view) |
| Multiple contextual variants (`deal_notes` + `deal_notes_compact`) | Yes — explicit `model: deal.note` | Switcher between deal-context variants |
| Context without specific presenter (fallback to default) | No — uses `note_auto` directly | Whatever the default group provides |

### Relationship to Dynamic Presenters

[Dynamic Presenters](dynamic_presenters.md) add a user/role/system personalization layer stored in DB. Context-aware resolution and dynamic presenters are independent and compose naturally:

```
URL: /deals/123/notes
        ↓
Context-aware resolution → base presenter: deal__notes.yml (slug: "deal-notes")
        ↓
Dynamic presenter lookup → DB override for slug "deal-notes", user/role/system?
        ↓
If override found → merge (dynamic config applied to base)
If no override   → use base as-is
        ↓
LayoutBuilder → views (unchanged)
```

Each layer solves a different problem:
- **Context-aware resolution:** which base presenter? (developer-defined, per parent context)
- **Dynamic presenters:** what personalization on top? (user/admin-defined, per user/role)
- **View groups:** which variant within the group? (user-selected, manual switch)

All three can be active simultaneously without interference.

### Controller Interaction

The controller provides context to the resolver. How it obtains the context depends on the routing strategy:

**With nested routing** (if the platform implements it):

```
Route: /:parent_slug/:parent_id/:child_slug
URL:   /deals/123/notes

Controller derives: context = "deal" (from :parent_slug)
```

**With polymorphic field** (no nested routing needed):

```
Route: /:lcp_slug
URL:   /notes?parent_type=deal&parent_id=123

Controller derives: context = params[:parent_type]
```

**With explicit configuration** (for non-standard cases):

```yaml
# The controller or route config specifies the context
context: "internal"  # e.g., internal vs. public document presenter
```

Context-aware resolution does not depend on any specific routing strategy. It only requires that the controller can provide a context string.

## Implementation Phases

### Phase 1: Resolver with context parameter

- Extend the presenter resolver to accept an optional `context:` parameter
- Implement the fallback chain: `context.model` → `model`
- Index presenter definitions by their full `model:` key (including dot-notation)
- Validate that qualified keys follow the expected format

**Value:** The resolution mechanism works. Developers can create contextual presenters and controllers can select them.

### Phase 2: Validation

- Validate that the model part (after the last dot) of a qualified key references a known model
- Warn (not error) if the context prefix does not match any known model name — it might be intentional (e.g., `public.document`)
- Validate that contextual presenters have unique slugs

**Value:** Catches typos and misconfigurations at boot time.

### Phase 3: DSL inheritance support

- Add `parent:` option to the presenter DSL
- Parent presenter provides defaults; child overrides specific sections
- The resulting PresenterDefinition is complete — no runtime inheritance chain

**Value:** Reduces YAML/DSL duplication for contextual presenters that differ only slightly from the default.

## Related Documents

- **[Scoped Permissions](scoped_permissions.md):** The permission counterpart — same qualified-key pattern, same fallback chain, same filename convention. Both designs should be implemented together or in close sequence.
- **[Dynamic Presenters](dynamic_presenters.md):** User/role/system personalization layer that applies on top of whichever presenter context-aware resolution selects.
- **[View Groups](../reference/view-groups.md):** Manual presenter switching within a group. Coexists with automatic context-based selection.
- **[Presenters Reference](../reference/presenters.md):** Full YAML presenter format used by both default and contextual presenters.

## Open Questions

1. **Nested context fallback:** For deeply nested contexts like `sales.deal.note`, should the resolver try progressively shorter prefixes (`sales.deal.note` → `deal.note` → `note`)? The [Scoped Permissions](scoped_permissions.md) design includes this for permissions. Recommendation: yes, for consistency — use the same `build_candidates` logic.

2. **Presenter label in context:** The contextual presenter has its own `label:` (e.g., "Deal Notes"). Should the platform automatically compose this from the parent and model names if not explicitly set? Recommendation: no — explicit labels are clearer and more flexible. Auto-generation can produce awkward names.

3. **Multiple contexts per presenter:** Can a single presenter serve multiple contexts (e.g., both `deal.note` and `project.note` use the same layout)? The current design requires one presenter per context. An alternative is a `contexts:` list in the presenter. Recommendation: defer — if two contexts need the same layout, they can both fall back to the default presenter. If they need a shared-but-not-default layout, a future `contexts: [deal, project]` option can be added without breaking changes.
