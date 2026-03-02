# Design: Advanced Search & Filter Builder

**Status:** In Progress (Phase 0–2 implemented, Phases 3–4 proposed)
**Date:** 2026-03-01

## Problem

The platform currently provides two search mechanisms on the index page:

1. **Text search** (`?q=term`) — a single text input that builds `LIKE '%term%'` conditions across configured `searchable_fields`. Limited to substring matching on direct model columns. No operators, no value types, no association traversal.

2. **Predefined filter buttons** (`?filter=name`) — a flat list of scope-based buttons that activate named scopes. The scopes are defined in model YAML and referenced from presenter `search_config`. Users cannot combine them, parameterize them, or create their own.

### Concrete Pain Points

- **No field-level filtering.** A user looking at a deals index cannot filter by `stage = closed_won` or `value > 10000` without a predefined scope. Every useful filter combination must be anticipated by the configurator and defined as a named scope.
- **No association filtering.** Filtering deals by `company.industry = 'Technology'` or `contact.city = 'Prague'` is impossible. The text search only queries direct columns.
- **No operator selection.** The text search always uses `LIKE` (contains). Users cannot search for "starts with", "greater than", "is blank", "is one of", etc.
- **No composability.** Users cannot combine multiple conditions (`stage = lead AND value > 5000 AND company.name contains 'Acme'`). Each predefined filter is a standalone scope; they don't compose.
- **No saved filters.** If a user repeatedly applies the same complex filter, they must re-enter it every time. There is no mechanism to name, save, share, or preset filter combinations.
- **No user-defined filters.** Configurators (YAML authors) can define predefined scopes, but end-users have no self-service filter capability.
- **Ransack is unused.** The `ransack ~> 4.0` gem is a declared dependency but is never called. The `apply_search` method in `ApplicationController` builds raw SQL `LIKE` queries manually.
- **No query language for power users.** Advanced users and API consumers have no text-based way to express complex filters concisely.

### What Works Today

| Feature | Status | Implementation |
|---------|--------|----------------|
| Text search (substring) | Working | Manual `LIKE` query in `apply_search` |
| Predefined filter buttons | Working | Named scopes from model YAML |
| Default scope | Working | `default_scope` in presenter `search_config` |
| Custom field search | Working | JSON `custom_data` text search |
| Sorting by column | Working | `?sort=field&direction=asc` params |
| Pagination | Working | Kaminari integration |

## Goals

- **Visual filter builder**: An interactive UI where users add filter rows — each row selects a field, an operator, and a value. Rows combine with AND logic, with optional OR grouping.
- **Association filtering**: Filter by fields on related models through the full association chain (N levels deep, e.g., `deal → company → country.name`).
- **Type-aware operators**: The available operators change based on field type — text fields get `contains`, `starts_with`, `equals`; numbers get `>`, `>=`, `<`, `<=`, `between`; dates get date-aware operators including relative dates (`this month`, `last 7 days`); booleans get `is true`/`is false`; enums get dropdown selection.
- **Improved quick search**: The existing text search becomes type-aware — numeric fields skip non-numeric queries, dates match by range, enums match by display label. Models can override quick search via a `default_query` escape hatch.
- **Predefined scopes in the filter builder**: Named scopes (existing `predefined_filters`) appear as one-click filter presets alongside user-built filters. Scopes can also appear as special "virtual fields" in the Add Filter menu.
- **Custom filter extensibility**: Host apps can define `filter_*` class methods on models that intercept filter params before Ransack — enabling complex JOINs, subqueries, and business-logic filters.
- **Saved filters**: Users can name and save filter combinations. Saved filters follow the Configuration Source Principle — predefined in YAML, user-created in DB, or provided by host app.
- **Text query language (QL)**: A power-user mode where filters can be typed as a text expression (e.g., `stage = 'lead' and company.name ~ 'Acme'`). The QL is bi-directional — the visual builder can render existing QL, and the visual state can be serialized to QL.
- **Permission-aware**: Users only see and filter on fields they have read permission for. Association paths are also permission-checked.
- **Metadata-driven configuration**: Which fields are filterable, which operators are available, and which scopes are exposed — all declared in presenter YAML (or DSL), consistent with the platform's metadata-first approach.
- **Ransack integration**: Use Ransack 4.x as the query engine for SQL generation, predicate mapping, association joins, and sorting. Wrap Ransack with LCP metadata for configuration and authorization.

## Non-Goals

- **Full-text search engine** (Elasticsearch, Meilisearch, etc.) — a separate concern with different architecture. The advanced filter operates on SQL queries via ActiveRecord.
- **Faceted search / aggregation counts** — no count badges on filter values (e.g., "Active (42)"). Can be added later.
- **Cross-entity global search** — searching across multiple models simultaneously. Each index page filters its own model.
- **Cursor-based pagination** — the existing offset pagination (Kaminari) is retained.
- **Fuzzy matching / typo tolerance** — requires a search engine, not SQL predicates.
- **Real-time filter-as-you-type** — the filter is applied on form submit, not on each keystroke.

## Background: The Search Problem Space

Building a generic filter UI for a metadata-driven platform presents several challenges worth understanding before diving into the design.

### Challenge 1: Operator–Type Compatibility

Not all operators make sense for all field types. `greater than` is meaningless for a boolean. `contains` is meaningless for an integer. `is true` is meaningless for a string. The filter UI must restrict available operators based on the selected field's type.

**Operator matrix by type:**

| Operator | string | text | integer | float | decimal | boolean | date | datetime | enum | association |
|----------|--------|------|---------|-------|---------|---------|------|----------|------|-------------|
| equals | yes | — | yes | yes | yes | — | yes | yes | yes | yes |
| not equals | yes | — | yes | yes | yes | — | yes | yes | yes | yes |
| contains | yes | yes | — | — | — | — | — | — | — | — |
| not contains | yes | yes | — | — | — | — | — | — | — | — |
| starts with | yes | — | — | — | — | — | — | — | — | — |
| ends with | yes | — | — | — | — | — | — | — | — | — |
| greater than | — | — | yes | yes | yes | — | yes | yes | — | — |
| greater or equal | — | — | yes | yes | yes | — | yes | yes | — | — |
| less than | — | — | yes | yes | yes | — | yes | yes | — | — |
| less or equal | — | — | yes | yes | yes | — | yes | yes | — | — |
| in list | yes | — | yes | — | — | — | — | — | yes | yes |
| not in list | yes | — | yes | — | — | — | — | — | yes | yes |
| is blank | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| is present | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| is null | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| is not null | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| between | — | — | yes | yes | yes | — | yes | yes | — | — |
| is true | — | — | — | — | — | yes | — | — | — | — |
| is false | — | — | — | — | — | yes | — | — | — | — |

