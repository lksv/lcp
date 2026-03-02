# Feature Specification: Deep Filter Enhancements

**Status:** Implemented
**Date:** 2026-03-02
**Related:** [Advanced Search & Filter Builder](advanced_search.md)

This spec covers two related enhancements to the advanced filter builder:
1. **Recursive association field picker** — drill-down UI for selecting fields through associations
2. **Recursive condition nesting** — full AND/OR tree support instead of the current two-level model

Both are motivated by the same need: supporting complex data models and complex queries in a production information system.

---

## Part 1: Recursive Association Field Picker

### Problem / Motivation

The advanced filter builder currently presents all filterable fields in a flat `<select>` dropdown organized by optgroups (direct fields, then one group per association with breadcrumb-style labels like "Company > Country > Name"). This works acceptably when the number of filterable fields is small and association depth is limited to 1–2 levels.

However, in real-world information systems with rich data models, this approach breaks down:

- **Information overload.** A model with 15 direct fields and 5 associations (each with 10+ fields) produces a dropdown with 60+ items. Users scroll through a long flat list without context for what they're looking at.
- **Deep associations are impractical.** Filtering by `deal.company.country.region.name` requires the configurator to explicitly list every deep path in `filterable_fields`. With 3+ levels of associations, the number of possible paths grows combinatorially. Auto-detection at depth 3+ produces overwhelming metadata.
- **No discovery.** Users cannot explore the data model. They see a fixed list of pre-computed paths and have no way to discover that, say, the `company` association has a `country` association which has a `region` association. The mental model of the data structure is invisible.
- **Large metadata payloads.** All association field metadata is pre-computed server-side and embedded in the page HTML as JSON. Deep auto-detection with many associations produces large payloads that slow down page load without benefiting most users (who filter by 2–3 common fields).

Systems like SAMO solve this with a cascading/drill-down picker: the user selects an association, sees its fields and sub-associations, and can drill deeper — building the field path interactively rather than selecting it from a flat list.

### User Scenarios

**Scenario 1: Simple field selection (no change from current behavior)**
A user filtering deals by `stage` or `value` sees these as direct fields and selects them in one click, exactly as today.

**Scenario 2: One-level association drill-down**
A user wants to filter deals by company name. They click the field picker, see "Company" listed as an association (visually distinct from direct fields). They click "Company" and the picker shows Company's fields (name, industry, website, etc.) plus Company's own associations (country, contacts). They select "name" → the filter row shows "Company > Name" as the selected field.

**Scenario 3: Multi-level drill-down**
A user wants to filter deals by the country of the company. Starting from the field picker: click "Company" → see Company's fields and associations → click "Country" → see Country's fields (name, code, region) → select "name" → filter row shows "Company > Country > Name".

**Scenario 4: Back navigation**
While drilling into Company > Country, the user realizes they wanted Company > Industry instead. They click a "back" breadcrumb or button to return to the Company level and select a different field.

**Scenario 5: Direct field search (shortcut)**
A power user knows they want `company.country.name`. Instead of drilling down, they type "country" into a search input within the picker. The picker shows matching fields across all levels: "Company > Country > Name", "Company > Country > Code". They select directly.

**Scenario 6: Filtering through has_many**
A user on the Companies index wants to find "companies that have at least one deal with stage=won". They drill into the "Deals" association (has_many), select "stage", set operator to "eq", value to "won". Ransack generates an `EXISTS` subquery. The result shows companies matching the condition — not individual deals.

### Configuration & Behavior

The recursive picker uses the existing `advanced_filter` configuration with one new key: `filterable_fields_except`.

**Three configuration modes:**

**Mode 1: Auto-detect (default).** No `filterable_fields` set. The picker shows all readable fields on the current model and all traversable associations recursively, up to `max_association_depth`. Fields are filtered by the standard exclusion rules (system fields, attachments, computed fields) and by permissions.

```yaml
search:
  advanced_filter:
    enabled: true
    max_association_depth: 3
    # no filterable_fields → auto-detect everything
```

```ruby
advanced_filter do
  enabled true
  max_association_depth 3
end
```

**Mode 2: Auto-detect with exclusions.** `filterable_fields_except` removes specific fields or entire association subtrees from the auto-detected set. Useful when the model is mostly filterable but has a few sensitive or irrelevant parts.

```yaml
search:
  advanced_filter:
    enabled: true
    max_association_depth: 3
    filterable_fields_except:
      - internal_notes            # exclude a direct field
      - audit_log                 # exclude entire association subtree
      - company.tax_id            # exclude a specific association field
```

```ruby
advanced_filter do
  enabled true
  max_association_depth 3
  filterable_fields_except :internal_notes, :audit_log, "company.tax_id"
end
```

