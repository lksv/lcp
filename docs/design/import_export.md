# Feature Specification: Import & Export

**Status:** Proposed
**Date:** 2026-03-07

## Problem / Motivation

LCP currently provides full CRUD for individual records and bulk actions on selected records, but there is no way to:

- **Export** data from the system in a structured format (CSV, XLSX, JSON) for reporting, sharing, or migration.
- **Import** data from external sources (spreadsheets, legacy systems, other tools) without direct database access.
- **Track** which records were created or updated by a specific import operation, making it impossible to audit or roll back bulk data loads.

These are table-stakes features for any production information system. Without platform-level support, host apps must build custom import/export logic outside the YAML metadata model, losing permissions, field visibility, type handling, and audit trail.

### Concrete Pain Points

- **No data extraction.** Users cannot get data out of the system without developer help or direct DB access.
- **No bulk data loading.** Onboarding a new customer with 500 existing records requires manual entry or custom scripts.
- **No import traceability.** When something goes wrong after a bulk import, there is no way to identify which records came from which import batch.
- **No reusable export profiles.** A user who regularly exports "active deals with company and value" must re-select fields every time.

## User Scenarios

### Export Scenarios

**Scenario 1: Quick export of current view.** A sales manager is looking at a filtered list of deals (status = negotiation, value > $50k). They click "Export", choose CSV format, and get a file with exactly the columns and rows they see on screen.

**Scenario 2: Custom field selection.** A user opens the export dialog, unchecks irrelevant fields, adds `company.name` (belongs_to association field) and includes `contacts` (has_many association) as nested rows. They save this configuration as a reusable export profile named "Deal report with contacts."

**Scenario 3: Reusable export profile.** Next week, the same user opens the export dialog and selects their saved "Deal report with contacts" profile. The same field selection is applied. They change the format to XLSX and download.

**Scenario 4: Export respects permissions.** A regular user exports deals but the "margin" field (restricted to managers) is not available in their field picker. The export only includes fields they can read.

### Import Scenarios

**Scenario 5: Basic CSV import.** An admin receives a spreadsheet with 200 new products from a supplier. They open the import dialog, upload the CSV, see a column mapping screen where "Product Name" is auto-matched to `name` and "Price (EUR)" needs manual mapping to `price`. They preview 5 rows, confirm, and the import creates 200 records.

**Scenario 6: Update existing records.** A data clerk receives an updated price list. They import with mode "Update" and match key `sku`. The system finds existing records by SKU and updates only the mapped fields. Records not found in the file are left untouched.

**Scenario 7: Import with errors.** During import, 8 out of 200 rows fail validation (missing required fields, invalid enum values). The system creates 192 records, skips 8, and provides a downloadable error report showing row numbers and error messages.

**Scenario 8: Import traceability.** After a large import, the admin navigates to "Import History" and sees a list of past imports with timestamps, file names, and counts (created/updated/skipped/errors). They click on an import batch and see exactly which records were created or updated in that batch.

**Scenario 9: Import with association resolution (future).** A CSV contains a "Category" column with text values like "Electronics". The system resolves these to `category_id` by looking up the Category model's `name` field. (v1 uses ID only; this is a future enhancement.)

## Scope: Per-Model vs Per-Presenter

This is an unresolved design question. Here are the trade-offs:

### Option A: Per-Model

Import/export configuration lives on the model level. Any presenter that references the model inherits the same import/export capability.

| Pro | Con |
|-----|-----|
| Simpler mental model — "I'm exporting Products" | Cannot have different export configs per view (e.g., "active products" vs "archived products" presenter) |
| One configuration per model, no duplication | Presenter already defines column visibility — this duplicates it |
| Import is inherently model-level (you create records in a model, not in a presenter) | Export "what I see" requires knowing which presenter triggered it anyway |
| Export profiles are reusable across all presenters of the same model | |
| Configurators think in terms of data models, not UI views | |

### Option B: Per-Presenter

Import/export configuration lives on the presenter. Each presenter can enable/disable and configure independently.

