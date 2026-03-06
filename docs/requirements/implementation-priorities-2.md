# Implementation Priorities — Easy Wins (Updated 2026-03-06)

Analysis of remaining unimplemented items across all requirement files, cross-referenced with current codebase state. Items already completed since the original `implementation-priorities.md` are excluded.

## Already Completed (since original analysis)

The following Tier 1 items from the original analysis are now implemented:

- **Empty value display** — `empty_value_placeholder` helper, configurable per presenter and globally
- **Copy URL to clipboard** — `copy_url` toolbar button on show page
- **Copy-to-clipboard on field values** — `copy_value` on field values
- **NULL / empty value as filter condition** — `null`, `not_null`, `present`, `blank` operators
- **Item sorting in selectbox** — `sort` option with field/direction hash
- **Row highlighting by condition** — `item_classes` with conditional rendering
- **Relative date filters** — `this_week`, `this_month`, `this_quarter`, `this_year`, `last_n_days` operators

---

## Tier 1 — Trivial (hours, CSS/template/config changes)

| # | Requirement | Source file | Why it's easy |
|---|-------------|-------------|---------------|
| 1 | **Sticky table header** | presenter | Pure CSS (`position: sticky`). No logic changes. ~10 lines of CSS. |
| 2 | **Catch-all 404 page** | routing | `set_presenter_and_model` already raises `MetadataError`. Add rescue + custom view template. Straightforward. |
| 3 | **Configurable redirect after CRUD** | routing | Add `redirect_after` key to presenter options + simple `case` in controller. ~20 lines. |
| 4 | **Debounce on search input** | search | JS `debounce` already exists in codebase. Wire it to search field + data attributes for config. |
| 5 | **Print-friendly version** | presenter | Pure `@media print` CSS — hide navigation, sidebar, buttons. No logic changes. |
| 6 | **Dirty state guard** (unsaved form warning) | routing/presenter | JS `beforeunload` event + form change detection. Pure frontend, ~30 lines of JS. |

## Tier 2 — Easy (1–2 days, existing infrastructure)

| # | Requirement | Source file | Why it's easy |
|---|-------------|-------------|---------------|
| 7 | **Summary row** (SUM/COUNT/AVG at column bottom) | presenter | Metadata schema **already supports** `summary: sum\|avg\|count` on columns. Only missing: footer row rendering in index template. |
| 8 | **Bulk selection UI** (checkboxes in table) | presenter | Backend **is done** (`ActionsController#execute_batch`, `BaseAction` with `records`). Only missing: checkbox UI + JS for batch submit. |
| 9 | **Export to CSV** | integration | `CSV.generate` on collection respecting `visible_table_columns` + permissions. Rails has CSV built-in. Add `respond_to format.csv`. |
| 10 | **Optimistic locking** | models | `lock_version` column + Rails built-in `ActiveRecord::StaleObjectError`. Add `optimistic_locking: true` to model YAML, `SchemaManager` creates the column. |
| 11 | **Selected tab/section in URL** (`#section`) | routing | Hash fragment + JS for tab activation. URL is automatically preserved. |
| 12 | **Search result highlighting** | search | Search query is available. Wrap matches with `<mark>` tag in table cells. Pure template change. |
| 13 | **Collapsible sections on show page** | presenter | On form page `collapsible: true` **already works**. Apply the same logic to show layout. |
| 14 | **Tabs on show page** | presenter | Tabs **work on form layout**. Extend to show view — same pattern. |
| 15 | **`description` class method on actions** | service-actions | One-liner: `class_attribute :description_text` in `BaseAction`. Trivial. |
| 16 | **Forbidden MIME types (blacklist)** | files | `AttachmentApplicator` **already validates** `content_type` (whitelist). Add global blacklist to engine config. |
| 17 | **Redirect after login to original URL** | routing/auth | Standard Devise `store_location_for` — just wire up the `return_to` parameter. |

---

## Recommendation

Start with **Tier 1 (items 1–6)** — each can be done in hours and immediately improves UX. Then **Tier 2 items 7–9** (summary row, bulk selection UI, CSV export) because the infrastructure for them **already largely exists** in the codebase.