Exclusion matching rules:
- **Direct field name** (`internal_notes`) — excludes that field from the root model.
- **Association name without dot** (`audit_log`) — excludes the entire association subtree. The association does not appear in the picker and none of its fields or sub-associations are reachable.
- **Dot-path to a field** (`company.tax_id`) — excludes that specific field on the associated model. The association itself remains traversable; only the named field is hidden.
- **Dot-path to an association** (`company.audit_log`) — excludes a sub-association within an association. Company remains traversable, but its audit_log sub-association is hidden.

**Mode 3: Explicit allowlist.** `filterable_fields` lists exactly which fields are available. Only the listed fields and their ancestor association paths appear in the picker. This is the current behavior — most restrictive, most predictable.

```yaml
search:
  advanced_filter:
    enabled: true
    max_association_depth: 3
    filterable_fields:
      - name
      - stage
      - company.name
      - company.country.name
```

```ruby
advanced_filter do
  enabled true
  max_association_depth 3
  filterable_fields :name, :stage, "company.name", "company.country.name"
end
```

**Precedence:** If both `filterable_fields` and `filterable_fields_except` are set, it is a configuration error (raises `MetadataError` at validation time). They are mutually exclusive — use one or the other.

**Behavior rules (all modes):**

- **Permission enforcement**: At each level, the picker only shows fields where `field_readable?` is true. For belongs_to associations, the FK field must be readable. Permissions always apply on top of the configured field set — `filterable_fields` can never grant access to fields the user cannot read.
- **Association traversal**: Both `has_many` and `belongs_to` associations are traversable. `has_many` fields generate `EXISTS` subqueries in Ransack (e.g., "companies that have at least one deal with stage=won"). Polymorphic `belongs_to` associations are excluded.
- **Flat fallback**: When the total number of filterable fields (including association fields) is below a threshold (e.g., 20), the picker may default to the current flat select with optgroups. The recursive picker activates when the field count is high enough to justify the extra interaction.

**Edge cases:**

- **Circular associations**: A model that has_many of itself (e.g., `parent_id` self-referential). The picker must detect cycles and not drill into the same model twice on the same path.
- **Inverse associations**: When drilling from Deal into Company, the picker must not show "Deals" as a sub-association of Company. Showing the inverse association would create confusing circular paths (Deal > Company > Deals > Company). The picker excludes the inverse of the association that led to the current level.
- **Polymorphic associations**: Already excluded by the current `traversable?` check. The picker skips them.
- **Virtual/non-LCP associations**: Already excluded. Only `lcp_model?` associations are traversable.
- **Empty association level**: If an association's target model has no readable/filterable fields and no further traversable associations, the association should not appear in the picker.

### General Implementation Approach

The feature splits into two parts: server-side metadata generation and a cascading UI component.

**Server-side: pre-computed metadata.** The `FilterMetadataBuilder` pre-computes all field metadata (including association fields) up to `max_association_depth` and sends it as a flat list with dot-path field names. Each field carries its type, available operators, enum values, and a `group` label for UI grouping (e.g., "Company > Country"). The initial design considered lazy-loading per association level, but the pre-computation approach was chosen for simplicity — it avoids extra AJAX requests and works well when `max_association_depth` is moderate (default: 1). The `filter_fields` endpoint is available for on-demand metadata refresh if needed.

The metadata response shape (embedded as a `data-lcp-filter-metadata` attribute or returned from `GET /:lcp_slug/filter_fields`):

```json
{
  "fields": [
    {
      "name": "title",
      "label": "Title",
      "type": "string",
      "group": null,
      "operators": ["eq", "not_eq", "cont", "start", "end", "present", "blank"]
    },
    {
      "name": "company.name",
      "label": "Name",
      "type": "string",
      "group": "Company",
      "operators": ["eq", "not_eq", "cont", "start", "end", "present", "blank"]
    },
    {
      "name": "company.country.name",
      "label": "Name",
      "type": "string",
      "group": "Company > Country",
      "operators": ["eq", "not_eq", "cont", "start", "end", "present", "blank"]
    }
  ],
  "operator_labels": { "eq": "equals", "cont": "contains", "...": "..." },
  "no_value_operators": ["present", "blank", "null", "not_null", "true", "false", "..."],
  "multi_value_operators": ["in", "not_in"],
  "range_operators": ["between"],
  "parameterized_operators": ["last_n_days"],
  "presets": [],
  "config": { "max_conditions": 10, "max_nesting_depth": 2, "..." : "..." }
}
```

Each field carries its type, available operators, and enum values (if applicable). The `group` string is used by the JS to build the cascading picker tree — fields with the same group prefix belong to the same association level.

**Filter restoration.** Because all metadata is pre-computed and embedded in the page, filter restoration requires no additional requests. The JS reads existing URL filter params and has full field metadata available to display the correct labels (e.g., "Company > Country > Name") immediately.

