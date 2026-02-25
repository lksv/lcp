# Design: Inline Collection Editor

**Status:** Implemented (Phases 1–5)
**Date:** 2026-02-25

## Problem

The platform has three distinct mechanisms for editing "a list of structured items," each implemented separately:

1. **Nested association forms** (`type: nested_fields`, `association:`) — for editing has_many child records inline. Fully dynamic, driven by presenter metadata, backed by `accepts_nested_attributes_for`. Limitation: child records must be a separate model + DB table.

2. **Custom fields manage page** — a hardcoded bulk editor for editing all custom field definitions in one form. The template manually enumerates every field (field_name, custom_type, label, constraints, display options, etc.) instead of rendering from presenter metadata. Adding/removing a model field requires manual template changes.

3. **JSON columns** — `type: json` fields can store structured data (array of hashes), but there is no form input for editing them as a collection of items. They render as raw text/textarea.

These three are conceptually the same UI pattern: **an inline list of items where each item has fields defined by metadata, with add/remove/reorder support and per-field conditional visibility**. Yet each is implemented independently, with varying levels of dynamism.

### Concrete Pain Points

- The custom fields manage page has hand-written HTML that duplicates the presenter's form config. Every model change requires manual template changes.
- JSON columns storing structured data (workflow steps, rule conditions, address lists) cannot be edited as forms — users must type raw JSON.
- Conditional visibility (`visible_when`) works in standard forms and at the section level in nested fields, but not at the field level inside nested rows.
- The platform has no general pattern for "configurator screens" — admin UIs that edit arrays of configuration objects (custom fields, workflow steps, permission rules, notification templates).

## Goals

- **Unified rendering**: One template pipeline that renders a row of fields from presenter metadata, reusable across all three contexts (association, JSON column, bulk records).
- **Field-level conditions in nested rows**: `visible_when` / `disable_when` working inside each row, evaluated against that row's data.
- **JSON collection editing**: A new `json_field:` source for `nested_fields` that stores items as a JSON array of hashes.
- **Model-backed item definitions**: JSON collection items can reference a target model for full field metadata (types, validations, transforms, custom types). Item fields are defined as virtual fields with `source: { service: "json_field" }`, reusing the existing accessor service. This gives JSON items the same field-level capabilities as DB-backed models without requiring a separate table.
- **Dynamic manage page**: The custom fields manage page becomes fully presenter-driven, with zero hardcoded field HTML.
- **Configurator reusability**: The infrastructure supports future configurator screens (workflow step editor, permission rule editor, notification template editor) without per-feature template work.

## Non-Goals

- Scalar array editing (`["tag1", "tag2"]`) — covered by the [Array Field Type](array_field_type.md) design.
- Deeply nested structures (arrays of arrays, trees) — use `type: json` with custom renderers.
- Real-time collaborative editing.
- Inline editing in index tables (different UX pattern).

## Background: Current Nested Fields Architecture

The existing `nested_fields` section type processes data through three layers:

```
Presenter (YAML/DSL)
  → LayoutBuilder.normalize_nested_section()
    → resolves target model, enriches fields with FieldDefinition objects
  → _form_section.html.erb (nested_fields branch)
    → form.fields_for :association, iterates records
    → renders each row via _nested_fields.html.erb
  → _nested_fields.html.erb
    → flat field iteration, render_form_input() per field
    → drag handle, position hidden field, _destroy + remove button
  → nested_forms.js
    → add row (clone template), remove row (_destroy flag), drag-drop reorder
```

**Key limitation:** `_nested_fields.html.erb` has no `visible_when`/`disable_when` support — it renders all fields unconditionally. The standard form field rendering pipeline (`_form_section.html.erb` lines 100-134) supports conditions, but `_nested_fields.html.erb` skips this entirely.

## Design

### Core Concept: Three Data Sources, One Renderer

The existing `nested_fields` section type is extended to support three data sources. The rendering pipeline is identical for all three — only the data loading, form naming, and persistence differ.

