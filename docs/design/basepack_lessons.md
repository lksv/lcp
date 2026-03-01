# Lessons Learned from Basepack Search System

**Purpose:** This file captures design patterns, algorithms, and architectural ideas inspired by the basepack gem (a Rails search/filter engine built on Ransack) and its usage in the subsys2 project. All code samples are original pseudocode or reimplementations written for LCP context — not copied from basepack source.

## 1. Three-Layer Filter Architecture

Basepack separates filtering into three independent, composable layers:

```
Request params
  ├── ?query=term           → Quick text search (free text, OR across fields)
  ├── ?f[field_pred]=val    → Structured filters (field + operator + value)
  └── ?ql=expression        → Query language (text DSL parsed to structured filters)
```

The key insight: **all three produce the same output** — a filtered `ActiveRecord::Relation`. They compose additively: quick search narrows, structured filters narrow further, QL is an alternative input to structured filters.

**The processing pipeline (conceptual):**
```
apply_quick_search(scope, params)    → 1. Free-text OR across queryable fields
apply_pagination(scope, params)      → 2. Page/per-page limits
apply_structured_filters(scope, params) → 3. Field+operator+value conditions via Ransack
```

**Lesson for LCP:** Keep the three layers independent. Don't merge quick search and advanced filter into one mechanism. They serve different UX needs — quick search is for exploration ("find something with 'Acme'"), advanced filter is for precise queries ("stage equals lead AND value > 10000").

## 2. Custom Filter Method Convention

The most powerful and extensible pattern in basepack. Models can define class methods that intercept filter parameters before Ransack processes them.

**Convention:** `self.filter_{field_name}(scope, value, auth_object)` or `self.filter_{field_name}_{predicate}(scope, value, auth_object)`

```ruby
# Simple boolean filter
def self.filter_active(scope, value, auth_object)
  scope.active(['t', 'true', '1', true].include?(value))
end

# Complex JOIN-based filter
def self.filter_magazine_issue(scope, values, auth_object)
  scope.joins(pays: { plobs: [:plob_issues, :order_template_magazine] })
    .where("order_template_magazines.magazine_id = ? AND plob_issues.issue_id = ?",
           values[:magazine], values[:issue])
end

# Filter with authorization check
def self.filter_my_records(scope, value, auth_object)
  scope.where(owner_id: auth_object.user.id) if value.present?
end
```

**The detection algorithm (pseudocode):**
```
for each filter param (key, value):
  if key is the complex condition container ("c"):
    for each condition in container:
      extract field_name, predicate, value from nested structure
      build method name: "filter_{field}_{predicate}" or "filter_{field}"
      if model responds to that method:
        call it: scope = model.filter_xxx(scope, value, auth_object)
        track as custom filter (excluded from Ransack)
      else:
        leave in params for Ransack to handle

  else if key matches pattern "fieldname_predicate" (e.g., "active_eq"):
    build method name: "filter_{key}" (strip trailing _eq for cleaner names)
    if model responds to it:
      call it and track as custom filter
    else:
      leave for Ransack

pass remaining (non-custom) params to Ransack for standard SQL generation
```

**Lesson for LCP:** This "intercept before Ransack" pattern is extremely valuable. In LCP, the equivalent would be:
1. Check if the model defines `self.filter_{name}` in its extensibility layer (via `app/lcp_services/filters/` or model extensions).
2. If yes, call it with `(scope, value, evaluator)`.
3. If no, pass to Ransack.

This enables complex filters (multi-table JOINs, subqueries, external service lookups) without extending Ransack itself.

## 3. Scope-as-Filter via Ransack Patch

Basepack patches Ransack to treat named scopes as filter parameters. This is the `scope_ransackable` macro.