**Note:** Date and datetime fields also support relative operators (`last_n_days`, `this_week`, `this_month`, `this_quarter`, `this_year`) not shown in the matrix above. These are resolved to absolute `gteq`/`lteq` ranges at query time by the `FilterParamBuilder`.

### Challenge 2: Association Path Ambiguity

When supporting N-level association filtering (e.g., `deal → company → country → name`), the field name becomes a dot-separated path. Ransack uses underscores (`company_country_name_cont`), which creates ambiguity — does `company_name_cont` mean "company.name contains" or "company_name contains"? Ransack resolves this by trying the longest matching attribute first, but with dynamic models this requires careful handling.

**Mitigation strategy:** The filter UI always selects fields from a structured tree (not a flat text field), so the association path is unambiguous. The QL parser also uses explicit dot notation (`company.name`) rather than underscores. The Ransack key is constructed programmatically from the parsed path, not from user-typed text.

### Challenge 3: N+1 and JOIN Explosion

Each association filter condition adds a SQL JOIN. Filtering on `company.name` AND `contact.email` AND `contact.company.industry` produces multiple JOINs that can explode query cost. With `has_many` associations, JOINs can also produce duplicate rows.

**Mitigation strategies:**
- Always use `result(distinct: true)` (or `DISTINCT` in the query) when `has_many` joins are present.
- Limit the maximum association depth (configurable, default 3).
- For `has_many` filters, consider `EXISTS` subqueries instead of JOINs when possible.
- Log slow filter queries in development for early detection.

### Challenge 4: Permission Boundaries

If a user doesn't have read access to `deal.value`, they shouldn't be able to filter by it — even though the data is in the database and the SQL would work. This requires integrating the filter field list with `PermissionEvaluator.readable_fields`. For association paths, each segment must be permission-checked.

### Challenge 5: Custom Fields in Filters

Custom fields are stored in a JSON `custom_data` column. Standard Ransack predicates don't work on JSON paths. Custom fields require specialized query generation (JSON extraction + comparison) that differs between PostgreSQL (`jsonb_extract_path_text`) and SQLite (`json_extract`).

### Challenge 6: Saved Filter Ownership & Sharing

Saved filters can be personal (only the creator sees them), shared (visible to specific roles), or global (visible to everyone). This interacts with the permission system and requires careful scoping.

## Alternative Approaches Considered

### A) Pure Arel / Custom Query Builder

Build an entirely custom SQL query builder on top of Arel (the SQL AST library bundled with ActiveRecord).

**Pros:**
- Full control over generated SQL — can optimize for specific patterns (e.g., `EXISTS` subqueries for `has_many` instead of JOINs).
- No external dependency for query generation.
- Can reuse the platform's existing 12-operator `ConditionEvaluator` semantics directly.

**Cons:**
- Significant implementation effort — Arel's API is low-level and verbose.
- Must handle association join resolution manually (traversing reflection chains, aliasing tables for self-joins).
- Must implement predicate normalization, type casting, NULL handling, and DISTINCT logic from scratch.
- No form helpers — the entire param↔query mapping is custom.
- Arel is a private Rails API with no stability guarantees between versions.

**Verdict:** High effort, high maintenance. Suitable only if Ransack's query generation is insufficient for a specific use case (e.g., JSON column queries where Ransack falls short). Not recommended as the primary approach.

### B) Hybrid: Ransack for SQL + LCP Operators for UI

Use Ransack as the SQL query engine but present the platform's own operator vocabulary (the 12 operators from `ConditionEvaluator`) in the UI, mapping them to Ransack predicates internally.

**Pros:**
- Consistent terminology between search filters and other condition contexts (visibility conditions, record rules, permission conditions all use the same operator names).
- Users learn one set of operators.

**Cons:**
- The two operator sets don't map 1:1 — Ransack has operators LCP doesn't (`cont`, `start`, `end`, `null`, `true/false`), and LCP has operators Ransack doesn't (`matches` as regex). The UI would be artificially limited.
- Search filtering is fundamentally different from visibility conditions — search needs substring matching (`cont`), date ranges, and `IN` lists, while visibility conditions evaluate in-memory on a single record.

**Verdict:** A forced unification would compromise both systems. Better to use Ransack's native predicate vocabulary for search (it's the SQL standard) and keep `ConditionEvaluator` for its intended purpose (in-memory record evaluation).

### C) Ransack with Metadata Wrapper (Recommended)

Use Ransack 4.x as the query engine. Wrap it with LCP metadata configuration to control which fields are filterable, which operators are available per field type, and which associations can be traversed. The filter UI generates Ransack-compatible parameters; the controller passes them to `Model.ransack(params)`.