| Pro | Con |
|-----|-----|
| Different presenters can have different export/import configs | If 5 presenters reference the same model, you may need 5 configs |
| Inherits presenter's column visibility and permissions naturally | Import is conceptually model-level — the presenter is just the entry point |
| "Export what I see" principle works naturally | More configuration to maintain |
| Consistent with how other features are configured (search, actions, filters) | |

### Option C: Hybrid

- **Import** is per-model — you import records into a model, regardless of which presenter you're looking at. The import action button is configured on the presenter, but the import dialog and profiles reference the model.
- **Export** is per-presenter — the presenter defines which fields are available for export (based on readable fields), but export profiles are stored per-model and shared across presenters. The presenter acts as the entry point and applies its current filters/scope.

This reflects the conceptual asymmetry: import is about data (model), export is about view (presenter).

### Option D: Export as a Presenter Section (recommended for discussion)

The presenter already defines `index`, `show`, `edit` sections — each is a "view" of the model with its own field list. Export is conceptually another view: "which fields should appear in the exported file." Adding an `export` section to the presenter is a natural extension:

```yaml
# config/lcp_ruby/presenters/deals.yml
presenter:
  name: deals
  model: deal
  slug: deals

  sections:
    index:
      fields: [name, value, stage, company_id]
    show:
      fields: [name, value, stage, margin, company_id, notes]
    export:
      fields:
        - name
        - value
        - stage
        - company:                           # belongs_to — reference the related presenter
            presenter: companies             # which presenter's export section to use
            fields: [name, industry]         # or: override inline
        - contacts:                          # has_many — include child records
            presenter: contacts              # the child model's presenter defines its export fields
```

**Association handling via presenter references:**
- **belongs_to:** `company: { presenter: companies }` means "include the fields from the `companies` presenter's export section." If the referenced presenter has no explicit `export` section, fall back to its `index` fields. Inline `fields:` override lets you cherry-pick without defining a separate presenter.
- **has_many:** `contacts: { presenter: contacts }` means "for each deal, include its contacts using the `contacts` presenter's export fields." The rendering strategy (rows, sheets, nested) is determined by format.

| Pro | Con |
|-----|-----|
| Consistent with existing presenter architecture (index/show/edit are all sections) | New section type — adds complexity to presenter definition |
| Association fields are defined declaratively, not in a runtime dialog | Less flexible at runtime — the configurator pre-defines the export shape |
| Presenter references for associations reuse existing metadata | Users who want custom field selection need the dialog anyway (profiles) |
| Clear what each presenter exports — no ambiguity | Import doesn't fit this pattern (import is model-level, not a "view") |
| Permissions naturally scoped — the export section respects the presenter's field permissions | |
| Configurator can define different export shapes per presenter (e.g., "active deals" exports different fields than "archived deals") | |

**How it works with the export dialog:** The `export` section defines the **available** fields (what the configurator allows). The export dialog then lets the user **select** from those available fields and save the selection as a profile. The section is the ceiling; the profile is the user's choice within that ceiling.

**Import stays per-model:** This option only affects export. Import creates/updates records in a model regardless of the presenter's view — the import dialog's field mapping targets are the model's writable fields, not a presenter section.

## Configuration & Behavior

### Presenter YAML (action trigger)

Export and import are **configurable built-in actions** in the presenter's action list:

```yaml
# config/lcp_ruby/presenters/products.yml
presenter:
  name: products
  model: product
  slug: products

  actions:
    collection:
      - { name: create, type: built_in }
      - name: export
        type: built_in
        icon: download
      - name: import
        type: built_in
        icon: upload

    # Export also available as batch action (export selected records)
    batch:
      - name: export
        type: built_in
        icon: download
```

The presence of `export`/`import` in the actions list enables the feature for that presenter. No action = no button = no capability.

### Export Configuration

```yaml
# Inline on the presenter (simple case)
export:
  formats: [csv, xlsx]              # available formats (default: [csv])
  max_records: 10_000               # safety limit per export
  default_columns: :visible         # :visible (index columns) | :readable (all readable)
```

### Import Configuration