| Source | Data Origin | Form Naming | Persistence |
|--------|------------|-------------|-------------|
| `association:` | has_many records | `record[items_attributes][N][field]` | `accepts_nested_attributes_for` |
| `json_field:` (inline) | JSON column value | `record[steps][N][field]` | JSON array in single column |
| `json_field:` + `target_model:` | JSON column value | `record[addresses][N][field]` | JSON array, model-backed field defs |
| *bulk records* | DB query | `definitions[N][field]` | Custom controller logic |

The renderer (template + JS) does not care about the source. It receives:
- A form builder object (for generating inputs)
- A section hash with enriched field configs (from LayoutBuilder)
- The current item/record (for condition evaluation)

### 1. Enhanced Nested Row Rendering

Extend `_nested_fields.html.erb` to support the full field rendering pipeline that `_form_section.html.erb` already has. Currently nested rows skip:

| Feature | Standard form | Nested row (current) | Nested row (proposed) |
|---------|--------------|---------------------|----------------------|
| `visible_when` per field | Yes | No | **Yes** |
| `disable_when` per field | Yes | No | **Yes** |
| `col_span` | Yes | No | **Yes** |
| `hint` | Yes | No | **Yes** |
| `prefix`/`suffix` | Yes | No | **Yes** |
| `readonly` | Yes | No | **Yes** |
| `data-lcp-conditional` attrs | Yes | No | **Yes** |
| Pseudo-fields (info, divider) | Yes | No | Optional |

The key addition is `data-lcp-condition-scope` on each row `<div>`, which tells the conditional rendering JS to scope field lookups to the current row instead of the entire form.

### 2. Row-Scoped Conditional Rendering (JS)

**Problem:** The current `getFieldValue(form, fieldName)` searches the entire `<form>` by `[name$="[fieldName]"]`. When multiple nested rows exist, this matches ALL rows' fields with that name.

**Solution:** When evaluating conditions for an element inside `[data-lcp-condition-scope]`, scope the field lookup to that container.

```
// Pseudocode for applyConditions():
for each [data-lcp-conditional] element:
  scope = element.closest('[data-lcp-condition-scope]') || form
  fieldValue = getFieldValue(scope, conditionFieldName)
  // evaluate and apply visibility/disabled state
```

This is fully backward-compatible: standard forms have no `[data-lcp-condition-scope]`, so scope falls back to the entire form. All existing forms continue to work identically.

After cloning a new row (add button), the JS dispatches a synthetic `change` event to trigger initial condition evaluation for the new row.

### 3. JSON Field Source (`json_field:`)

A new alternative to `association:` for `nested_fields` sections. Items are stored as a JSON array of hashes in a single column. There are two modes: **inline field definitions** and **model-backed field definitions**.

#### 3a. Inline Mode — Fields Declared in Presenter

For simple, ad-hoc structures where creating a full model is overkill. Field types and labels are declared directly in the section config:

```yaml
# YAML — inline field definitions
form:
  sections:
    - title: "Workflow Steps"
      type: nested_fields
      json_field: steps
      sortable: true
      allow_add: true
      allow_remove: true
      columns: 2
      fields:
        - field: name
          type: string
          label: "Step Name"
        - field: action_type
          type: string
          input_type: select
          input_options:
            values: [review, approve, notify]
        - field: timeout_days
          type: integer
          label: "Timeout (days)"
          visible_when:
            field: action_type
            operator: eq
            value: review
```

```ruby
# DSL — inline
form do
  nested_fields "Workflow Steps", json_field: :steps,
    sortable: true, allow_add: true, allow_remove: true, columns: 2 do
    field :name, type: :string, label: "Step Name"
    field :action_type, type: :string, input_type: :select,
      input_options: { values: %w[review approve notify] }
    field :timeout_days, type: :integer, label: "Timeout (days)",
      visible_when: { field: :action_type, operator: :eq, value: "review" }
  end
end
```

LayoutBuilder creates synthetic `FieldDefinition` objects from the inline declarations. No target model needed.

#### 3b. Model-Backed Mode — Fields from a Virtual Model