**Pros:**
- Ransack is already a declared dependency (v4.4.1 in Gemfile.lock) — zero new gems.
- Mature predicate system with 20+ operators, association traversal, groupings (AND/OR), sorting.
- Ransack 4.x mandatory allowlisting (`ransackable_attributes`, `ransackable_associations`) aligns perfectly with the platform's permission model.
- Form helpers available (though we'll build a custom UI for the visual builder).
- Active maintenance with Rails 7.x/8.x compatibility.
- The `auth_object` parameter enables passing `PermissionEvaluator` for dynamic allowlisting.

**Cons:**
- Ransack's underscore-based attribute naming can be ambiguous with associations (mitigated by programmatic key construction).
- No native support for JSON column queries (custom fields) — requires custom predicates or fallback to raw SQL.
- Groupings param format is complex and deeply nested.

**This is the recommended approach** and the focus of this design.

## Design

### Architecture Overview

```
User Interaction
├── Visual Filter Builder (JavaScript)
│   ├── Add filter row → select field → select operator → enter value
│   ├── Add group (OR) → nested rows within a group
│   ├── Predefined scope buttons → quick one-click filters
│   └── Save filter → name, save, share
│
├── Query Language Editor (text input)
│   ├── Type QL expression (e.g., "stage = 'lead' and value > 5000")
│   └── Parse ↔ Serialize bidirectionally with visual builder state
│
└── URL Parameters (bookmarkable)
    └── ?qs=term & ?f[field_pred]=value&f[s]=field+dir

         │
         ▼

Controller (ResourcesController#index)
├── apply_advanced_search(scope)
│   ├── Apply predefined scope + filter scope
│   ├── Sanitize ?f[...] params (reject blanks, normalize booleans)
│   ├── Intercept custom filter_* methods (before Ransack)
│   ├── scope.ransack(remaining_params, auth_object: evaluator).result(distinct: true)
│   ├── Apply quick text search (?qs=, additive, type-aware)
│   └── Apply custom field filters (?cf[...], JSON query fallback)
│
└── Filter metadata (for rendering the UI)
    ├── filterable_fields (from presenter + permissions)
    ├── association_fields (traversable, depth-limited)
    ├── predefined_scopes (from search_config)
    └── saved_filters (from DB + YAML)

         │
         ▼

Ransack 4.x (Query Engine)
├── ransackable_attributes(auth_object) → derived from PermissionEvaluator
├── ransackable_associations(auth_object) → derived from model associations + permissions
├── ransackable_scopes(auth_object) → derived from search_config.predefined_filters
├── Predicate resolution (eq, cont, gt, gteq, lt, lteq, in, not_in, null, present, blank, ...)
├── Association JOIN generation (multi-level)
├── Groupings (AND / OR combinators)
└── result(distinct: true) → ActiveRecord::Relation
```

### 1. Presenter Configuration — `search` key extension

The existing `search_config` in presenter YAML is extended with new keys while retaining full backward compatibility. Existing `searchable_fields`, `predefined_filters`, `enabled`, and `placeholder` continue to work unchanged.

```yaml
# config/lcp_ruby/presenters/deal.yml
presenter:
  name: deal
  model: deal
  slug: deals

  search:
    enabled: true
    placeholder: "Quick search..."

    # --- Existing (unchanged) ---
    searchable_fields: [title, description]

    predefined_filters:
      - { name: all, label: "All", default: true }
      - { name: open, label: "Open", scope: open_deals }
      - { name: won, label: "Won", scope: won }
      - { name: lost, label: "Lost", scope: lost }

    # --- New: Advanced Filter Configuration ---
    advanced_filter:
      enabled: true                    # Show the "Add Filter" button (default: true when search.enabled)
      max_conditions: 20               # Safety limit on filter rows (default: 20)
      max_association_depth: 3          # How deep association traversal goes (default: 3)
      default_combinator: and           # Top-level combinator: "and" or "or" (default: "and")
      allow_or_groups: true             # Allow users to create OR groups (default: true)
      query_language: true              # Show "Edit as QL" toggle (default: false)

      # Fields available in the filter dropdown.
      # If omitted, all readable model fields are shown (auto-detected from permissions).
      # If specified, only these fields appear. Supports associations with dot notation.
      filterable_fields:
        - title                          # Direct field
        - stage                          # Enum field — auto-detects enum values for dropdown
        - value                          # Numeric field — auto-detects numeric operators
        - expected_close_date            # Date field — auto-detects date operators
        - priority                       # Enum field
        - company.name                   # Association field (1 level)
        - company.industry               # Association field (1 level)
        - contact.email                  # Association field (1 level)
        - contact.company.country        # Association field (2 levels)

      # Override operators for specific fields (optional).
      # By default, operators are auto-detected from field type.
      field_options:
        stage:
          operators: [eq, not_eq, in, not_in]  # Restrict operators
        value:
          operators: [eq, gt, gteq, lt, lteq, between, present, blank]
          step: 0.01                     # Numeric input step

      # Predefined filter presets (different from scope buttons above).
      # These populate the filter builder with a preset combination.
      presets:
        - name: high_value_open
          label: "High-value open deals"
          conditions:
            - { field: stage, operator: not_in, value: [closed_won, closed_lost] }
            - { field: value, operator: gteq, value: 10000 }
        - name: my_stale_deals
          label: "My stale deals"
          conditions:
            - { field: expected_close_date, operator: lt, value: "{today}" }
            - { field: stage, operator: not_in, value: [closed_won, closed_lost] }
        - name: created_this_month
          label: "Created this month"
          conditions:
            - { field: created_at, operator: this_month }

    # --- New: Saved Filters ---
    saved_filters:
      enabled: true                      # Allow users to save personal filters (default: false)
      sharing: true                      # Allow sharing filters with roles (default: false)
```

**DSL equivalent:**

```ruby
LcpRuby.define_presenter("deal") do
  model "deal"
  slug "deals"

  search do
    enabled true
    placeholder "Quick search..."
    searchable_fields [:title, :description]

    predefined_filter "all", default: true
    predefined_filter "open", scope: :open_deals
    predefined_filter "won", scope: :won

    advanced_filter do
      max_conditions 20
      max_association_depth 3
      allow_or_groups true
      query_language true

      filterable_field :title
      filterable_field :stage, operators: [:eq, :not_eq, :in, :not_in]
      filterable_field :value, operators: [:eq, :gt, :gteq, :lt, :lteq, :between]
      filterable_field :company, :name      # dot-path as two arguments
      filterable_field :contact, :email

      preset "high_value_open", label: "High-value open deals" do
        condition field: :stage, operator: :not_in, value: %w[closed_won closed_lost]
        condition field: :value, operator: :gteq, value: 10000
      end
    end

    saved_filters enabled: true, sharing: true
  end
end
```

### 2. Auto-Detection of Filterable Fields

When `filterable_fields` is not specified in the presenter, the platform auto-detects available fields:

1. **Direct fields:** All model fields where the user has read permission (`PermissionEvaluator.readable_fields`), excluding `id`, `created_at`, `updated_at`, computed fields, and attachment fields.
2. **Association fields:** For each `belongs_to` association on the model, the target model's `label_method` field is added (e.g., `company.name`). Only associations where the user has read permission on the FK field are included.
3. **Custom fields:** Active custom field definitions for the model that have `filterable: true` (a new attribute on `CustomFieldDefinition`, default: `false`).

The auto-detection is evaluated at request time (not boot time) because it depends on the current user's permissions.

### 3. Operator–Type Mapping

Each field type maps to a set of Ransack predicates. The mapping is defined in a central registry:

```ruby
# lib/lcp_ruby/search/operator_registry.rb
module LcpRuby
  module Search
    class OperatorRegistry
      OPERATORS_BY_TYPE = {
        string:   %i[eq not_eq cont not_cont start not_start end not_end in not_in present blank null not_null],
        text:     %i[cont not_cont present blank null not_null],
        integer:  %i[eq not_eq gt gteq lt lteq between in not_in present blank null not_null],
        float:    %i[eq not_eq gt gteq lt lteq between present blank null not_null],
        decimal:  %i[eq not_eq gt gteq lt lteq between present blank null not_null],
        boolean:  %i[true not_true false not_false null not_null],
        date:     %i[eq not_eq gt gteq lt lteq between last_n_days this_week this_month this_quarter this_year present blank null not_null],
        datetime: %i[eq not_eq gt gteq lt lteq between last_n_days this_week this_month this_quarter this_year present blank null not_null],
        enum:     %i[eq not_eq in not_in present blank null not_null],
        uuid:     %i[eq not_eq in not_in present blank null not_null],
      }.freeze

      OPERATOR_LABELS = {
        eq: "equals", not_eq: "not equals",
        cont: "contains", not_cont: "not contains",
        start: "starts with", not_start: "does not start with",
        end: "ends with", not_end: "does not end with",
        gt: "greater than", gteq: "greater or equal",
        lt: "less than", lteq: "less or equal",
        between: "is between",
        in: "is one of", not_in: "is not one of",
        present: "is present", blank: "is blank",
        null: "is null", not_null: "is not null",
        true: "is true", not_true: "is not true",
        false: "is false", not_false: "is not false",
        last_n_days: "in the last N days",
        this_week: "this week", this_month: "this month",
        this_quarter: "this quarter", this_year: "this year",
      }.freeze

      # Operators that require no value input
      NO_VALUE_OPERATORS = %i[present blank null not_null true not_true false not_false
                              this_week this_month this_quarter this_year].freeze

      # Operators that accept multiple values
      MULTI_VALUE_OPERATORS = %i[in not_in].freeze

      # Operators that accept two values (from + to)
      RANGE_OPERATORS = %i[between].freeze

      # Operators that require a numeric parameter (e.g., "last N days" → N)
      PARAMETERIZED_OPERATORS = %i[last_n_days].freeze

      # Operators resolved at query time to absolute date ranges (not native Ransack predicates)
      RELATIVE_DATE_OPERATORS = %i[last_n_days this_week this_month this_quarter this_year].freeze
    end
  end
end
```

Operator labels are i18n-backed: `I18n.t("lcp_ruby.search.operators.#{operator}", default: label)`.

**Relative date and range operator resolution:**

`between`, `last_n_days`, and relative date operators (`this_week`, `this_month`, `this_quarter`, `this_year`) are not native Ransack predicates. The `FilterParamBuilder` expands them into standard Ransack predicates at query time:

| Operator | Expansion |
|----------|-----------|
| `between` (value: [from, to]) | `field_gteq = from` AND `field_lteq = to` |
| `last_n_days` (value: 7) | `field_gteq = 7.days.ago.beginning_of_day` |
| `this_week` | `field_gteq = Date.current.beginning_of_week` AND `field_lteq = Date.current.end_of_week` |
| `this_month` | `field_gteq = Date.current.beginning_of_month` AND `field_lteq = Date.current.end_of_month` |
| `this_quarter` | `field_gteq = Date.current.beginning_of_quarter` AND `field_lteq = Date.current.end_of_quarter` |
| `this_year` | `field_gteq = Date.current.beginning_of_year` AND `field_lteq = Date.current.end_of_year` |

### 4. Ransack Integration on Dynamic Models

When `ModelFactory::Builder` builds a dynamic AR class, it installs Ransack allowlisting methods:

```ruby
# Inside ModelFactory::Builder.build, after model class creation:

model_class.define_singleton_method(:ransackable_attributes) do |auth_object = nil|
  if auth_object.is_a?(LcpRuby::Authorization::PermissionEvaluator)
    auth_object.readable_fields.map(&:to_s)
  else
    column_names
  end
end

model_class.define_singleton_method(:ransackable_associations) do |auth_object = nil|
  model_def = LcpRuby.loader.model_definition(model_name)
  assoc_names = model_def.associations.select(&:lcp_model?).map(&:name).map(&:to_s)

  if auth_object.is_a?(LcpRuby::Authorization::PermissionEvaluator)
    # Only allow associations where the FK field is readable
    assoc_names.select do |assoc_name|
      assoc_def = model_def.associations.find { |a| a.name == assoc_name }
      next true unless assoc_def&.foreign_key  # has_many — always allow if target model exists
      auth_object.field_readable?(assoc_def.foreign_key)
    end
  else
    assoc_names
  end
end

model_class.define_singleton_method(:ransackable_scopes) do |auth_object = nil|
  search_config = presenter&.search_config
  return [] unless search_config

  (search_config["predefined_filters"] || [])
    .filter_map { |f| f["scope"] }
end
```

The `auth_object` is always the current user's `PermissionEvaluator`, passed from the controller:

```ruby
# In ResourcesController#index
@ransack_search = scope.ransack(
  params[:f],                        # custom param key (not default :q)
  auth_object: current_evaluator
)
```

### 5. Filter Builder — URL Parameter Format

The filter state is encoded in URL parameters for bookmarkability and back-button support. Two param formats are supported:

**A) Simple flat format (for common single-condition filters):**
```
?f[title_cont]=Acme&f[stage_eq]=lead&f[s]=value+desc
```

