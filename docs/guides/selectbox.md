# Selectbox Guide

This guide covers all select input types available in LCP Ruby: basic association selects, cascading (dependent) selects, remote search, multi-select, tree select, and advanced options like scoping, disabled items, and legacy record handling.

For the full attribute reference, see the [Presenters Reference](../reference/presenters.md). For the requirements checklist, see [Selectbox Requirements](../requirements/selectbox.md).

---

## Association Select

The most common select type. Renders a dropdown for `belongs_to` associations, populated from the target model's records.

**YAML:**

```yaml
form:
  sections:
    - title: "Details"
      columns: 2
      fields:
        - field: company_id
          input_type: association_select
          input_options:
            sort: { name: asc }
            label_method: name
            include_blank: "Select company..."
```

**DSL:**

```ruby
form do
  section "Details", columns: 2 do
    field :company_id, input_type: :association_select,
      input_options: { sort: { name: :asc }, label_method: :name, include_blank: "Select company..." }
  end
end
```

### Options Summary

| Option | Type | Description |
|--------|------|-------------|
| `include_blank` | boolean/string | Blank option text. Default: `"-- Select --"`. Set `false` to remove |
| `sort` | hash | Ordering hash, e.g. `{ name: asc }` |
| `label_method` | string | Method called on each record for display text. Default: `to_label` |
| `scope` | string | Named scope on the target model (e.g. `"active"`) |
| `filter` | hash | Static where-conditions, e.g. `{ status: "active" }` |
| `group_by` | string | Group options into `<optgroup>` by this field |
| `max_options` | integer | Maximum options returned (default: 1000) |

---

## Cascading (Dependent) Selects

Use `depends_on` to create cascading select chains. When the parent field changes, the child select options are refreshed via AJAX through the `select_options` endpoint.

### Two-Level Cascade

**YAML (Country -> Region):**

```yaml
form:
  sections:
    - title: "Address"
      columns: 2
      fields:
        - field: country_id
          input_type: association_select
          input_options:
            scope: active
            sort: { name: asc }

        - field: region_id
          input_type: association_select
          input_options:
            depends_on:
              field: country_id
              foreign_key: country_id
            sort: { name: asc }
```

**DSL:**

```ruby
section "Address", columns: 2 do
  field :country_id, input_type: :association_select,
    input_options: { scope: "active", sort: { name: :asc } }

  field :region_id, input_type: :association_select,
    input_options: {
      depends_on: { field: :country_id, foreign_key: :country_id },
      sort: { name: :asc }
    }
end
```

### Three-Level Cascade

Chains can be arbitrarily deep. Each level declares its parent via `depends_on`:

```yaml
# Region -> City -> District
- field: region_id
  input_type: association_select
  input_options:
    sort: { name: asc }

- field: city_id
  input_type: association_select
  input_options:
    depends_on:
      field: region_id
      foreign_key: region_id
    sort: { name: asc }

- field: district_id
  input_type: association_select
  input_options:
    depends_on:
      field: city_id
      foreign_key: city_id
    sort: { name: asc }
```

### depends_on Options

| Key | Type | Description |
|-----|------|-------------|
| `field` | string | Parent field name in the same form |
| `foreign_key` | string | FK column on the target model to filter by |
| `reset_strategy` | string | `"clear"` (default) or `"keep_if_valid"` — what happens to the current value when parent changes |

### How It Works

1. The form renders `data-lcp-depends-on` and `data-lcp-depends-fk` HTML attributes on the child select
2. JavaScript listens for changes on the parent field
3. On change, it calls `GET /:slug/select_options?field=city_id&depends_on[region_id]=42`
4. The controller builds a filtered query via `AssociationOptionsBuilder` and returns JSON
5. The child select is repopulated with the filtered options

When no parent value is selected, the child select shows all available options.

---

## Remote Search

For large datasets (hundreds or thousands of records), enable server-side search to avoid loading all options upfront. This uses Tom Select with remote AJAX search.

```yaml
- field: city_id
  input_type: association_select
  input_options:
    search: true
    search_fields: [name]
    per_page: 20
    min_query_length: 1
    sort: { name: asc }
    label_method: name
```

