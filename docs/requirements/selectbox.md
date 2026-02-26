# Selectbox Field — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Basic Selectors and Conditional Selectors

- [~] Value selection for foreign_key via inline vs. ajax — `association_select` input type renders inline `<select>`, no ajax support
- [ ] Statically pre-filtered selection
- [ ] Selection dependent on another field (selectbox → selectbox, radio → select, checkbox → select)
- [~] Selection dependent on role — field-level permissions control visibility, but not individual option filtering

## Data Source and Loading

- [ ] Lazy loading / virtual scroll for large datasets (thousands of items)
- [ ] Full-text search within items (with diacritics, fuzzy match)
- [ ] Ability to combine static codelist + dynamic query (enum table vs. API endpoint)
- [ ] Item caching (how long a loaded list remains valid)

## Display and UX

- [ ] Multi-select (selecting multiple values)
- [ ] Grouped options (optgroup) — grouping items into categories
- [ ] Custom item rendering (icon, color, description, badge)
- [~] Placeholder / default value from metadata — `default` on field definition, `placeholder` on presenter field
- [ ] "Create new item" directly from selectbox (inline create)
- [ ] Hierarchical selection (tree, e.g., category → subcategory)

## Validation and Behavior

- [x] Required / optional driven from metadata — `presence` validation in model definition
- [ ] Disabled / readonly for individual items (not the entire select)
- [ ] Maximum / minimum selected values (for multi-select)
- [ ] Validation against current state (item was deleted or deactivated in the meantime)

## Dependencies and Cascades

- [ ] Chained dependencies (A → B → C), not just A → B
- [ ] Dependent field reset on parent change (strategy: clear vs. keep if still valid)
- [ ] Cross-form dependencies (value from another form / context)

## Permissions and Visibility

- [ ] Visibility of individual items by role (not just the entire select, but specific options)
- [ ] Audit trail — who changed the value and when
- [ ] Soft-delete of codelist items (historical records display old value, new records don't offer it)

## Other

- [ ] Item sorting (alphabetical, custom order, by usage frequency)
- [ ] Localization of item labels (multilingual codelist)
- [ ] Support for copying / importing values (bulk operations)

---

## Key Points

- **Dependent selectors** — cascading selectboxes (country → region → city) are among the most common requirements in enterprise forms. Without this, users have to scroll through hundreds of irrelevant options.
- **Lazy loading for large datasets** — rendering thousands of `<option>` elements freezes the browser. For large codelists, ajax/virtual scroll is essential.
- **Soft-delete in codelists** — historical records must still display the value that was valid at the time. Deleting a codelist item must not break existing data.
- **Inline create** — power users expect to be able to add a new option directly from the selectbox without navigating away from the form.