**B) Grouped format (for OR groups and complex combinations):**
```
?f[g][0][m]=and&f[g][0][c][title_cont]=Acme&f[g][0][c][stage_eq]=lead
&f[g][1][m]=or&f[g][1][c][value_gteq]=10000&f[g][1][c][priority_eq]=high
```

This is Ransack's native param format (with custom key `f` instead of default `q`), which means:
- URLs can be shared and bookmarked.
- The browser back button works correctly.
- External tools can construct filter URLs directly.

**Why `?f[...]` instead of Ransack's default `?q[...]`:**

Ransack defaults to `?q[field_pred]=value` (a Hash param). The platform's existing quick text search uses `?q=term` (a String param). Rails cannot parse `q` as both a String and a Hash in the same request. Following basepack's convention, we use:
- `?qs=term` — quick text search (renamed from `?q`)
- `?f[field_pred]=value` — Ransack structured filters
- `?f[s]=field+dir` — Ransack sorting (within the filter namespace)
- `?cf[field_operator]=value` — custom field filters (JSON column, outside Ransack)

The Ransack search object is initialized with the custom param key: `scope.ransack(params[:f], auth_object: evaluator)`.

### 6. Controller — `apply_advanced_search`

The existing `apply_search` method is refactored into `apply_advanced_search` which handles both the legacy simple search and the new filter builder:

```ruby
# app/controllers/lcp_ruby/application_controller.rb

def apply_advanced_search(scope)
  search_config = current_presenter.search_config
  return scope unless search_config&.dig("enabled")

  # 1. Apply default_scope (unchanged)
  if (default_scope = search_config["default_scope"])
    scope = scope.send(default_scope) if @model_class.respond_to?(default_scope)
  end

  # 2. Apply predefined filter scope (unchanged — backward compatible)
  if params[:filter].present?
    predefined = search_config["predefined_filters"]&.find { |f| f["name"] == params[:filter] }
    if (scope_name = predefined&.dig("scope"))
      scope = scope.send(scope_name) if @model_class.respond_to?(scope_name)
    end
  end

  # 3. Build filter params from ?f[...] namespace, reject blank values
  raw_filter_params = sanitize_filter_params(params[:f])

  # 4. Apply custom filter_* methods (intercept before Ransack — see Section 6.5)
  scope, remaining_params = apply_custom_filter_methods(scope, raw_filter_params)

  # 5. Build Ransack search from remaining filter params
  if remaining_params.present?
    @ransack_search = scope.ransack(remaining_params, auth_object: current_evaluator)
    scope = @ransack_search.result(distinct: true)
  end

  # 6. Apply quick text search on top (?qs= param, additive)
  if params[:qs].present? && search_config["searchable_fields"]&.any?
    scope = apply_text_search(scope, search_config)
  end

  # 7. Apply custom field filters (JSON column — not handled by Ransack)
  if params.dig(:cf)&.any?
    scope = apply_custom_field_filters(scope)
  end

  scope
end

private

def sanitize_filter_params(filter_params)
  return {} if filter_params.blank?
  # Strip blank values to prevent WHERE field = '' conditions
  filter_params.to_unsafe_h.reject { |_, v| v.blank? }
end
```