```yaml
# Inline on the presenter (simple case)
import:
  formats: [csv, xlsx]              # accepted formats (default: [csv])
  mode: create                      # default mode: create | update | upsert
  match_key: id                     # field(s) for update/upsert matching
  on_error: skip                    # skip | abort
  max_file_size: 10485760           # 10 MiB (default), in bytes
```

### Export Dialog — Field Picker

The export dialog is a **presenter-driven modal** (uses the [Modal Dialogs](modal_dialogs.md) infrastructure). It shows:

1. **Format selector** — dropdown with available formats
2. **Field picker** — checkboxes for model fields (respecting `readable_fields` permissions)
3. **Association fields:**
   - **belongs_to** — expand to show target model's fields (e.g., `company.name`, `company.industry`)
   - **has_many** — toggle to include related records as additional rows/sheets (e.g., include `contacts` for each deal)
4. **Save as profile** — optional name to save the field selection for reuse
5. **Load profile** — dropdown of saved export profiles

The dialog uses a **virtual model** for the form (format, selected fields, profile name) and a **real model** (`export_profile`) for saved configurations.

### Import Dialog — Column Mapping

The import dialog is a **multi-step modal**:

1. **Upload step** — file upload (CSV/XLSX) + mode selection (create/update/upsert) + match key (for update/upsert)
2. **Mapping step** — two-column table: source columns (from file) on the left, target fields (from model) on the right. Auto-mapping by header name match, manual override via dropdown. Unmapped columns are skipped.
3. **Preview step** — first N rows shown as they will be imported, with validation errors highlighted
4. **Result step** — summary (created/updated/skipped/errors) + link to import batch detail + downloadable error report

Both dialogs are defined as YAML models and presenters, created by a generator.

### Import Batch Tracking

Every import operation creates an `import_batch` record that links to the individual records affected:

- **`import_batch`** — metadata about the import run (file name, model, mode, counts, user, timestamp, status)
- **`import_batch_item`** — one record per affected row (links to the created/updated record, action taken, row number, any errors)

This enables:
- "Show me all records from import #47"
- "Which import created this record?"
- "How many errors were in last week's imports?"
- Potential future rollback (delete all records from a failed import)

### Export Batch Tracking

Similarly, every export creates an `export_batch` record:

- **`export_batch`** — metadata (model, presenter, format, record count, filters applied, user, timestamp, status)
- In v1 (synchronous), the file is generated and downloaded immediately — status is always `completed`.
- In a future version with background jobs, the `export_batch` holds the status (`pending`/`processing`/`completed`/`failed`) and the generated file as an attachment for later download.

### Permission Integration

Export and import actions respect the standard permission system:

```yaml
# config/lcp_ruby/permissions/product.yml
permissions:
  model: product
  roles:
    admin:
      crud: [create, read, update, delete]
      actions: [export, import]         # both enabled
    manager:
      crud: [create, read, update]
      actions: [export]                 # export only, no import
    viewer:
      crud: [read]
      actions: [export]                 # can export what they can read
      fields:
        readable: [name, sku, price]    # limited fields = limited export columns
```

- **Export** requires `read` permission + `export` action permission. Only `readable_fields` appear in the field picker.
- **Import** requires `create` (or `update` for update mode) permission + `import` action permission. Only `writable_fields` are available as mapping targets.

### Events & Auditing Integration

- **Events:** Imported records trigger standard `after_create`/`after_update` events, but with a `bulk: true` flag in the event context. This allows event handlers to optimize (e.g., send one batch notification instead of 200 individual ones).
- **Auditing:** Each imported/updated record gets its own audit log entry (consistent with the existing auditing system). All entries from one import share an `import_batch_id` marker, enabling batch-level audit queries.

## Generator

A generator creates the necessary YAML metadata files:

```bash
bundle exec rails generate lcp_ruby:import_export
```

This generates:

```
config/lcp_ruby/models/
  export_profile.yml          # saved export field selections
  import_profile.yml          # saved import column mappings
  export_batch.yml            # export run history
  import_batch.yml            # import run history
  import_batch_item.yml       # per-row import results

config/lcp_ruby/presenters/
  export_profiles.yml         # manage saved export profiles
  import_profiles.yml         # manage saved import mappings
  export_batches.yml          # view export history
  import_batches.yml          # view import history
  import_batch_items.yml      # view items in an import batch

config/lcp_ruby/permissions/
  export_profile.yml
  import_profile.yml
  export_batch.yml
  import_batch.yml
  import_batch_item.yml
```