**DSL:**

```ruby
field :city_id, input_type: :association_select,
  input_options: {
    search: true,
    search_fields: ["name"],
    per_page: 20,
    min_query_length: 1,
    sort: { name: :asc },
    label_method: :name
  }
```

| Option | Type | Description |
|--------|------|-------------|
| `search` | boolean | Enable remote search mode |
| `search_fields` | array | Fields to search against (LIKE query) |
| `per_page` | integer | Results per page (default: 25, max: 100) |
| `min_query_length` | integer | Minimum characters before search triggers (default: 1) |

### Combining Search with Cascading

Search and `depends_on` work together. The child select uses remote search, and results are filtered by the parent's value:

```ruby
field :city_id, input_type: :association_select,
  input_options: {
    depends_on: { field: :region_id, foreign_key: :region_id },
    search: true,
    search_fields: ["name"],
    per_page: 20,
    min_query_length: 1,
    sort: { name: :asc },
    label_method: :name
  }
```

---

## Scoping Options

### Static Scope

Apply a named scope on the target model to filter available options:

```yaml
- field: contact_id
  input_type: association_select
  input_options:
    scope: active_contacts
    sort: { last_name: asc }
```

The target model must define this scope:

```yaml
# config/lcp_ruby/models/contact.yml
model:
  name: contact
  scopes:
    - name: active_contacts
      where: { status: active }
```

### Static Filter

For simple field-value filtering without defining a scope:

```yaml
- field: company_id
  input_type: association_select
  input_options:
    filter: { status: "active", country: "CZ" }
```

### Role-Based Scope

Apply different scopes depending on the current user's role:

```yaml
- field: company_id
  input_type: association_select
  input_options:
    scope_by_role:
      admin: all
      editor: active_companies
      viewer: my_companies
```

The special value `"all"` means no scope is applied (returns all records). When `scope_by_role` is present, the `scope` option is ignored.

---

## Disabled Options

Show certain options in the dropdown but prevent their selection (greyed out).

### By Scope

```yaml
- field: city_id
  input_type: association_select
  input_options:
    disabled_scope: small_cities
    sort: { name: asc }
```

Records returned by the `small_cities` scope appear in the dropdown but cannot be selected.

### By ID List

```yaml
- field: category_id
  input_type: association_select
  input_options:
    disabled_values: [1, 5, 12]
```

Both `disabled_scope` and `disabled_values` can be combined.

---

## Legacy Scope (Archived Records)

When editing a record that references an archived/deactivated option, the dropdown should still display that option (so the user sees what was selected) but mark it as disabled. Without this, the current value would silently disappear from the dropdown.

```yaml
- field: country_id
  input_type: association_select
  input_options:
    scope: active
    legacy_scope: with_archived
    sort: { name: asc }
```

**How it works:**

1. The select is populated using the `active` scope (only active records)
2. On edit, if the record's current `country_id` is not in the active options, the system looks it up using the `with_archived` scope
3. If found, the archived record is injected into the options as a disabled entry

This ensures historical data integrity — users see which value was selected, but cannot select archived values for new records.

---

## Grouped Options

Group options into `<optgroup>` sections by a field value:

```yaml
- field: company_id
  input_type: association_select
  input_options:
    group_by: industry
    sort: { name: asc }
```

This renders options grouped by the `industry` field of the company model (e.g., "Technology", "Finance", "Healthcare"), each group containing alphabetically sorted companies.

---

## Inline Create

Allow users to create a new target record directly from the select dropdown, without navigating away:

```yaml
- field: country_id
  input_type: association_select
  input_options:
    allow_inline_create: true
    scope: active
    sort: { name: asc }
    label_method: name
```

When enabled, the select dropdown shows a "Create new..." option. Clicking it opens a modal form for the target model. After saving, the new record is automatically selected.

---

## Multi-Select

For `has_many :through` associations, use `multi_select` to allow selecting multiple values:

```yaml
- field: tag_ids
  input_type: multi_select
  input_options:
    association: tags
    scope: active
    sort: { name: asc }
    label_method: name
    min: 1
    max: 5
```