### 6.5. Custom Filter Methods (`filter_*` Convention)

Host applications can define class methods on model extensions that intercept filter parameters before Ransack processes them. This enables complex filtering logic (multi-table JOINs, subqueries, external service lookups, authorization-aware filters) that cannot be expressed as Ransack predicates.

**Convention:** `self.filter_{name}(scope, value, evaluator)`

```ruby
# app/models/deal_extensions.rb (host app)
module DealExtensions
  extend ActiveSupport::Concern

  class_methods do
    # Simple boolean filter
    def filter_active(scope, value, evaluator)
      return scope unless ActiveModel::Type::Boolean.new.cast(value)
      scope.where(stage: %w[lead qualified proposal])
    end

    # Complex JOIN-based filter
    def filter_region(scope, value, evaluator)
      scope.joins(company: :country)
           .where(countries: { region: value })
    end

    # Authorization-aware filter
    def filter_my_records(scope, value, evaluator)
      return scope unless ActiveModel::Type::Boolean.new.cast(value)
      scope.where(owner_id: evaluator.user.id)
    end
  end
end
```

**Detection algorithm (in `apply_custom_filter_methods`):**

Before passing filter params to Ransack, the controller checks each parameter key:
1. For each filter param `(key, value)` from `params[:f]`:
   - Build method name: `"filter_#{key}"` (strip trailing predicate like `_eq` if present)
   - If `@model_class.respond_to?(method_name)` and the method is defined directly on the model (not inherited from `ActiveRecord::Base`):
     - Call `@model_class.send(method_name, scope, value, current_evaluator)`
     - Validate return value is an `ActiveRecord::Relation`
     - Remove the key from params (so Ransack does not see it)
   - Else: leave in params for Ransack to handle
2. Return `[scope, remaining_params]` — Ransack processes only the remaining params.

**Registration in presenter YAML** (optional explicit declaration):

```yaml
search:
  advanced_filter:
    custom_filters:
      - name: region
        label: "Region"
        type: string            # value input type
      - name: my_records
        label: "My Records"
        type: boolean
      - name: active
        label: "Active Only"
        type: boolean
```

When `custom_filters` is declared, these appear as selectable fields in the filter dropdown under a "Custom" group. When not declared, `filter_*` methods still work when parameters arrive (e.g., via URL), but they do not appear in the UI dropdown.

**Security:** Only methods matching the `filter_` prefix convention are callable. The method must be defined directly on the model class (not inherited from `ActiveRecord::Base`). The return value is validated to be an `ActiveRecord::Relation` — if it returns anything else, the filter is ignored and a warning is logged.

### 7. Custom Field Filtering (JSON Column Fallback)

Ransack cannot natively query JSON columns. Custom field filters are handled separately with database-specific JSON extraction:

```ruby
# lib/lcp_ruby/search/custom_field_filter.rb
module LcpRuby
  module Search
    class CustomFieldFilter
      def self.apply(scope, field_name, operator, value, table_name)
        json_path = CustomFields::Query.extract_path(table_name, field_name)

        case operator.to_sym
        when :eq      then scope.where("#{json_path} = ?", value.to_s)
        when :not_eq  then scope.where("#{json_path} != ?", value.to_s)
        when :cont    then scope.where("#{json_path} LIKE ?", "%#{sanitize_like(value)}%")
        when :gt      then scope.where("CAST(#{json_path} AS REAL) > ?", value.to_f)
        when :gteq    then scope.where("CAST(#{json_path} AS REAL) >= ?", value.to_f)
        when :lt      then scope.where("CAST(#{json_path} AS REAL) < ?", value.to_f)
        when :lteq    then scope.where("CAST(#{json_path} AS REAL) <= ?", value.to_f)
        when :present then scope.where("#{json_path} IS NOT NULL AND #{json_path} != ''")
        when :blank   then scope.where("#{json_path} IS NULL OR #{json_path} = ''")
        when :in      then scope.where("#{json_path} IN (?)", Array(value).map(&:to_s))
        else scope
        end
      end
    end
  end
end
```

Custom field filters use a separate param namespace (`?cf[field_name_operator]=value`) to distinguish them from Ransack params.

### 8. Query Language (QL)

The Query Language provides a text-based alternative to the visual builder. It is parsed into a structured AST and then converted to Ransack params.

**Syntax:**

```
# Simple conditions
stage = 'lead'
value > 10000
title ~ 'Acme'                  # ~ means "contains"
company.name = 'Acme Corp'      # association dot-path

# Logical operators
stage = 'lead' and value > 5000
stage = 'lead' or stage = 'qualified'

# Grouping with parentheses
(stage = 'lead' or stage = 'qualified') and value > 5000

# List values
stage in ['lead', 'qualified', 'proposal']

# Null / presence tests
expected_close_date is null
description is present
active is true

# Predefined scopes
@open_deals                       # @ prefix invokes a named scope
@open_deals and value > 5000      # Scopes compose with conditions

# Relative date functions
expected_close_date >= {today}
created_at >= {7.days.ago}
created_at in {this_month}
created_at in {this_quarter}
```

**Operator mapping (QL → Ransack):**

| QL Syntax | Ransack Predicate | Meaning |
|-----------|-------------------|---------|
| `=` | `_eq` | Equals |
| `!=` | `_not_eq` | Not equals |
| `>` | `_gt` | Greater than |
| `>=` | `_gteq` | Greater or equal |
| `<` | `_lt` | Less than |
| `<=` | `_lteq` | Less or equal |
| `~` | `_cont` | Contains |
| `!~` | `_not_cont` | Not contains |
| `^` | `_start` | Starts with |
| `$` | `_end` | Ends with |
| `in` | `_in` | In list |
| `not in` | `_not_in` | Not in list |
| `is null` | `_null` | Is null |
| `is not null` | `_not_null` | Is not null |
| `is present` | `_present` | Is present (not null and not empty) |
| `is blank` | `_blank` | Is blank (null or empty) |
| `is true` | `_true` | Boolean true |
| `is false` | `_false` | Boolean false |
| `>= {N.days.ago}` | expanded to `_gteq` with computed date | Last N days |
| `in {this_week}` | expanded to `_gteq` + `_lteq` | This week |
| `in {this_month}` | expanded to `_gteq` + `_lteq` | This month |
| `in {this_quarter}` | expanded to `_gteq` + `_lteq` | This quarter |
| `in {this_year}` | expanded to `_gteq` + `_lteq` | This year |