**Client-side: cascading picker UI.** The JavaScript builds a tree from the flat dot-path metadata. The flat `<select>` is replaced with cascading `<select>` elements. Selecting an association in the first select reveals a second select with that association's fields and sub-associations, and so on. A breadcrumb trail shows the current path. Selecting a field populates the filter row with the full dot-path.

**Integration.** The existing `FilterMetadataBuilder` logic is extended with recursive `traverse_associations`. The `encodeCondition` JS function already handles dot-paths. Ransack natively supports multi-level association predicates. No changes to the query execution pipeline.

### Decisions

1. **Dot-path convention for field paths**: Use dot-delimited paths (`company.name`, `company.country.name`) rather than Ransack's underscore convention (`company_name`, `company_country_name`). Underscore paths create ambiguity — `company_name` could be a field called "company_name" or association "company" > field "name". Dot-paths are unambiguous and already used throughout the advanced filter implementation. Conversion to Ransack underscore format happens at the URL param building stage only.

2. **Pre-computation over lazy loading**: The initial design proposed lazy-loading metadata per association level. The implemented approach pre-computes all field metadata up to `max_association_depth` server-side and sends it as a flat list with dot-path field names. The JavaScript builds the cascading tree client-side from this flat data. This is simpler, avoids extra AJAX requests, and works well when `max_association_depth` is moderate (1–3). The default `max_association_depth` of 1 keeps the metadata payload small. For models with deep association graphs, increasing the depth increases the initial payload proportionally.

3. **Inverse association exclusion**: When the user drills from model A into association B, the picker hides the inverse association back to A on model B. This prevents circular navigation paths and reduces clutter at each level. Additionally, FK fields pointing back to the parent model are excluded from association fields.

4. **Auto-detect as default, exclusion over enumeration**: The default mode (no `filterable_fields`) auto-detects all fields recursively. `filterable_fields_except` provides a blocklist for the common case of "everything except these few things". The explicit `filterable_fields` allowlist remains for cases requiring precise control. The two are mutually exclusive — combining them is a configuration error.

5. **Both has_many and belongs_to are traversable**: Unlike the current auto-detect (which only traverses belongs_to), the recursive picker traverses both directions. `has_many` traversal produces `EXISTS` subqueries via Ransack, enabling queries like "companies with at least one deal in stage=won". Polymorphic `belongs_to` remains excluded.

6. **Cycle prevention via visited set**: The traversal maintains a set of already-visited model names in the current path to prevent infinite recursion from circular associations (e.g., self-referential models).

---

## Part 2: Recursive Condition Nesting (AND/OR Tree)

### Problem / Motivation

The current filter data model is a fixed two-level structure:

```
Root (implicit AND)
├── condition
├── condition
└── OR group
    ├── condition
    └── condition
```

This means:
- Top-level conditions are always combined with AND
- OR groups can only contain flat conditions (no nested AND inside OR)
- The structure cannot represent `(A AND B) OR (C AND D)`

**Current behavior with complex QL expressions:**

| QL input | Semantic meaning | Actual result |
|----------|-----------------|---------------|
| `a = 1 and b = 2` | a AND b | Correct |
| `a = 1 or b = 2` | a OR b | Correct |
| `a = 1 and (b = 2 or c = 3)` | a AND (b OR c) | Correct |
| `(a = 1 or b = 2) and (c = 3 or d = 4)` | (a OR b) AND (c OR d) | Correct (2 OR groups) |
| `(a = 1 and b = 2) or (c = 3 and d = 4)` | (a AND b) OR (c AND d) | **Wrong**: flattened to `a OR b OR c OR d` |
| `a = 1 or (b = 2 and c = 3)` | a OR (b AND c) | **Wrong**: flattened to `a OR b OR c` |

The `normalize_tree` function in `QueryLanguageParser` flattens all expressions into the two-level model. When the top-level combinator is OR, `extract_conditions` recursively pulls out all leaf conditions and puts them in a single OR group, losing AND sub-structure.

This affects both the visual filter builder AND the QL mode — the flattening happens at parse time, before URL params are built.

### User Scenarios

**Scenario 1: Current (two-level) queries — no change**
`status = 'active' and (priority = 'high' or priority = 'critical')` — works today and continues to work.

**Scenario 2: OR of AND groups**
A user wants: "show me deals that are (stage=qualified AND value>100K) OR (stage=negotiation AND value>50K)". Today this query silently produces wrong results. With recursive nesting, it works correctly.

**Scenario 3: Complex nested conditions**
A user wants: "active contacts at (tech companies in Prague) OR (finance companies in London)". This requires: `active = true AND ((company.industry = 'tech' AND company.city.name = 'Prague') OR (company.industry = 'finance' AND company.city.name = 'London'))`.