**DSL:**

```ruby
field :skill_ids, input_type: :multi_select,
  input_options: { sort: { name: :asc }, label_method: :name, max: 5 }
```

| Option | Type | Description |
|--------|------|-------------|
| `association` | string | Name of the `has_many :through` association |
| `scope` | string | Named scope on the target model |
| `sort` | hash | Ordering for options |
| `label_method` | string | Method for display text |
| `min` | integer | Minimum required selections |
| `max` | integer | Maximum allowed selections |
| `display_mode` | string | Visual mode for selected items |

---

## Tree Select

For self-referential (hierarchical) models, use `tree_select` to render a collapsible tree dropdown:

```yaml
- field: department_id
  input_type: tree_select
  input_options:
    parent_field: parent_id
    label_method: name
    max_depth: 3
    sort: { name: asc }
```

**DSL:**

```ruby
field :department_id, input_type: :tree_select,
  input_options: { parent_field: :parent_id, label_method: :name, max_depth: 3 }
```

| Option | Type | Description |
|--------|------|-------------|
| `parent_field` | string | Field name for the parent reference (default: `"parent_id"`) |
| `label_method` | string | Method for display text |
| `max_depth` | integer | Maximum tree depth to render (default: 10) |
| `sort` | hash | Ordering within each level |
| `include_blank` | string/boolean | Blank option text |

---

## Codelists

A codelist (lookup table, reference data) in LCP Ruby is simply a **normal model** accessed via `association_select`. There is no special codelist concept — any model can serve as a codelist.

### Typical Codelist Model

```yaml
# config/lcp_ruby/models/country.yml
model:
  name: country
  fields:
    - { name: code, type: string, validations: [{ type: presence }, { type: uniqueness }] }
    - { name: name, type: string, validations: [{ type: presence }] }
    - { name: active, type: boolean, default: true }
  options:
    positioning: true
    soft_delete: true
  label_method: name
  scopes:
    - name: active
      where: { active: true }
    - name: with_archived
      where_not: { discarded_at: null }
```

### Using a Codelist in a Form

```yaml
- field: country_id
  input_type: association_select
  input_options:
    scope: active              # only show active entries
    legacy_scope: with_archived # preserve archived values on edit
    sort: { position: asc }    # custom ordering via positioning
    label_method: name
```

### Key Patterns for Codelists

| Need | Solution |
|------|----------|
| Only show active entries | `scope: active` |
| Preserve historical values | `legacy_scope: with_archived` |
| Custom sort order | `positioning: true` + `sort: { position: asc }` |
| Deactivate without deleting | `soft_delete: true` or `active` boolean field |
| Hierarchical codelist | `tree` model option + `tree_select` input type |
| Cascading codelists | `depends_on` on each level |
| Role-based visibility | `scope_by_role` |
| Disable specific entries | `disabled_scope` or `disabled_values` |

---

## Complete Example

This example from the CRM app demonstrates most features together — cascading selects with scoping, legacy records, inline create, remote search, and disabled options:

```ruby
section "Address", columns: 2 do
  field :country_id, input_type: :association_select,
    input_options: {
      scope: "active",
      legacy_scope: "with_archived",
      sort: { name: :asc },
      allow_inline_create: true,
      label_method: :name
    }

  field :region_id, input_type: :association_select,
    input_options: {
      depends_on: { field: :country_id, foreign_key: :country_id },
      sort: { name: :asc },
      label_method: :name
    }

  field :city_id, input_type: :association_select,
    input_options: {
      depends_on: { field: :region_id, foreign_key: :region_id },
      search: true,
      search_fields: ["name"],
      per_page: 20,
      min_query_length: 1,
      sort: { name: :asc },
      disabled_scope: "small_cities",
      label_method: :name
    }
end
```

This creates a 3-level cascade (Country -> Region -> City) where:
- Countries are filtered to active, with archived values preserved on edit, and inline create enabled
- Regions are filtered by the selected country
- Cities are filtered by the selected region, use remote search (for potentially large datasets), and small cities are shown but disabled