**Parser implementation:** A recursive descent parser (no external gem dependency) that produces a condition tree. The tree is then serialized to Ransack's groupings param format.

**Bidirectional conversion:** The visual builder state can be serialized to QL text, and QL text can be parsed back to visual builder state. This allows users to switch between modes without losing their filter.

### 9. Saved Filters — Configuration Source Principle

Saved filters follow the three-source principle:

| Source | How | When |
|--------|-----|------|
| **YAML (presets)** | `advanced_filter.presets` in presenter YAML | Static, version-controlled. Appear for all users. Cannot be modified at runtime. |
| **DB (user-saved)** | `SavedFilter` model in database | Runtime. Users create/edit/delete their own filters. Optional sharing by role. |
| **Host API** | Host app registers filters via `LcpRuby.configure` | Host app provides dynamic presets (e.g., from external system, user preferences service). |

**SavedFilter model (generated via `rails generate lcp_ruby:saved_filters`):**

```yaml
# Generated model metadata
model:
  name: saved_filter
  label: "Saved Filter"
  table_name: lcp_ruby_saved_filters
  fields:
    - name: name
      type: string
      validations: [{ type: presence }]
    - name: target_model
      type: string
      validations: [{ type: presence }]
    - name: presenter_slug
      type: string
    - name: filter_data
      type: json
    - name: query_language
      type: text
    - name: scope
      type: string
      enum_values: [personal, role, global]
      default: personal
    - name: shared_roles
      type: json
    - name: position
      type: integer
    - name: active
      type: boolean
      default: true
    - name: user_id
      type: integer
  associations:
    - type: belongs_to
      name: user
      class_name: "User"
      required: false
  options:
    timestamps: true
```

**`filter_data` structure** (JSON, mirrors the visual builder state):

```json
{
  "combinator": "and",
  "conditions": [
    { "field": "stage", "operator": "not_in", "value": ["closed_won", "closed_lost"] },
    { "field": "value", "operator": "gteq", "value": 10000 },
    { "field": "company.name", "operator": "cont", "value": "Acme" }
  ],
  "groups": [
    {
      "combinator": "or",
      "conditions": [
        { "field": "priority", "operator": "eq", "value": "high" },
        { "field": "priority", "operator": "eq", "value": "critical" }
      ]
    }
  ]
}
```

### 10. Visual Filter Builder — UI Design