Additionally, the generator creates virtual models and dialog presenters for the export/import forms:

```
config/lcp_ruby/models/
  export_config.yml           # virtual model for export dialog form
  import_config.yml           # virtual model for import dialog form

config/lcp_ruby/presenters/
  export_dialog.yml           # export field picker dialog
  import_dialog.yml           # import column mapping dialog
```

### Generated Model Sketches

**export_profile.yml:**
```yaml
name: export_profile
fields:
  - { name: profile_name, type: string, required: true }
  - { name: target_model, type: string, required: true }
  - { name: format, type: enum, values: [csv, xlsx, json], default: csv }
  - { name: columns, type: json }              # selected field paths
  - { name: include_associations, type: json }  # has_many includes
  - { name: created_by_id, type: integer }
```

**import_profile.yml:**
```yaml
name: import_profile
fields:
  - { name: profile_name, type: string, required: true }
  - { name: target_model, type: string, required: true }
  - { name: format, type: enum, values: [csv, xlsx], default: csv }
  - { name: column_mapping, type: json }       # source_col → target_field mapping
  - { name: mode, type: enum, values: [create, update, upsert], default: create }
  - { name: match_key, type: string }           # field used for update/upsert matching
  - { name: created_by_id, type: integer }
```

**import_batch.yml:**
```yaml
name: import_batch
fields:
  - { name: target_model, type: string, required: true }
  - { name: file_name, type: string }
  - { name: mode, type: enum, values: [create, update, upsert] }
  - { name: match_key, type: string }
  - { name: status, type: enum, values: [pending, processing, completed, failed] }
  - { name: column_mapping, type: json }       # source_col → target_field
  - { name: total_rows, type: integer, default: 0 }
  - { name: created_count, type: integer, default: 0 }
  - { name: updated_count, type: integer, default: 0 }
  - { name: skipped_count, type: integer, default: 0 }
  - { name: error_count, type: integer, default: 0 }
  - { name: created_by_id, type: integer }
associations:
  - { name: items, type: has_many, model: import_batch_item }
```

**import_batch_item.yml:**
```yaml
name: import_batch_item
fields:
  - { name: import_batch_id, type: integer, required: true }
  - { name: record_id, type: integer }         # FK to the created/updated record
  - { name: record_type, type: string }         # polymorphic model name
  - { name: action, type: enum, values: [created, updated, skipped, error] }
  - { name: row_number, type: integer }
  - { name: error_details, type: json }         # validation errors for this row
associations:
  - { name: import_batch, type: belongs_to, model: import_batch }
```

**export_batch.yml:**
```yaml
name: export_batch
fields:
  - { name: target_model, type: string, required: true }
  - { name: presenter_name, type: string }
  - { name: format, type: enum, values: [csv, xlsx, json] }
  - { name: record_count, type: integer, default: 0 }
  - { name: applied_filters, type: json }       # snapshot of active filters
  - { name: columns, type: json }               # exported field paths
  - { name: status, type: enum, values: [pending, completed, failed] }
  - { name: created_by_id, type: integer }
```

## General Implementation Approach

### Export Flow

1. User clicks "Export" action button on index page (or selects records + batch export)
2. System opens export dialog (modal) with field picker pre-populated from presenter's readable fields
3. User selects format, fields, association includes, optionally saves as profile
4. On submit, controller:
   a. Creates an `export_batch` record
   b. Applies current filters/scope to the model query
   c. Selects only the chosen fields (+ association eager loading)
   d. Serializes to the chosen format (CSV: ruby `csv` stdlib, XLSX: a gem like `caxlsx`, JSON: `to_json`)
   e. Returns the file as a download response (`send_data`)
5. The export_batch record is marked as `completed`

For **batch export** (selected records), the same flow applies but the query is scoped to the selected IDs instead of the current filters.

### Import Flow

