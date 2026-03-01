# Implementation Priorities — Easiest Items

Analysis of all ~600 unimplemented items (`[ ]` and `[~]`) across 13 requirement files, ranked by implementation difficulty against the existing codebase architecture.

## Tier 1 — Trivial (hours, mostly config/CSS/template changes)

| # | Requirement | File | Why it's easy |
|---|-------------|------|---------------|
| 1 | **Empty value display** (empty vs. "—" vs. "N/A" — configurable) | presenter | Add `empty_value` option to `BaseRenderer`, fallback in `DisplayHelper`. A few lines. |
| 2 | **Copy URL to clipboard** ("Share link" button) | routing | One button in show/index view + `navigator.clipboard.writeText()`. Pure frontend. |
| 3 | **Copy-to-clipboard on values** | presenter | Small icon next to values in show view. Same pattern as above. |
| 4 | **Sticky header / sidebar** | presenter | Pure CSS (`position: sticky`). No logic change. |
| 5 | **NULL / empty value as filter condition** | search | `where(field: nil)` / `where.not(field: nil)`. Add `is_empty`/`is_not_empty` operators to search. |
| 6 | **Catch-all / fallback route** (custom 404 page) | routing | Rails `match '*path'` route + custom view. |
| 7 | **Configurable redirect per action per entity** (from metadata) | routing | Add `redirect_after` key to presenter YAML, use in controller `after_create`/`after_update`. |
| 8 | **Item sorting** (alphabetical, custom order) | selectbox | Tom Select is already integrated — add `sort_options` config in presenter. |
| 9 | **Debounce / throttle requests** (search optimization) | search | `utils.js` already has a `debounce` function. Just wire it into the search input event. |

## Tier 2 — Easy (1–2 days, existing infrastructure)

| # | Requirement | File | Why it's easy |
|---|-------------|------|---------------|
| 10 | **Summary row** (SUM, COUNT, AVG at column bottom) | presenter | ResourcesController **already has** `summary_columns` support. Only missing: UI footer row in `_index` template. |
| 11 | **Bulk selection and bulk actions** | presenter | ActionSet already has `batch` action type. Missing: checkbox UI in index and controller endpoint for batch. |
| 12 | **Export to CSV** | presenter/integration | `to_csv` on collection respecting `visible_table_columns` and permissions. Rails has CSV built-in. |
| 13 | **Dirty state detection** (warning on leaving unsaved form) | presenter/routing | `beforeunload` event listener + form change tracking in JS. Pure frontend. |
| 14 | **Selected tab / section in URL** (`?tab=history` or `#history`) | routing | Hash fragment + JS for tab activation. Preserved in URL automatically. |
| 15 | **Matched part highlighting** in search results | search | Search query is available — `<mark>` tag around matches in table. Template change. |
| 16 | **Row highlighting by condition** (upgrade from `[~]` to `[x]`) | presenter | Badge renderer has `color_map`. Extend to entire row — add `row_class_when` to presenter. |
| 17 | **Relative date filters** (last 7 days, this month) | search | Add predefined scopes with dynamic dates: `where("created_at > ?", 7.days.ago)`. Scope config in YAML. |
| 18 | **Optimistic locking** (version / updated_at check) | models | `lock_version` column + Rails built-in `ActiveRecord::StaleObjectError`. Config in model YAML. |
| 19 | **Print-friendly detail version** | presenter | `@media print` CSS stylesheet. Hides navigation, buttons, sidebar. |
| 20 | **Forbidden MIME types / extensions** (blacklist) | files | AttachmentApplicator **already validates** `content_type`. Add global blacklist in engine config. |
| 21 | **Keyboard navigation in results** (arrows, Enter) | search | JS event listener on index table — `keydown` for `ArrowUp`/`ArrowDown`/`Enter`. |
| 22 | **Record navigation** (previous / next in list) | presenter | Add prev/next links in show view. Controller needs IDs from session/query context. |
| 23 | **Autocomplete while typing** (suggestions after N characters) | search | Tom Select **is already integrated** with remote search. Wire it to the main search field. |
| 24 | **`description` class method** on actions | service-actions | One-line DSL: `class_attribute :description_text` in BaseAction. Trivial. |
| 25 | **`param` DSL on BaseAction** | service-actions | BaseAction already has `param_schema`. Extend to `param :name, type: :string` DSL syntax. |
| 26 | **Disabled / readonly for individual items** | selectbox | Tom Select supports per-item disabled. FormHelper `association_select` has `disabled_ids`. Extend to enum. |
| 27 | **Grouped options** (optgroup) | selectbox | Tom Select + FormHelper **already have** `group_by` support for association selects. Extend to enum. |

## Tier 3 — Medium complexity (3–5 days, clear patterns exist)

| # | Requirement | File | Why it's manageable |
|---|-------------|------|---------------------|
| 28 | **Inline editing directly in table** | presenter | Pattern exists: nested_forms.js + form helpers. Needed: contenteditable cells + PATCH endpoint. |
| 29 | **Compound conditions** (AND/OR/NOT) | workflow | ConditionEvaluator has 12 operators. Add `all:`/`any:`/`not:` wrappers (recursion). Clear design in workflow spec. |
| 30 | **Kanban view** | presenter | New view type. Needed: JS drag-drop, enum column mapping, PATCH on state change. Data flow is clear. |
| 31 | **REST API auto-generated** | integration | ResourcesController CRUD already exists. Add `respond_to :json` + API namespace with auth. |
| 32 | **Soft-delete** (deleted_at) | models | Add `soft_delete: true` in model YAML → `default_scope { where(deleted_at: nil) }` + `destroy` override. |
| 33 | **Audit trail** (who, when, what changed) | models | Event system **dispatches** before/after_update with changes. Add AuditLog model + built-in handler. |
| 34 | **Saved / named filters** (per user) | search | New model `saved_filter` (user, presenter, query params JSON). UI: save/load buttons. |
| 35 | **State machine DSL** (workflow engine) | workflow | Add `transitions` to model YAML. Enforce `from → to` in before_update callback. Design doc exists. |
| 36 | **Import from CSV** | integration | `CSV.parse` + field mapping UI + `model.create!` loop. Basics straightforward, edge cases (validation, duplicates) more complex. |

---

## Recommendation

Start with **Tier 1 items (1–9)** as quick wins — each can be done in hours and immediately improves UX. Then **Tier 2 #10–12** (summary row, bulk actions, CSV export), because the infrastructure for them **already largely exists** in the codebase.