The filter builder replaces the existing single search input with a richer UI. The existing text search and predefined filter buttons are preserved above the filter builder.

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 [Quick search...________________] [Search]               │
│                                                              │
│ [All] [Open] [Won] [Lost]              ← predefined filters │
│                                                              │
│ ┌── Filters ──────────────────────────────────────────────┐  │
│ │                                                          │  │
│ │  [stage     ▾] [equals        ▾] [lead          ▾] [×]  │  │
│ │  AND                                                     │  │
│ │  [value     ▾] [greater than  ▾] [10000          ] [×]  │  │
│ │  AND                                                     │  │
│ │  ┌─ OR group ──────────────────────────────────────┐     │  │
│ │  │ [company.name ▾] [contains ▾] [Acme      ] [×] │     │  │
│ │  │ OR                                              │     │  │
│ │  │ [company.name ▾] [contains ▾] [Corp      ] [×] │     │  │
│ │  │         [+ Add condition]  [Remove group]       │     │  │
│ │  └─────────────────────────────────────────────────┘     │  │
│ │                                                          │  │
│ │  [+ Add filter] [+ Add OR group]                         │  │
│ │                                                          │  │
│ │  ── Saved ──                                             │  │
│ │  [High-value open deals ▾] [Apply] [💾 Save current]    │  │
│ │                                                          │  │
│ │  [Apply filters]  [Clear all]  [Edit as QL]              │  │
│ └──────────────────────────────────────────────────────────┘  │
│                                                              │
│ Showing 42 results                                           │
└─────────────────────────────────────────────────────────────┘
```

**Key UI behaviors:**

- **Field select:** A searchable dropdown (Tom Select) organized by groups: "Direct fields", then one group per association ("Company", "Contact"). Nested association fields are shown with a breadcrumb path: "Company → Country → Name".
- **Operator select:** Updates dynamically when a field is selected. Only shows operators valid for the field's type. Defaults to the most common operator for the type (`cont` for string, `eq` for enum, `gteq` for date).
- **Value input:** Adapts to field type and operator:
  - String → text input
  - Enum → dropdown with values
  - Boolean → no input (operator is sufficient: "is true" / "is false")
  - Date → date picker
  - Datetime → datetime picker
  - Numeric → number input with step
  - `in` / `not_in` on enum → multi-select dropdown with checkboxes (Tom Select)
  - `in` / `not_in` on string/integer → textarea with comma/semicolon/newline splitting (`split(/\s*[,;\n]\s*/)`). Supports pasting from spreadsheets (semicolons) and manual entry (commas). Placeholder: "Enter values separated by commas or one per line".
  - `in` / `not_in` on association FK → multi-select with remote search (Tom Select)
  - `between` on date/datetime/numeric → two side-by-side inputs (from + to): `[expected_close_date ▾] [between ▾] [2024-01-01] — [2024-03-31] [×]`
  - `last_n_days` → numeric input for N value
  - `this_week` / `this_month` / `this_quarter` / `this_year` → no input (self-contained)
  - Null/present/blank operators → no input shown
- **OR groups:** A visually nested container with its own add/remove. Groups combine conditions with OR; groups themselves combine with AND at the top level.
- **Remove (×):** Removes a single condition row or an entire group.
- **Apply:** Submits the filter form (GET request). All state is in URL params.
- **Clear all:** Resets to no filters.
- **Edit as QL:** Toggles a textarea with the current filter serialized as QL text. Changes in QL parse back to the visual builder on "Apply".

**JavaScript module:** `app/assets/javascripts/lcp_ruby/advanced_filter.js`

The filter builder is a standalone JavaScript module (no framework dependency, consistent with the platform's Stimulus-lite approach). It receives metadata via a JSON `data-` attribute on the container element:

```json
{
  "fields": [
    { "name": "title", "label": "Title", "type": "string", "operators": ["eq","cont","start","end","present","blank"] },
    { "name": "stage", "label": "Stage", "type": "enum", "operators": ["eq","not_eq","in","not_in"], "values": [["lead","Lead"],["qualified","Qualified"]] },
    { "name": "company.name", "label": "Company → Name", "type": "string", "group": "Company", "operators": ["eq","cont","start"] }
  ],
  "operatorLabels": { "eq": "equals", "cont": "contains", ... },
  "noValueOperators": ["present", "blank", "null", "not_null", "true", "not_true", "false", "not_false"],
  "multiValueOperators": ["in", "not_in"],
  "presets": [ { "name": "high_value_open", "label": "High-value open deals", "conditions": [...] } ],
  "savedFilters": [ { "id": 1, "name": "My Q1 pipeline", "conditions": [...] } ],
  "currentFilters": { ... },
  "qlEnabled": true
}
```

### 11. Interaction with Existing Features

#### Quick text search (`?qs=`)

The quick text search is renamed from `?q=` to `?qs=` to avoid namespace collision with Ransack's `?f[...]` params (see Section 5). It remains a text input that builds OR conditions across `searchable_fields`. It is additive — applied on top of advanced filter results. This means a user can have both an advanced filter active and a text search narrowing the results further.

**Type-aware matching improvements** (inspired by basepack's `Utils.query` algorithm):

The current `apply_search` builds `LIKE '%term%'` for all fields regardless of type. The improved implementation handles each field type appropriately:

| Field Type | Behavior |
|-----------|----------|
| `string`, `text` | `LIKE '%term%'` (unchanged) |
| `integer` | `column = integer_value` only if term parses as integer; **skip** otherwise |
| `float`, `decimal` | `column = float_value` only if term parses as numeric; skip otherwise |
| `boolean` | Match if term is truthy (`true`, `1`, `t`, `yes`) or falsy (`false`, `0`, `f`, `no`); skip otherwise |
| `date` | Parse as date; if valid, `column = parsed_date`; skip otherwise |
| `datetime` | Parse with **precision auto-detection**: date-only input ("2024-01-15") matches the whole day (`column >= day_start AND column < next_day`); time input matches the whole minute |
| `enum` | Collect enum values where the **stored value** matches OR the **display label** contains the query (case-insensitive). Use `column IN (matched_values)` |

**Additional improvements:**
- **`default_query` escape hatch:** If the model defines `self.default_query(term)`, call it instead of building automatic conditions. This allows models to override quick search entirely (useful for complex JOINs or external search integration).
- **Boolean normalization:** Recognize `"t"`, `"true"`, `"1"`, `"yes"` as truthy; `"f"`, `"false"`, `"0"`, `"no"` as falsy (case-insensitive).
- **Empty/blank rejection:** Strip and reject blank query params before processing. An empty `?qs=` produces no filter (not `WHERE field = ''`).
- **Empty result on no match:** If the query is non-empty but no conditions were generated (e.g., "hello" with only integer fields), return `scope.none` instead of all records.

#### Predefined filter buttons (`?filter=`)

Unchanged. The buttons remain above the filter builder. When a predefined filter is active, it applies its scope and the filter builder operates on the scoped result set. Predefined filters are mutually exclusive (clicking one replaces the other).

#### Sorting (`?sort=`, `?direction=`)

Unchanged. Sorting is independent of filtering. Ransack's `s` parameter can also be used for sorting (e.g., `?f[s]=value+desc`), and the two should be reconciled — the platform's sort params take precedence if both are present.

#### Eager loading

The `IncludesResolver` already detects associations used in the presenter. Association-based filters introduce additional JOINs that Ransack generates. These JOINs are separate from eager loading and do not conflict — Ransack adds JOINs for filtering, `IncludesResolver` adds `includes` for N+1 prevention on display.

#### Pagination

Pagination applies after filtering. The page count updates to reflect filtered results. When a filter is applied, the page resets to 1.

#### Permission checks

The `PermissionEvaluator` is passed as `auth_object` to Ransack. Dynamic `ransackable_attributes` and `ransackable_associations` ensure that:
- Fields the user cannot read are excluded from filter options.
- Attempting to filter on a non-readable field via URL manipulation returns no results (Ransack ignores unknown attributes).
- Association paths are permission-checked at each level.

#### Custom fields

Custom fields appear in the filter dropdown under a separate group ("Custom Fields"). They use the `?cf[...]` param namespace and are processed outside Ransack via `CustomFieldFilter`.

#### Summary columns

Summary columns (sum, avg, count) are computed on the filtered result set, not the full dataset. This is already the case in the current implementation.

### 12. Edge Cases & Pitfalls

#### Duplicate rows from has_many JOINs

When filtering on a `has_many` association (e.g., "deals where any contact has email containing 'john'"), the JOIN produces one row per matching contact. Without `DISTINCT`, a deal with 3 matching contacts appears 3 times.

**Solution:** Always use `.result(distinct: true)`. This adds `SELECT DISTINCT` which deduplicates. The performance cost of `DISTINCT` is acceptable for filtered result sets.

**Caveat:** `DISTINCT` combined with `ORDER BY` on a non-selected column can fail in PostgreSQL. Ransack handles this by adding the sort column to the SELECT.

#### Ambiguous column names in JOINs

Multiple JOINs can introduce table aliases. Sorting by `name` when both the main model and a joined model have a `name` column is ambiguous.

**Solution:** Ransack qualifies all column references with table names (`deals.name`, `companies.name`). The platform should ensure that presenter sort configuration also uses qualified names when associations are joined.

#### Empty string vs NULL

Users may be confused by the difference between "is blank" (NULL or empty string) and "is null" (only NULL). The UI should use clear labels: "is empty" for blank (NULL or ""), "has no value" for null.

#### Date/datetime timezone handling

Date filters should use the application's configured timezone. Ransack passes date strings to ActiveRecord which handles timezone conversion. The UI date picker should display dates in the user's timezone.

#### Enum value display vs storage

Enum fields store machine values (`closed_won`) but display human labels (`Closed Won`). The filter dropdown should show human labels, but the filter value sent to Ransack must be the machine value.

#### Boolean fields with NULL

A boolean field can have three states: true, false, NULL. The operators "is true" and "is false" check only the stored value. "is null" checks for records where the boolean was never set. "is blank" in Ransack treats false as blank for booleans, which is counterintuitive — the UI should not offer "is blank" for boolean fields.

#### URL length limits

Complex filters with many conditions can produce very long URLs. Browsers typically support 2000–8000 characters. With 20 conditions, each ~80 characters, the URL is ~1600 characters — within limits. The `max_conditions` setting prevents exceeding this.

**Future option:** For very complex filters, a POST-based filter submission with a redirect to a short filter token URL. Not needed for the initial implementation.

#### Race conditions with saved filters

A saved filter references field names and scopes. If a model's YAML is updated (field renamed, scope removed), a saved filter may reference invalid fields. The filter application should silently ignore unknown fields/operators (log a warning in development) rather than crashing.

#### Self-referential associations

A model like `employee` with `belongs_to :manager, target_model: employee` creates a self-join. Ransack handles this with table aliasing, but the filter UI must clearly distinguish "Employee → Manager → Name" from "Employee → Name".

#### Polymorphic associations

Polymorphic `belongs_to` associations (`commentable_type`, `commentable_id`) cannot be traversed by Ransack because the target model is unknown at query time. The filter builder should exclude polymorphic associations.

#### Empty filter params

Empty-string values in filter params (e.g., `?f[title_cont]=`) must be stripped before passing to Ransack. Without this, Ransack generates `WHERE title LIKE '%%'` or `WHERE title = ''` instead of ignoring the condition. The `build_ransack_params` method rejects blank values early in the pipeline.

#### Boolean value normalization

Boolean values arrive from URL params in many formats: `"t"`, `"true"`, `"1"`, `"yes"`, `true`. The filter param builder normalizes all truthy representations (`true`, `1`, `t`, `yes` — case-insensitive) and falsy representations (`false`, `0`, `f`, `no`) before passing to Ransack. Without this, a checkbox value `"t"` is not recognized as `true`.

## Implementation Plan

**Phase rationale:**
- **Phase 0 first** because the `?q` → `?qs` rename is a prerequisite for introducing Ransack params without breaking existing search. Quick search improvements are low-risk and immediately useful.
- **Phases 1+2 merged association filtering** because it is deeply coupled with the Ransack foundation (`ransackable_associations`) and with the UI (grouped field selector). Shipping it as a separate phase would deliver an incomplete feature.
- **Phase 3 combines custom fields + saved filters** because both are storage-layer features (JSON queries, DB model) that build on the core filter infrastructure without needing each other.
- **Phase 4 (QL) is last** because it has the lowest user impact relative to effort and depends on all other phases being stable.

### Phase 0: Quick Search Improvements + Param Namespace Fix (**Implemented** — commit `0617933`)
1. Rename quick search param from `?q=` to `?qs=` in views and controller
2. Implement type-aware quick search (numeric skip, datetime precision, enum label matching, boolean normalization, empty param rejection)
3. Add `default_query` model escape hatch for quick search override
4. Update tests for renamed param and improved type handling

### Phase 1: Ransack Foundation + Custom Filter Methods (**Implemented** — commit `0617933`)
5. Install Ransack allowlisting on dynamic models (`ransackable_attributes`, `ransackable_associations`, `ransackable_scopes`) using `?f[...]` param namespace
6. Refactor `apply_search` to `apply_advanced_search` with backward compatibility
7. Implement `Search::OperatorRegistry` with type-operator mapping (including `between`, relative date operators)
8. Implement `Search::FilterParamBuilder` to convert filter state to Ransack params (with relative date expansion and `between` expansion)
9. Implement custom `filter_*` method detection and interception before Ransack
10. Extend `PresenterDefinition` to parse `advanced_filter` config
11. Extend `ConfigurationValidator` for new search keys

### Phase 2: Visual Filter Builder + Association Filtering (**Implemented**)
12. Create `_advanced_filter.html.erb` partial with toggle button and filter count badge
13. Implement `advanced_filter.js` — dynamic filter rows, field/operator/value selects, URL round-trip parsing
14. Implement value input variants: date picker, enum dropdown (Tom Select), textarea for `in`/`not_in`, numeric input, date range ("between"), no-value operators, parameterized inputs (`last_n_days`)
15. Integrate Tom Select for field selection and enum/association value selection
16. Implement `Search::FilterMetadataBuilder` — permission-aware field/operator/type metadata generation for the JS filter builder, with association traversal, custom type resolution, and field_options overrides
17. Implement grouped field selector in UI (direct fields, association groups with optgroups)
18. Add i18n keys for operator labels and UI strings (Rails locale + JS bridge via `i18n.js.erb`)
19. Add CSS styles for filter builder (rows, groups, between inputs, combinators, count badge)
20. Unit tests (`filter_metadata_builder_spec.rb`) and integration tests (`advanced_search_spec.rb`)

### Phase 3: Custom Field Filtering + Saved Filters
20. Implement `Search::CustomFieldFilter` for JSON column queries
21. Add `filterable` attribute to `CustomFieldDefinition`
22. Integrate custom fields into the filter dropdown
23. Create `SavedFilter` model + generator
24. Add save/load/delete UI in filter builder
25. Implement YAML presets loading
26. Add sharing/scoping by role

### Phase 4: Query Language
27. Implement `Search::QueryLanguageParser` (recursive descent)
28. Implement `Search::QueryLanguageSerializer` (AST → text)
29. Add QL toggle in filter UI with bidirectional conversion
30. Add relative date functions to QL (`{today}`, `{this_month}`, etc.)
31. Error display for QL parse failures

## Test Plan

### Unit Tests

- `spec/lib/lcp_ruby/search/operator_registry_spec.rb` — operator-type mapping, label lookup, i18n, relative date operators
- `spec/lib/lcp_ruby/search/filter_param_builder_spec.rb` — condition tree → Ransack params conversion, `between` expansion, relative date expansion
- `spec/lib/lcp_ruby/search/custom_filter_method_spec.rb` — `filter_*` detection, interception, security (return type validation)
- `spec/lib/lcp_ruby/search/quick_search_spec.rb` — type-aware matching (numeric skip, datetime range, enum labels, boolean normalization, empty rejection)
- `spec/lib/lcp_ruby/search/query_language_parser_spec.rb` — QL parsing (valid expressions, error cases, edge cases)
- `spec/lib/lcp_ruby/search/query_language_serializer_spec.rb` — AST → QL text round-trip
- `spec/lib/lcp_ruby/search/custom_field_filter_spec.rb` — JSON column query generation (PostgreSQL + SQLite)
- `spec/lib/lcp_ruby/metadata/presenter_definition_spec.rb` — advanced_filter config parsing
- `spec/lib/lcp_ruby/model_factory/builder_spec.rb` — ransackable_attributes/associations/scopes

### Integration Tests

- `spec/integration/advanced_search_spec.rb`:
  - Filter by direct field with each operator type
  - Filter by belongs_to association field (1 level)
  - Filter by multi-level association (N levels)
  - Filter by enum field with dropdown values
  - Filter with OR groups
  - Filter with predefined scope + advanced filter combined
  - Quick text search + advanced filter combined (verify `?qs=` param works)
  - Permission-restricted fields not filterable
  - Custom `filter_*` method interception
  - Custom field filtering
  - Saved filter create/load/delete
  - Relative date operators (this_month, last_n_days, etc.)
  - "Between" operator with date ranges
  - QL parse → apply → verify results
  - Edge cases: empty results, NULL values, boolean fields, date ranges, empty params
  - URL bookmarkability: apply filter, copy URL, load in new session
  - Type-aware quick search: numeric query on mixed fields, date precision, enum label matching

### Fixtures

- `spec/fixtures/integration/advanced_search/` — models with various field types, associations at multiple levels, scopes, permissions with restricted fields