1. User clicks "Import" action button
2. System opens import dialog (multi-step modal):
   - **Step 1:** File upload + mode + match key selection
   - **Step 2:** Parse file headers → auto-map to model fields → show mapping UI for manual adjustment
   - **Step 3:** Dry-run preview — validate first N rows, show errors
3. On confirm, controller:
   a. Creates an `import_batch` record (status: `processing`)
   b. Iterates rows, applies column mapping, coerces types per model field definitions
   c. For each row: create or find-and-update record, create `import_batch_item`
   d. Writable field permissions enforced — unmapped/non-writable fields are skipped
   e. Events fired with `bulk: true` context
   f. Audit entries created with `import_batch_id` marker
   g. Updates batch counters and sets status to `completed` or `failed`
4. Result summary shown to user (in dialog or redirect to import_batch show page)

### Association Handling in Export

- **belongs_to:** The field picker shows the target model's fields as nested options (e.g., under "Company": `company.name`, `company.industry`). These are resolved via eager loading and dot-path field access (existing `FieldValueResolver` infrastructure).
- **has_many:** The user toggles "include related records." The export strategy depends on format (see D11):
  - **CSV:** One row per parent-child pair — parent data is duplicated on each row. This is the most universally compatible format.
  - **XLSX:** Separate worksheet per has_many association, linked by parent ID (no duplication).
  - **JSON:** Nested array within the parent object.

### Association Resolution in Import (v1 and future)

- **v1:** Import maps to raw field values. For FK fields (`category_id`), the CSV must contain the integer ID. This is simple and unambiguous.
- **Future enhancement:** A "lookup resolver" that maps text values to IDs by querying the target model. Configuration: `category_id: { resolve_by: name }` — the system looks up `Category.find_by(name: value)`. The architecture should keep association resolution behind an interface so this can be plugged in later without restructuring the import pipeline.

### Type Coercion

The import pipeline reuses existing type infrastructure:
- Model field definitions provide type information (string, integer, date, enum, etc.)
- Type transforms (strip, downcase, normalize) are applied as they would be for regular form submissions
- Enum values validated against the allowed values list
- Date/datetime parsing with configurable format (ISO 8601 by default)

### Error Handling

- **`on_error: skip`** — invalid rows are recorded as `import_batch_item` with `action: error` and `error_details`, the import continues. Summary shows skipped count.
- **`on_error: abort`** — import stops at the first error. All previously created records in this batch are kept (no rollback). The batch is marked `failed` with the error row information.
- Rollback (transactional — undo all on any error) is intentionally not in v1. It adds complexity (large transactions, FK ordering) and "skip" covers most real-world use cases.

## Usage Examples

### Enabling export/import on a presenter

```yaml
# config/lcp_ruby/presenters/products.yml
presenter:
  name: products
  model: product
  slug: products

  export:
    formats: [csv, xlsx]
    max_records: 50_000

  import:
    formats: [csv, xlsx]
    mode: upsert
    match_key: sku
    on_error: skip

  actions:
    collection:
      - { name: create, type: built_in }
      - { name: export, type: built_in, icon: download }
      - { name: import, type: built_in, icon: upload }
    batch:
      - { name: export, type: built_in, icon: download }
```

### Viewing import history

```yaml
# Generated by the generator — import_batches presenter
# User navigates to /import-batches, sees a list:
#
# | File           | Model   | Mode   | Created | Updated | Errors | Date       | User  |
# |----------------|---------|--------|---------|---------|--------|------------|-------|
# | products.csv   | product | upsert | 180     | 20      | 3      | 2026-03-07 | admin |
# | contacts.xlsx  | contact | create | 450     | 0       | 12     | 2026-03-06 | admin |
#
# Clicking a batch shows the import_batch_items:
#
# | Row | Record      | Action  | Errors                          |
# |-----|-------------|---------|---------------------------------|
# | 1   | Product #42 | updated | —                               |
# | 2   | Product #43 | created | —                               |
# | 5   | —           | error   | price: must be greater than 0   |
```

### Export with belongs_to association

A deal export with company fields:

```
Selected fields:
  [x] name
  [x] value
  [x] stage
  [ ] margin           ← not readable for this role
  Company:
    [x] company.name
    [x] company.industry
    [ ] company.revenue
  Contacts:
    [x] include (has_many → separate sheet in XLSX)
```

Resulting CSV:
```csv
name,value,stage,company.name,company.industry
"Acme Deal",50000,negotiation,"Acme Corp","Manufacturing"
"Beta Deal",30000,proposal,"Beta Inc","Technology"
```

## Decisions

### D1: Built-in configurable actions, not custom actions

Export and import are `type: built_in` actions in the presenter's action list. They are platform-provided, not host-app-defined. The presence of the action in the YAML enables the feature; its absence disables it.

### D2: Events fire with bulk flag

Imported records trigger standard model events (`after_create`, `after_update`) with `bulk: true` in the event context. Event handlers can check this flag to optimize (e.g., batch notifications).

### D3: Audit entries per record with batch marker

Each imported/updated record gets its own audit log entry (if auditing is enabled on the model). All entries share an `import_batch_id` for batch-level queries.

### D4: No background jobs in v1

All import/export operations run synchronously in the request cycle. The `export_batch`/`import_batch` models include `status` fields to support future background job processing. The architecture is ready for async but v1 is synchronous.

### D5: ID-only association resolution in v1

Import maps FK fields by integer ID. The architecture separates association resolution behind an interface so lookup-by-field resolution can be added later without restructuring.

### D6: PDF export deferred

PDF export is a reporting/printing concern with different layout requirements (page size, headers/footers, grouping). Deferred to a separate "Reports" feature spec.

### D7: Computed and aggregate fields are export-only

Computed fields and aggregate columns can appear in export output as read-only values. They are not available as import mapping targets (they are derived, not writable).

### D8: Dialogs defined in YAML with generator

Both the export dialog (field picker) and import dialog (column mapper) are defined as YAML models and presenters. The generator creates all necessary files. This follows the platform principle that every UI form is metadata-driven.

### D9: Import/export history as standard models

`import_batch`, `import_batch_item`, `export_batch` are standard YAML-defined models with their own presenters and permissions. They are browsable through the normal LCP UI — no special admin pages needed.

### D10: XLSX as optional dependency

XLSX export/import requires an external gem (e.g., `caxlsx` for writing, `roo` for reading). This is an **optional dependency** — the engine works without it, but export formats are limited to CSV and JSON. If the gem is not present and a user tries XLSX, the system raises a clear error message explaining which gem to add. The presenter's `formats:` list should only include `xlsx` if the gem is available.

### D11: has_many CSV export strategy — one row per parent-child pair

When exporting has_many associations to CSV, the default strategy is **one row per parent-child combination** with parent data duplicated on each row. This is the most universally compatible format — every spreadsheet tool handles it, and users can pivot/group in their tool of choice.

For XLSX, has_many associations use **separate worksheets** linked by parent ID (no duplication). For JSON, has_many is a **nested array** within the parent object.

### D12: Import file size limit — configurable, default 10 MiB

Import file size is configurable via `import.max_file_size` (default: `10.megabytes`). This applies to synchronous imports in v1. When background jobs are added, the limit can be raised or removed for async processing.

### D13: Saved import mappings as reusable profiles

Column mappings from an import can be saved as a reusable `import_profile` (similar to export profiles). This avoids re-mapping columns every time the same file format is imported. The generator creates the `import_profile` model alongside the other import/export models.

### D14: Export section as presenter scope (Option D)

Export uses **Option D** — an `export` section in the presenter defines the ceiling of available fields. Key sub-decisions:

1. **Section = ceiling, not replacement.** The `export` section defines which fields are **available** for export. The export dialog lets users **select from** those fields and save the selection as a profile. The section is the configurator's constraint; the profile is the user's choice within it.
2. **Import is model-level.** Import does not have a presenter section. All writable fields (per the user's permission) are available as mapping targets. The import dialog provides the mapping UI.
3. **No export section = no export.** If a presenter does not define an `export` section, the export action is not available for that presenter. This is explicit opt-in — the configurator must declare what can be exported. (The export action in the `actions:` list is still required too — both the section and the action must be present.)

### D15: Export field picker — dedicated built-in component

The export dialog's field picker is a **dedicated built-in component** (like the advanced filter builder), not a dynamically generated presenter. The component reads the presenter's `export` section metadata and renders a checkbox tree:

```
Export Fields
├── [x] Name
├── [x] Value
├── [x] Stage
├── [ ] Margin
├── [v] Company                    ← belongs_to, expandable
│   ├── [x] company.name
│   ├── [x] company.industry
│   └── [ ] company.revenue
└── [v] Contacts                   ← has_many, expandable
    ├── [x] contacts.first_name
    ├── [x] contacts.last_name
    └── [x] contacts.email
```

**Why not a dynamically generated presenter definition?**

Dynamically generating a virtual model with `include_<field>` boolean fields + a presenter for rendering is technically possible but adds unnecessary complexity:
- Ephemeral virtual models are not a concept the platform has — virtual models are defined in YAML
- Association recursion creates nested virtual models with cycle detection concerns
- Field names become `include_name`, `include_company_name` — a clumsy mapping layer
- The resulting "form" is a flat list of checkboxes with no tree structure, expand/collapse, or "select all" UX

The filter builder precedent shows that specialized components reading metadata directly produce better UX with less machinery. The field picker component:
- Reads the `export` section's field list and association references
- Follows presenter references to resolve association fields (with cycle detection — see D16)
- Renders a checkbox tree with expand/collapse for associations
- Supports "select all" / "deselect all" per group
- Outputs a JSON array of selected field paths (e.g., `["name", "value", "company.name", "contacts"]`)

This is purpose-built UI, not a generic form. The same pattern can be reused for the import column mapping component (showing target fields as a dropdown list populated from model metadata).

### D16: No depth limit for association recursion, cycle detection only

When the `export` section references an association's presenter, and that presenter's export section references further associations, there is **no artificial depth limit**. The system follows presenter references as deep as they go. Cycle detection (tracking visited presenter names) prevents infinite loops — if a presenter has already been visited in the current chain, it is skipped.

This means a configurator can define `deal → company → country → region` if needed. In practice, most exports will be 1–2 levels deep because the configurator only includes associations they explicitly reference in the `export` section.

### D17: has_many cross product — warn, don't restrict

When exporting multiple has_many associations in CSV, the system **warns** the user about potential row explosion in the export dialog (e.g., "Including both Contacts and Line Items may produce up to ~N rows") but does **not** restrict it. Users know their data best.

The existing `max_records` limit (D12, configured on the presenter's `export:` block) acts as the safety net — if the cross product exceeds the limit, the export is stopped with a clear error. This limit is already role-aware via the permission system: different presenters (with different `max_records`) can be assigned to different roles via the `presenters:` permission key.

For more granular control, the configurator can set different `max_records` values per presenter:

```yaml
# Full export presenter for admins
presenter:
  name: deals_admin
  model: deal
  export:
    max_records: 100_000
    fields: [...]

# Limited export for regular users
presenter:
  name: deals
  model: deal
  export:
    max_records: 5_000
    fields: [...]
```

Combined with the role-based `presenters:` permission key, this gives full control over who can export how much.

## Open Questions

### Q1: Import dialog multi-step flow

The import dialog has 4 steps (upload → mapping → preview → result). The current modal dialog infrastructure (Tier 1) supports single-step dialogs. Multi-step wizard is listed as Tier 3 in the [Modal Dialogs spec](modal_dialogs.md). Options:
- Implement import as a full page (not a dialog) for v1, migrate to wizard dialog later
- Implement a minimal multi-step flow (server-driven, no client-side step management) within the dialog
- Use separate pages for each step with standard navigation

*Q4–Q7 (XLSX dependency, CSV strategy, file size, saved mappings) resolved — see D10–D13.*
*Q1 sub-questions (ceiling vs replacement, import scope, missing section default) resolved — see D14.*
*Q2 (field picker rendering) resolved — see D15.*
*Q2–Q3 (depth limit, cross product) resolved — see D16–D17.*