**The approach (described conceptually — basepack monkey-patched Ransack's `search` method):**

```
scope_ransackable :overdue, :active   # Whitelist specific scopes

# When filter params arrive, the patched search method:
# 1. Iterates params
# 2. For each key that matches a model scope AND is whitelisted:
#    - Call the scope (with or without value argument)
#    - Verify it returns an ActiveRecord::Relation (security check)
#    - Remove from params so Ransack doesn't see it
# 3. Pass remaining params to Ransack as usual
# 4. Non-whitelisted scopes raise an error (prevent arbitrary method calls)
```

**How it works:**
1. Model declares `scope_ransackable :overdue, :active`.
2. When `?f[overdue]=true` arrives, the patch intercepts it before Ransack.
3. Calls `Model.overdue` (or `Model.overdue(value)` if parameterized).
4. Passes remaining params to Ransack.
5. Validates that the scope returns `ActiveRecord::Relation` (security).

**Important note for Ransack 4.x:** Ransack 4.x has native `ransackable_scopes` support, so this monkey-patch is no longer needed. Instead:
```ruby
def self.ransackable_scopes(auth_object = nil)
  %w[overdue active]
end
```
And the scope is called directly by Ransack 4.x when `?q[overdue]=true`.

**Lesson for LCP:** LCP already defines named scopes via model YAML. These should be automatically registered as `ransackable_scopes`. The predefined_filters in the presenter already reference scopes by name — the same scopes should be available in the advanced filter UI as virtual "fields" that users can toggle.

## 4. Custom Ransack Predicate: `one_of`

Basepack registers a custom Ransack predicate called `one_of` that accepts a comma/semicolon-separated string and converts it to a SQL `IN` clause. The idea:

```
# Ransack custom predicate concept:
# - arel_predicate: "in" (maps to SQL IN)
# - formatter: splits input string by comma or semicolon (with optional whitespace)
# - Result: ?f[status_one_of]=active,pending → WHERE status IN ('active', 'pending')
```

This is useful because users paste values from spreadsheets (semicolons) or type them (commas). The `formatter` normalizes both.

**In the UI**, when the `one_of` operator is selected, the value input switches from a text field to a `<textarea>` so users can paste multi-line value lists.

**Lesson for LCP:** The `in` and `not_in` operators need a multi-value input. Options:
- For enums: a multi-select dropdown (Tom Select with checkboxes).
- For free-form values: a textarea with comma/newline splitting (like `one_of`).
- For associations: a multi-select with remote search.

## 5. Type-Aware Quick Search Algorithm

The `Utils.query` method builds OR conditions across all queryable fields, with type-specific matching logic. This is the most sophisticated part of the quick search.

**Algorithm (pseudocode):**
```
function quick_search(scope, query_term, queryable_fields):
  return scope if query_term is blank

  # Escape hatch: let model override entirely
  if model has class method "default_query":
    return scope.merge(model.default_query(query_term))

  conditions = []   # will be OR-ed together
  lowered = query_term.downcase

  for each queryable field:
    column = arel reference to the field's DB column

    case field.type:
      :integer →
        try to parse query_term as Integer; if OK, add "column = integer_value"
        (silently skip if not a number)

      :decimal, :float →
        try to parse as Float; if OK, add "column = float_value"
        (silently skip if not numeric)

      :string, :text →
        add "column LIKE '%query_term%'"

      :boolean →
        if query_term looks truthy ("true", "1", "t") → add "column = TRUE"
        if query_term looks falsy ("false", "0", "f") → add "column = FALSE"
        (skip otherwise)

      :date →
        try to parse as date; if OK, add "column = parsed_date"

      :datetime →
        try to parse as datetime, then auto-detect precision:
        - If midnight (user typed just a date like "2024-01-15"):
            add "column >= day_start AND column < next_day_start"
        - If seconds are zero (user typed "2024-01-15 14:30"):
            add "column >= minute_start AND column < next_minute_start"
        - If sub-second is zero (user typed full time with seconds):
            add "column >= second_start AND column < next_second_start"
        - Otherwise: exact match

      :enum →
        collect enum values where stored_value matches OR display_label contains query
        if any matches: add "column IN (matched_values)"

  if conditions is not empty:
    return scope.where(conditions joined with " OR ")
  else:
    return scope.where("1=0")   # query was non-empty but nothing matched → empty result
```

**Key insights:**
1. **Numeric fields silently skip** non-numeric queries (via `rescue nil`) — typing "Acme" doesn't crash on integer fields.
2. **Datetime precision auto-detection** — "2024-01-15" matches the whole day, "2024-01-15 14:30" matches the whole minute. This is extremely user-friendly.
3. **Enum text matching** — searches both the stored value (`closed_won`) and the display text (`Closed Won`). A user typing "closed" finds both.
4. **`default_query` escape hatch** — models can completely override quick search with custom logic (useful for complex JOINs or external search).
5. **Empty result on no match** — `scope.where("0")` ensures that if the query is non-empty but matches nothing, zero results are returned (not all results).

**Lesson for LCP:** The current LCP `apply_search` only does LIKE on strings. It should:
- Skip numeric fields gracefully when the query isn't numeric.
- Use datetime range matching when the query is a date.
- Search enum display labels, not just stored values.
- Allow models to override via a `default_query` hook.

## 6. FilterQL: Query Language Design

Basepack implements a full query language using the Parslet PEG parser gem. Key design decisions:

**Grammar structure:**
```
query      = condition (AND condition)*
condition  = expression | str_expression | blank_expr
expression = identifier operator literal          # e.g., age >= 18
str_expr   = identifier [NOT] str_op string       # e.g., name not like '%test%'
blank_expr = identifier IS [NOT] switch_op        # e.g., email is not null
```

**Operator mapping (QL syntax → Ransack predicate):**

| QL Syntax | Ransack | QL Syntax | Ransack |
|-----------|---------|-----------|---------|
| `=` | eq | `!=` | not_eq |
| `>=` | gteq | `<=` | lteq |
| `>` | gt | `<` | lt |
| `like` | matches | `not like` | does_not_match |
| `cont` | cont | `not cont` | not_cont |
| `start` | start | `not start` | not_start |
| `end` | end | `not end` | not_end |
| `one_of` | one_of | | |
| `is blank` | blank | `is not blank` | present |
| `is null` | null | `is not null` | not_null |

**Bidirectional conversion** — a reverse mapping table enables converting structured conditions back to QL text. The serialization algorithm:

```
function conditions_to_ql(conditions):
  parts = []
  for each (field_name, predicate, value) in conditions:
    if predicate is a boolean type (true/false/null/present/blank):
      append "{field_name} {reverse_lookup(predicate)}"   # no value needed
    else:
      format value (quote strings, format hashes/arrays)
      append "{field_name} {reverse_lookup(predicate)} {formatted_value}"
  return parts.join(" and ")
```

**Custom functions in QL** — the parser supports function calls (e.g., `current_user()`, `today()`) that are resolved at runtime. The controller registers a hash of function names → lambdas. When the parser encounters `function_name()`, it looks up and calls the lambda. This allows context-dependent values in queries like `user_id = current_user() and issue_id = current_issue()`.

**Error reporting** — when parsing fails, the parser finds the deepest (most specific) parse error in the error tree and reports it with line/column position. The error message inserts a marker into the original query string at the failure position, e.g.: `"Unexpected input at line 1 column 15: "age >= 18 and (<=ERROR)name ..."``. This makes it easy for users to find and fix syntax errors.

**Limitations of basepack's QL:**
- Only supports AND (no OR, no parenthesized grouping in the released version — the code has commented-out OR/grouping rules).
- The query is flat — `conditions.inject({}) { |h, c| h.merge(c) }` means duplicate field names override.
- No type checking — `age cont 'text'` is syntactically valid but produces a meaningless SQL query.

**Lesson for LCP:** If implementing QL:
- Use a recursive descent parser (no Parslet dependency needed — the grammar is simple enough).
- Support AND, OR, and parenthesized grouping from the start.
- Use dot-notation for associations: `company.name ~ 'Acme'` instead of underscores.
- Keep bidirectional conversion — it enables switching between visual builder and QL.
- Add QL functions for dynamic values (`@today`, `@current_user`, `@scope_name`).

## 7. Filter UI: JavaScript Architecture

The query builder UI (`Basepack.QueryForm`) follows a template-based approach:

**Data flow:**
1. Server renders the filter container and a dropdown menu of filterable fields.
2. JavaScript initializes with a `setup` JSON payload containing: predicates metadata, enum options, date format, and initial filter state.
3. User clicks "Add Filter" → selects field from dropdown → JavaScript creates a filter row.
4. Filter row contains: field label, predicate select, value input (type-dependent).
5. On form submit, hidden inputs encode the filter as Ransack params: `f[c][INDEX][a][0][name]`, `f[c][INDEX][p]`, `f[c][INDEX][v][0][value]`.

**The `setup` JSON payload structure (conceptual):**
```
{
  options: {
    regional: { datePicker format config },
    predicates: { predicate_name → { name, label, type, wants_array } },
    enum_options: { field_name → [[value, label], ...] },
  },
  initial: [
    { label, name, type, value, predicate, template }   // one per active filter
  ]
}
```

**Type → predicate mapping** — each field type has a specific set of valid operators:

| Type | Available Predicates |
|------|---------------------|
| boolean | true, false, null, not_null |
| date, datetime | eq, not_eq, lt, lteq, gt, gteq, present, blank, null, not_null |
| enum | eq, not_eq, null, not_null |
| string, text, belongs_to | eq, not_eq, matches, does_not_match, cont, not_cont, start, not_start, end, not_end, present, blank, one_of, null, not_null |
| integer, decimal, float | eq, not_eq, lt, lteq, gt, gteq, one_of, null, not_null |

**Value input switching:**
- `boolean` predicates → no value input (predicate IS the value: "is true", "is false", "is null").
- `one_of` predicate → textarea (paste comma-separated values).
- `enum` fields → `<select>` with enum options.
- `date/datetime` fields → datepicker.
- All others → text input.

**Lesson for LCP:** The JSON payload approach is solid. LCP should:
- Build the filter metadata server-side (from presenter config + permissions + model metadata).
- Pass it as a `data-filter-config` attribute on the container element.
- JavaScript reads it and builds the UI dynamically.
- Use Tom Select for field selection (grouped by direct fields / associations) and for enum value selection.

## 8. Nested Association Field Resolution

The association field resolution uses a "longest prefix match" algorithm to disambiguate underscore-joined names:

```
function resolve_nested_field(name):
  # First, try as a direct field
  if name is a known filterable field: return it

  # Otherwise, split by underscores and try progressively shorter prefixes
  segments = name.split("_")
  for length from (segments.count - 1) down to 1:
    prefix = segments[0..length-1].join("_")
    if prefix is a known association field:
      remainder = segments[length..].join("_")
      return association.resolve_nested_field(remainder)   # recurse

  return nil  # not found
```

**The problem this solves:** Ransack uses underscores for both field names and association traversal. `company_name_cont` could mean:
- Field `company_name` with predicate `cont`, OR
- Association `company`, field `name` with predicate `cont`.

The algorithm tries longest prefix first, which matches association names before field names.

**Lesson for LCP:** With LCP's dot-notation (`company.name`), this ambiguity doesn't exist. But the algorithm is useful for building the filterable field tree — recursively traverse associations and collect their fields.

## 9. Filter Form: Custom Field Templates

Basepack supports custom filter field templates defined in view partials. A resource-specific `_query.html.haml` partial can register additional filter fields with custom HTML templates. For example, a "Magazine & Issue" composite filter renders two dependent dropdowns — selecting a magazine reloads the issue dropdown via AJAX.

**The key insight:** A single "filter field" can have multiple inputs (magazine dropdown + issue dropdown). The custom template renders both inputs, and the `filter_magazine_issue` class method receives the combined value as a Hash.

**Lesson for LCP:** The advanced filter should support "composite filters" where one filter row can have multiple inputs. Use cases:
- Date range (from + to).
- Association with dependent dropdowns (category + subcategory).
- Geographic filters (city + radius).

In LCP, this could be a `composite_filter` type in the presenter config with a custom template and a registered filter service.

## 10. Saved Filter Model

The Filter model stores reusable filters. Key attributes:

```
SavedFilter:
  name          — unique per filter_type (resource class)
  filter_type   — model class name (e.g., "Deal") — scopes filters to a resource
  filter        — the QL text string
  active        — boolean (can be deactivated without deleting)
  position      — integer for manual ordering
  user_id       — owner (belongs_to user)
```

The `results` method re-executes the stored QL string against a live scope by passing it through the standard filter pipeline with the current user's auth context. This means saved filters always reflect the current data and current permissions — no stale results.

**Design decisions:**
- Filters are stored as QL text (human-readable, editable, versionable).
- `filter_type` is the model class name (e.g., "Deal") — scopes filters to a resource type.
- `results` method re-executes the filter against a live scope — no stale data.
- Position field for manual ordering of filter presets.
- Per-user ownership with `user_id`.

**Lesson for LCP:** Store filters as both structured JSON (for the visual builder) and QL text (for display/editing). The JSON is the source of truth; QL is generated from it. This avoids parsing roundtrip issues.

## 11. Predicate Metadata from Ransack

Basepack dynamically reads all available predicates from `Ransack.predicates` at boot time and caches them as a hash. For each predicate it extracts: name, i18n-translated label (via `Ransack::Translate.predicate`), type (string/boolean), whether it's a compound predicate (`_any`/`_all` variants), and whether it expects an array value (`in`, `not_in`). This hash is then serialized to JSON and passed to the JavaScript UI.

**Lesson for LCP:** Don't hardcode predicate metadata. Read it from Ransack at boot time and cache it. This ensures the UI is always in sync with the available predicates, including any custom ones added later.

## 12. Enum Options Collection (Recursive for Associations)

The algorithm iterates all filterable fields. For each:
- If the field has enum options (select/enum type) → add to result with the full nested name as key.
- If the field is an association (and not polymorphic, and not already nested) → recurse into the associated model's fields and merge their enum options.

This produces a flat hash keyed by full path (`company_industry`, or in LCP terms, `company.industry`) with values being `[[stored_value, display_label], ...]` pairs.

**Lesson for LCP:** When building filter metadata for the UI, recursively collect enum values from both direct fields and association fields. The key must be the full path (`company.industry`, not just `industry`).

## 13. Edge Cases from Production (subsys2)

### Boolean value normalization
Multiple representations of boolean values appear in URL params (`"t"`, `"true"`, `"1"`, `true`). Always normalize by checking against a known set of truthy strings (case-insensitive). Without this, `"t"` from a checkbox is not recognized as `true`.

### Multi-value input parsing
When accepting comma-separated value lists (for `in` / `one_of` operators), split on both commas and semicolons with optional surrounding whitespace: `split(/\s*[,;]\s*/)`. Users paste from spreadsheets (semicolons) and type manually (commas).

### Empty vs nil filter values
Reject empty-string params before passing to Ransack. Without this, an empty text input produces `WHERE field = ''` instead of being ignored. Strip blank values from filter params early in the pipeline.

### Dependent dropdowns in filters
The `data-dependant-filteringselect` attribute chains two select inputs — changing the first reloads the second's options via AJAX. The dependent param name is specified: `data-dependant-param="f[magazine_id_eq]"`.

### Filter vs sort param collision
Basepack uses `f` for filters and allows sort within `f[s]`. When converting between QL and structured filters, sort must be preserved separately.

## Summary: What to Reuse in LCP

| Pattern | Priority | Notes |
|---------|----------|-------|
| Custom `filter_*` method convention | High | Enable host apps to define complex filters |
| Type-aware predicate lists | High | Different operators for string/number/date/enum/boolean |
| Quick search datetime range matching | High | Date-only input matches whole day |
| Quick search enum text matching | Medium | Search by display label, not just stored value |
| `one_of` predicate with textarea | Medium | Multi-value paste from spreadsheets |
| Bidirectional QL ↔ structured conversion | Medium | For QL feature |
| Enum options recursive collection | Medium | Association enum values in filter dropdown |
| `default_query` model override | Medium | Escape hatch for custom quick search |
| Filter metadata JSON payload | High | Server → JS data contract for filter builder |
| Saved filter as QL + JSON dual storage | Medium | For saved filters feature |
| Boolean normalization | High | Prevent false negatives from param format |
| Empty param rejection | High | Prevent `WHERE field = ''` bugs |