For complex, reusable structures that benefit from full field metadata: validations, transforms, custom types, enums. The item structure is defined as a model whose fields use the existing `source: { service: "json_field" }` accessor to map each property to a key in the JSON hash.

**Item model definition:**

```yaml
# config/lcp_ruby/models/address.yml
name: address
table_name: _virtual   # no real table — all fields are virtual
fields:
  - name: street
    type: string
    source: { service: json_field, options: { key: street } }
    validations:
      - type: presence
  - name: street_number
    type: integer
    source: { service: json_field, options: { key: street_number } }
  - name: city
    type: string
    source: { service: json_field, options: { key: city } }
    validations:
      - type: presence
  - name: zip
    type: string
    source: { service: json_field, options: { key: zip } }
    validations:
      - type: format
        options: { with: "\\A\\d{3}\\s?\\d{2}\\z" }
  - name: country
    type: string
    source: { service: json_field, options: { key: country } }
    default: "CZ"
```

**Parent model:**

```yaml
# config/lcp_ruby/models/company.yml
name: company
fields:
  - name: name
    type: string
  - name: addresses
    type: json    # stores [{street: "...", city: "...", ...}, ...]
```

**Presenter — references the item model:**

```yaml
# config/lcp_ruby/presenters/companies.yml
form:
  sections:
    - title: "Addresses"
      type: nested_fields
      json_field: addresses
      target_model: address        # ← LayoutBuilder resolves field defs from this model
      allow_add: true
      allow_remove: true
      columns: 2
      fields:
        - field: street
        - field: street_number
        - field: city
        - field: zip
        - field: country
```

```ruby
# DSL
form do
  nested_fields "Addresses", json_field: :addresses, target_model: :address,
    allow_add: true, allow_remove: true, columns: 2 do
    field :street
    field :street_number
    field :city
    field :zip
    field :country
  end
end
```

#### How Model-Backed Mode Works

When `json_field:` + `target_model:` are both present, LayoutBuilder resolves field definitions from the target model — exactly the same path as `association:` uses in `normalize_nested_section`:

```ruby
def normalize_json_field_section(section)
  if section["target_model"]
    # Model-backed: resolve FieldDefinitions from target model
    target_def = LcpRuby.loader.model_definition(section["target_model"])
    fields = (section["fields"] || []).map do |f|
      field_def = target_def.field(f["field"])
      field_def ? f.merge("field_definition" => field_def) : nil
    end.compact
  else
    # Inline: create synthetic FieldDefinitions from inline type/label
    fields = (section["fields"] || []).map do |f|
      base_type = f["type"] || "string"
      f.merge("field_definition" => Metadata::FieldDefinition.new(
        name: f["field"], type: base_type,
        label: f["label"] || f["field"].to_s.humanize
      ))
    end
  end

  result = section.merge("fields" => fields, "target_model_definition" => target_def)
  result["sortable_field"] = resolve_sortable_field(section) if section["sortable"]
  result
end
```

**The item model fields are virtual** (all have `source:`), so the `SchemaManager` creates no DB table. The model exists purely for metadata — field types, labels, validations, transforms, enum values, custom types. The existing `json_field` accessor service handles get/set of individual properties within each hash item.

#### Benefits of Model-Backed vs. Inline

| Capability | Inline | Model-backed |
|-----------|--------|-------------|
| Field types & labels | Yes (manual) | Yes (from model) |
| Validations | No | Yes (model-level, per item) |
| Transforms (strip, downcase, normalize_url) | No | Yes |
| Custom types (email, phone, url, color) | No | Yes |
| Enum fields with named values | No | Yes |
| Default values | No | Yes |
| Reuse across multiple presenters | No | Yes (one model, many presenters) |
| No-config convenience | Yes | No (requires model YAML) |

The inline mode is for quick, simple structures. The model-backed mode is for domain objects that need proper validation and typing — the same items that would traditionally require a separate DB table and a `has_many` association.

#### Item Wrapping for Model-Backed Rows

