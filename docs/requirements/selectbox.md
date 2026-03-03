# Selectbox Field — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Basic Selectors and Conditional Selectors

- [x] Value selection for foreign_key via inline vs. ajax — `association_select` input type with Tom Select; inline (default) and AJAX remote search (`search: true` with `search_fields`, `per_page`, `min_query_length`)
- [x] Statically pre-filtered selection — `scope` (named scope on target model) and `filter` (hash of field-value pairs) options on `association_select`
- [x] Selection dependent on another field (selectbox → selectbox, radio → select, checkbox → select) — `depends_on` with `field` + `foreign_key`, multi-level cascading (A→B→C), reverse cascade (ancestor resolution)
- [x] Selection dependent on role — `scope_by_role` option with per-role scope selection (e.g., admin: all, editor: active_companies)

## Data Source and Loading

- [x] Lazy loading / virtual scroll for large datasets (thousands of items) — Tom Select with `search: true`, server-side pagination (`page`, `per_page`), `max_options` limit
- [x] Full-text search within items (with diacritics, fuzzy match) — Tom Select client-side sifter (local mode) + server-side LIKE search across `search_fields` (remote mode); no fuzzy match
- [~] Ability to combine static codelist + dynamic query (enum table vs. API endpoint) — enum fields (static) and association_select (dynamic) are separate input types, not combined in one widget
- [ ] Item caching (how long a loaded list remains valid)

## Display and UX

- [x] Multi-select (selecting multiple values) — `multi_select` input type with Tom Select `remove_button` plugin, `min`/`max` constraints
- [x] Grouped options (optgroup) — `group_by: field_name` groups options by model field into `<optgroup>` elements
- [~] Custom item rendering (icon, color, description, badge) — `label_method` for custom display field; no full HTML templates for option rendering
- [x] Placeholder / default value from metadata — `include_blank` (true/string/false) + `default` on field definition
- [x] "Create new item" directly from selectbox (inline create) — `allow_inline_create: true`, opens modal form, created record auto-selected
- [x] Hierarchical selection (tree, e.g., category → subcategory) — `tree_select` input type with collapsible tree dropdown, `max_depth`, expand/collapse

## Validation and Behavior

- [x] Required / optional driven from metadata — `presence` validation in model definition
- [x] Disabled / readonly for individual items (not the entire select) — `disabled_values` (ID list) and `disabled_scope` (named scope) for non-selectable options
- [x] Maximum / minimum selected values (for multi-select) — `min`/`max` on `multi_select` input type
- [x] Validation against current state (item was deleted or deactivated in the meantime) — `legacy_scope` resolves archived/soft-deleted records, displays as disabled "(Archived)" option on edit

## Dependencies and Cascades

- [x] Chained dependencies (A → B → C), not just A → B — multi-level cascading selects via nested `depends_on`, tested with 3-level chains
- [x] Dependent field reset on parent change (strategy: clear vs. keep if still valid) — `reset_strategy: "clear"` (default) or `reset_strategy: "keep_if_valid"`
- [ ] Cross-form dependencies (value from another form / context)

## Permissions and Visibility

- [~] Visibility of individual items by role (not just the entire select, but specific options) — `scope_by_role` filters entire option list per role, not individual items
- [x] Audit trail — who changed the value and when — auditing module tracks all field changes including association values with old/new diffs
- [x] Soft-delete of codelist items (historical records display old value, new records don't offer it) — `legacy_scope` with "(Archived)" label on edit forms, active scope excludes archived from new records

## Other

- [x] Item sorting (alphabetical, custom order, by usage frequency) — `sort` option with field/direction hash (e.g., `sort: { name: asc }`)
- [ ] Localization of item labels (multilingual codelist)
- [ ] Support for copying / importing values (bulk operations)

---

## Key Points

- **Dependent selectors** — cascading selectboxes (country → region → city) are among the most common requirements in enterprise forms. Without this, users have to scroll through hundreds of irrelevant options.
- **Lazy loading for large datasets** — rendering thousands of `<option>` elements freezes the browser. For large codelists, ajax/virtual scroll is essential.
- **Soft-delete in codelists** — historical records must still display the value that was valid at the time. Deleting a codelist item must not break existing data.
- **Inline create** — power users expect to be able to add a new option directly from the selectbox without navigating away from the form.