**Scenario 4: QL ↔ Visual round-trip**
A user types a complex QL expression, switches to visual mode, sees the correct nested structure, modifies one condition, switches back to QL — the expression is correct.

### Configuration & Behavior

```yaml
search:
  advanced_filter:
    enabled: true
    allow_or_groups: true
    max_nesting_depth: 3     # NEW: max depth of AND/OR nesting (default: 2 = current behavior)
```

```ruby
search do
  advanced_filter do
    enabled true
    allow_or_groups true
    max_nesting_depth 3
  end
end
```

- `max_nesting_depth: 1` — flat AND only (no OR groups)
- `max_nesting_depth: 2` — current behavior: AND with OR groups (default)
- `max_nesting_depth: 3+` — full recursive nesting

**Behavior rules:**

- The QL parser preserves the full tree structure up to `max_nesting_depth`. Beyond the limit, it flattens (current behavior).
- The visual builder shows nested groups indented with visual nesting indicators.
- Each group shows its combinator (AND/OR) and contains conditions or sub-groups.
- The QL serializer outputs parentheses for nested groups.
- URL parameters use Ransack's native grouping format: `g[0][m]=or&g[0][g][0][m]=and&g[0][g][0][field_eq]=value`.

**Edge cases:**

- **Max nesting exceeded in QL**: The parser raises a `ParseError` with a message like "Nesting depth exceeds maximum of N" rather than silently flattening.
- **Empty groups**: Groups with no conditions are stripped during normalization.
- **Single-condition groups**: A group with one condition is unwrapped (the condition is pulled up to the parent level).

### General Implementation Approach

**Data model change.** Replace the fixed two-level structure with a recursive tree:

```
Current:  { combinator, conditions[], groups[] }
Proposed: { combinator, children[] }
  where each child is either:
    - a condition: { field, operator, value }
    - a group:     { combinator, children[] }
```

**Parser change.** `normalize_tree` currently flattens to two levels. Instead, it preserves the parsed AST structure, only simplifying redundancies (unwrapping single-child groups, merging same-combinator parent/child). The `max_nesting_depth` config controls how deep the tree can be.

**FilterParamBuilder change.** Currently builds flat Ransack params with one level of `g[...]` grouping. Needs to support recursive `g[0][g][0][...]` nesting. Ransack already supports this natively — the builder just needs to emit nested grouping keys.

**Serializer change.** `QueryLanguageSerializer` currently reads `conditions` + `groups`. Needs to walk the recursive tree and emit parentheses around sub-groups.

**Visual builder (JS) change.** The biggest change. Currently renders a flat list of conditions with OR group sections. Needs to render a tree with indented, visually nested groups. Each group has a combinator toggle (AND/OR) and can contain conditions or sub-groups. An "Add sub-group" button creates a nested group.

**URL parameter format.** Ransack's grouping param format already supports arbitrary nesting: `g[0][m]=or`, `g[0][g][0][m]=and`, etc. No custom encoding needed.

### Decisions

1. **Recursive tree data model**: Replace `{ conditions, groups }` with `{ combinator, children[] }`. Simpler, more general, naturally maps to Ransack's grouping and to QL parentheses.

2. **Backward compatible URL params**: The flat `f[field_op]=value` format remains for simple AND-only queries. Ransack grouping params (`g[...]`) are used only when OR/nesting is needed. Existing bookmarked URLs continue to work.

3. **Fail-loud for exceeded depth**: Rather than silently flattening (current behavior), the parser raises an error. Users see "Nesting too deep" rather than getting wrong results.

4. **Default `max_nesting_depth: 2`**: Current behavior is preserved by default. Deep nesting is opt-in.

### Open Questions

1. ~~**Visual nesting UX**~~ — **Resolved.** Implemented with indentation and visual nesting indicators (nested containers with border styling). Each group shows its combinator (AND/OR) toggle and can contain conditions or sub-groups.

2. **Mobile UX**: Both the cascading field picker and deeply nested condition groups are challenging on mobile screens. Should the mobile layout use a simplified interaction pattern?

3. ~~**Migration of existing two-level data**~~ — **Resolved.** Incremental approach with backward compatibility: `FilterParamBuilder.build` accepts both the legacy `{ conditions, groups }` format and the new recursive `{ combinator, children }` format. The JS serializes to the new format; existing bookmarked URLs with the old format continue to work.

4. **Performance with deep Ransack nesting**: Deeply nested `g[0][g][0][g[0]...]` may produce complex SQL with many JOINs and subqueries. Should there be a SQL complexity limit or query timeout beyond `max_nesting_depth`?

5. **Custom filter interaction**: The platform supports custom filter methods (`filter_*` on models via `CustomFilterInterceptor`). How do custom filters interact with deep association paths? If a model defines a custom filter for `company.name`, should the lazy endpoint still list it as a regular field, or mark it as custom?