Each JSON hash item must be wrapped in an object that responds to the model's getter/setter methods. The `json_field` accessor service already provides get/set by key — the wrapper makes each hash item behave like an ActiveModel record:

```ruby
# Conceptual wrapper — each hash item is wrapped for form rendering
class JsonItemWrapper
  include ActiveModel::Model

  def initialize(hash, model_definition)
    @data = hash.transform_keys(&:to_s)
    @model_definition = model_definition
  end

  # Dynamic getter/setter per field, delegates to @data hash
  # The json_field accessor service operates on @data instead of a DB record
end
```

The wrapper allows `form.text_field :street` to call `wrapper.street` → reads from hash. On submission, the controller collects the wrappers' data back into an array of hashes for JSON persistence.

#### Comparison: Three Sources Side by Side

| Aspect | `association:` | `json_field:` (inline) | `json_field:` + `target_model:` |
|--------|---------------|----------------------|-------------------------------|
| Field definitions | Target model (DB-backed) | Inline (type, label) | Target model (virtual) |
| LayoutBuilder | `normalize_nested_section` | `normalize_json_field_section` | `normalize_json_field_section` |
| Field metadata | Full (validations, types, transforms) | Minimal (type + label) | Full (validations, types, transforms) |
| Template row object | `assoc_reflection.klass.new` | `JsonItemWrapper.new(hash, nil)` | `JsonItemWrapper.new(hash, model_def)` |
| Item validation | Target model validations | None (or controller-level) | Target model validations (per item) |
| DB footprint | Separate table + FK column | JSON column only | JSON column only |
| Form builder | `form.fields_for :assoc` | `fields_for "record[field][N]"` | `fields_for "record[field][N]"` |

### 4. Controller: JSON Field Processing

The `ResourcesController` gets a `process_json_field_params` method that runs before save:

1. Detects `json_field` sections from the presenter
2. Parses the submitted hash-of-hashes into an array of hashes
3. Filters `_destroy` flagged items
4. For model-backed items: validates each item against the target model
5. Assigns the cleaned array to the JSON column

This processing is generic — it works for any model with any JSON column, driven entirely by presenter metadata.

### 5. Dynamic Manage Page

The custom fields manage page becomes fully presenter-driven by reusing the enhanced nested_fields rendering.

#### How It Works

The `custom_fields` presenter defines a complete `form` config with sections, fields, and `visible_when` conditions. The manage controller:

1. Calls `LayoutBuilder.form_sections` to get enriched section data
2. For each CFD record, renders a row using those sections
3. Each section renders with conditional visibility from the presenter
4. Fields use `render_form_input` — the same helper as standard forms
5. Submission goes to a `bulk_update` action

The manage page template becomes a generic iterator over LayoutBuilder data instead of hand-written field HTML.

#### Field Options Override

Some fields need controller-provided select options (e.g., `custom_type` enum values, `input_type` choices, `renderer` choices). The controller provides a `@manage_field_options` hash:

```ruby
{ "custom_type" => [...], "input_type" => [...], "renderer" => [...] }
```

The template checks this hash when rendering — if a field has controller-provided options and is a string/text type, it renders as a `<select>` instead of a text input. This override pattern is reusable for any configurator screen.

#### Section Rendering per Row

Each row renders all form sections from the presenter. For compact inline editing, the template can:
- Show the first section as a summary (always visible)
- Collapse subsequent sections with expand/toggle (existing JS)
- Respect section-level `visible_when` (e.g., "Text Constraints" section only visible when type is string/text)

### 6. Configurator Pattern

The infrastructure built here establishes a reusable pattern for configurator screens:

```
[Presenter defines form sections with fields and conditions]
       ↓
[LayoutBuilder enriches sections with FieldDefinitions]
  (from target model, inline declarations, or parent model)
       ↓
[Template iterates sections → fields, calls render_form_input]
       ↓
[JS handles add/remove/reorder, row-scoped conditional rendering]
       ↓
[Controller handles persistence (JSON column, bulk save, nested attrs)]
```

Future configurator examples:

| Configurator | Item Model | Persistence |
|-------------|-----------|-------------|
| Custom field definitions | `custom_field_definition` (DB-backed) | Bulk save |
| Workflow steps | `workflow_step` (virtual, `source: json_field`) | JSON column |
| Approval rules | `approval_rule` (virtual) | JSON column |
| Address list | `address` (virtual) | JSON column |
| Notification templates | DB records | Bulk save |
| Permission rules (if DB-backed) | DB records | Bulk save |
| Dashboard widget config | `widget_config` (virtual) | JSON column |

All use the same rendering pipeline. The only per-feature code is:
1. The item model definition (YAML) — field types, validations, transforms
2. The presenter section (YAML) — which fields to show, conditions, layout
3. For non-standard persistence: controller logic

## Reference Implementation

Branch `custom-fields--manage-all-as-nested` (commit `2822ab0`) contains a working prototype of the custom fields manage page with bulk editing. This prototype demonstrates the target UX and serves as a starting point for Phase 2.

**What to reuse from the prototype:**
- Controller actions `manage` and `bulk_update` — submission parsing, per-row validation, transactional save, error handling. This logic is largely correct and carries over.
- Route definitions (`manage` + `bulk_update` under `/:lcp_slug/custom-fields`).
- `manage.html.erb` layout — container structure, hidden template row for "Add", error display banner, Save/Cancel actions.
- JS row re-indexing (`reindexManageRows` in `custom_fields_manage.js`) — needed regardless of rendering approach.
- Expand/collapse UX pattern — summary row (field_name, type, label, required, active) + expandable detail panel.

**What the design replaces (hardcoded → presenter-driven):**
- `_manage_row.html.erb` (176 lines of hand-written HTML) → replaced by iterating over `LayoutBuilder.form_sections` with `render_form_input()` per field. Adding a model field to the presenter auto-updates the manage UI.
- Custom `data-cf-visible-types` attribute + `applyTypeVisibility()` JS → replaced by standard `visible_when` conditions from the presenter + row-scoped `conditional_rendering.js` (Phase 1).

**Key files in the prototype:**
| File | Reuse | Notes |
|------|-------|-------|
| `custom_fields_controller.rb` (`manage`, `bulk_update`) | Keep | Controller logic is generic enough |
| `manage.html.erb` | Keep structure | Replace row rendering with LayoutBuilder iteration |
| `_manage_row.html.erb` | Replace | This is the hardcoded HTML that Phase 2 eliminates |
| `custom_fields_manage.js` | Partial | Keep `reindexManageRows`, remove `applyTypeVisibility` |
| `nested_forms.js` additions | Keep | Add button + template cloning works for manage page too |

## Implementation Order

The implementation naturally decomposes into independent, incrementally shippable pieces:

### Phase 1: Row-scoped conditional rendering
- Enhance `_nested_fields.html.erb` with `visible_when`/`disable_when`, `col_span`, `hint`, `data-lcp-condition-scope`
- Add scope-aware logic to `conditional_rendering.js`
- Dispatch change events after row cloning in `nested_forms.js`
- **Value:** All existing nested_fields sections gain field-level conditions. No new features, just closing a gap.

### Phase 2: Dynamic manage page
- Start from the prototype in `custom-fields--manage-all-as-nested` (`2822ab0`) — keep controller logic and page layout, replace row rendering.
- Refactor the custom fields manage action to use LayoutBuilder for section/field metadata
- Rewrite the manage row partial to iterate over form sections dynamically
- Replace the custom `data-cf-visible-types` / `applyTypeVisibility()` with standard `visible_when` conditions from the presenter (depends on Phase 1's row-scoped conditional rendering)
- **Value:** Manage page becomes presenter-driven. Adding a field to the CFD model + presenter auto-updates the manage UI.

### Phase 3: JSON field source (inline mode)
- Add `json_field:` option to DSL and LayoutBuilder
- Add `normalize_json_field_section` to LayoutBuilder (inline field definitions)
- Extend `_form_section.html.erb` to handle `json_field` rendering
- Add `process_json_field_params` to ResourcesController
- **Value:** Any model with a JSON column can have structured inline editing with zero custom code.

### Phase 4: Model-backed JSON items
- Add `target_model:` option to `json_field:` sections
- LayoutBuilder resolves field definitions from target model (same as association path)
- `JsonItemWrapper` wraps hash items for form rendering and validation
- Extend `json_field` accessor service to work with item wrappers
- Per-item validation using target model's validations
- **Value:** JSON array items get full model-level capabilities: validations, transforms, custom types, enums, defaults.

### Phase 5: Sub-sections in nested rows
- Support `section` blocks inside `nested_fields` (sub-sections per row)
- Collapsible sub-sections for complex items (like the manage page's expand/collapse)
- **Value:** Complex configurator screens with 20+ fields per item get section grouping inside each row.

## Key Files

| File | Phase | Change |
|------|-------|--------|
| `app/views/lcp_ruby/resources/_nested_fields.html.erb` | 1 | Add visible_when, col_span, data-lcp-condition-scope |
| `app/assets/javascripts/lcp_ruby/conditional_rendering.js` | 1 | Scope-aware field lookup |
| `app/assets/javascripts/lcp_ruby/nested_forms.js` | 1 | Dispatch change event after clone |
| `app/controllers/lcp_ruby/custom_fields_controller.rb` | 2 | Use LayoutBuilder for manage action |
| Custom fields manage views (new) | 2 | Dynamic row partial iterating over form sections |
| `lib/lcp_ruby/dsl/presenter_builder.rb` | 3 | `json_field:` on nested_fields, inline type/label |
| `lib/lcp_ruby/presenter/layout_builder.rb` | 3 | `normalize_json_field_section` |
| `app/views/lcp_ruby/resources/_form_section.html.erb` | 3 | json_field branch |
| `app/controllers/lcp_ruby/resources_controller.rb` | 3 | `process_json_field_params` |
| `lib/lcp_ruby/metadata/configuration_validator.rb` | 3–4 | Validate json_field + target_model sections |
| `lib/lcp_ruby/services/accessors/json_field.rb` | 4 | Extend for item wrapper context |

## Relationship to Other Designs

- **[Array Field Type](array_field_type.md):** Covers scalar arrays (`type: array`, `item_type: string`). This design covers structured arrays (array of hashes). Complementary, no overlap.
- **[Model Options Infrastructure](model_options_infrastructure.md):** The JSON field processing in the controller follows the applicator pattern. Future features (workflow steps, approval rules) will be model options that use JSON field nested editing.
- **[Workflow and Approvals](workflow_and_approvals.md):** Workflow step definitions are a prime use case for `json_field:` + `target_model:` nested editing.

## Open Questions

1. **Virtual model table handling:** Models with all-virtual fields currently still trigger `SchemaManager.ensure_table!`. Need a way to declare a model as table-less (`table_name: _virtual` or `virtual: true` option). Alternatively, SchemaManager skips table creation when all fields are virtual.

2. **Sortable position in JSON items:** Association-backed records have a DB column for position. JSON items store position as a key in the hash or rely on array order. Recommendation: rely on array order (the array index IS the position). No position key needed.

3. **Undo/redo for bulk editors:** Manage pages allow destructive bulk operations. Should there be undo support? Recommendation: out of scope; the existing "Cancel" link and validation error re-render are sufficient.

4. **Max items enforcement for JSON fields:** Should the platform enforce a maximum number of items in JSON arrays? Recommendation: yes, via the existing `max:` option on nested_fields sections, with both client-side (JS blocks add) and server-side (controller rejects) enforcement.

5. **Searchability of JSON field items:** Should items in JSON arrays be searchable via the platform's text search? Recommendation: defer; the [Array Field Type](array_field_type.md) design covers scalar array search. Structured search within JSON objects is significantly more complex.

6. **Item-level error display:** When a model-backed item fails validation, how are errors shown? Recommendation: highlight the specific row and field with inline errors, similar to how standard nested_fields shows errors per row.
