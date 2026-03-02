# Search — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Universal Search (Global Search)

- [ ] Single search field across all entities (command palette style)
- [x] Configuration from metadata — which entities and fields are searchable — `search: { enabled: true, fields: [...] }` in presenter
- [ ] Field weighting (name has higher priority than description)
- [ ] Results grouped by entity (customers, orders, invoices...)
- [ ] Record preview display directly in results (configurable per entity)
- [ ] Keyboard navigation in results (arrows, Enter)
- [ ] Recently searched terms (per user)
- [ ] Favorite / pinned results
- [x] Permission enforcement (user sees only results they have access to) — Pundit scope applied
- [ ] Tenant isolation enforcement

## Full-Text Search

- [ ] Full-text index per entity / per field (configuration from metadata)
- [~] Diacritics support (searching "Novak" finds "Novák") — LIKE-based, depends on DB collation
- [x] Case-insensitive search — LIKE with LOWER
- [ ] Stemming / lemmatization (searching "orders" finds "order")
- [ ] Multiple language support (language-specific stemmers)
- [ ] Fuzzy matching / typo tolerance (Levenshtein distance)
- [ ] Phrase search (exact match of multi-word expression)
- [ ] Wildcard search (prefix, suffix, infix)
- [ ] Boosting / favoring newer records
- [ ] Searching within file / attachment content (PDF, DOCX — text extraction)
- [ ] Searching in rich text / HTML fields (strip tags during indexing)

## Suggestions and Autocomplete

- [ ] Autocomplete while typing (suggestions after N characters)
- [ ] Debounce / throttle requests (optimization during fast typing)
- [ ] Matched part highlighting in results (highlight)
- [ ] "Did you mean..." — typo correction / alternative suggestions
- [ ] Suggestions from user's search history
- [ ] Suggestions from popular searches (trending queries)
- [ ] Contextual suggestions (if on customer page, prefer searching customers)

## Advanced Filters (Advanced Search)

- [x] Filter builder — user composes conditions (field + operator + value) — visual filter builder with `FilterMetadataBuilder` + `advanced_filter.js`
- [x] Operators by data type:
  - [x] Text: equals, contains, starts_with, ends_with, is_empty, is_not_empty — via `OperatorRegistry` (no regex)
  - [x] Number: =, ≠, >, <, ≥, ≤, between, is_empty — via `OperatorRegistry`
  - [x] Date: =, before, after, between, relative (last 7 days, this month...) — via `OperatorRegistry` + `FilterParamBuilder` relative date expansion
  - [x] Boolean: is_true, is_false — via `OperatorRegistry`
  - [x] Enum / select: in, not_in — via `OperatorRegistry` + Tom Select multi-select
  - [ ] Relation: has_any, has_none, has_exactly
- [x] Condition combinations (AND / OR groups, no arbitrary NOT nesting) — visual OR groups in filter builder
- [x] Filters across related entities (filter orders by customer name) — dot-path association fields via Ransack
- [ ] Filters on computed / derived fields
- [x] Filters by workflow state — predefined filters / scopes
- [ ] Filters by tags / labels
- [x] Relative date filters (today, this week, last month, last N days) — `this_week`, `this_month`, `this_quarter`, `this_year`, `last_n_days` operators
- [x] NULL / empty value as filter condition — `null`, `not_null`, `present`, `blank` operators

## Saved Filters and Views

- [ ] Save filter by name (saved filter / saved view) — planned Phase 3
- [ ] Private filters (per user) — planned Phase 3
- [ ] Shared filters (per team / per role) — planned Phase 3
- [x] System / default filters defined in metadata — `predefined_filters` in presenter
- [x] Default filter per view / per role — `default_scope` in presenter
- [x] Preset filter combinations defined in YAML — `advanced_filter.presets` in presenter
- [ ] Saved filter ordering and organization (drag & drop, folders)
- [ ] Notification on saved filter (alert when new record matches filter)
- [x] Filter sharing by link (URL contains filter parameters) — `?f[field_pred]=value` URL params are bookmarkable

## Facets and Aggregations

- [ ] Faceted filtering (display counts per value — e.g., "Status: New (12), Approved (5)")
- [ ] Dynamic facets generated from metadata
- [ ] Hierarchical facets (category → subcategory with counts)
- [ ] Range facets (price ranges, date ranges)
- [ ] Facet count updates on filter change (real-time)
- [ ] Combining facets with advanced filters

## Result Sorting

- [ ] Sorting by relevance (score from full-text engine)
- [x] Sorting by any field (ASC / DESC) — column header sort
- [x] Multi-column sort (primary + secondary sorting) — `default_sort` in presenter
- [ ] Sorting by computed / derived field
- [ ] Sorting by related entity field
- [x] Custom sorting (drag & drop manual order) — positioning with drag & drop on index
- [x] Default sorting per view from metadata — `default_sort`
- [ ] User-persisted sorting (remembered per view)

## Result Pagination

- [x] Offset-based pagination (page 1, 2, 3...) — Kaminari
- [ ] Cursor-based pagination (for large datasets, consistent during data changes)
- [ ] Infinite scroll as alternative to pagination
- [x] Configurable page size (10 / 25 / 50 / 100) — `per_page` in presenter
- [x] Total result count display (with optimization — exact vs. approximate count)
- [ ] "Jump to page" / "Jump to record"

## Indexing and Backend

- [ ] DB full-text support (PostgreSQL tsvector, Oracle Text)
- [ ] Elasticsearch / OpenSearch support as search engine
- [ ] Incremental re-indexing (on record change, not full rebuild)
- [ ] Bulk re-indexing (on schema / metadata change)
- [ ] Index status monitoring (age, size, errors)
- [ ] Queue for asynchronous indexing (record change → event → re-index)
- [ ] Analyzer / tokenizer configuration from metadata
- [ ] Fallback strategy (if search engine unavailable → fallback to DB query)

## Performance and Optimization

- [ ] Search result caching (with invalidation on data change)
- [ ] Query timeout (protection against slow queries)
- [ ] Search rate limiting per user
- [ ] Lazy facet loading (facets calculated asynchronously)
- [ ] Partial results (display first results before search completes)
- [ ] Explain / debug mode (why a record appeared / didn't appear in results)

## Special Search

- [ ] Duplicate detection (fuzzy match on field combination — name + address + email)
- [ ] Similar record search ("find similar to this record")
- [ ] Geographic search (within X km radius of point, within polygon)
- [ ] Temporal search (records with overlapping date range)
- [ ] Change history search (find record that previously had value X)
- [ ] Cross-entity search (search across entities with single query, mixed results)

---

## Key Points

- **Diacritics and stemming** — in localized environments this is a must-have from day one. Without it, users can't find anything and will consider the platform broken.
- **Permission enforcement in results** — search engine indexes everything, but results must pass through the authorization layer. Can be solved by query-time filtering or post-filter, each approach has trade-offs.
- **Relative date filters** — "last 7 days", "this quarter" — users expect this and it's significantly more useful than entering specific dates. Implemented: `last_n_days`, `this_week`, `this_month`, `this_quarter`, `this_year`.
- **Notification on saved filter** — very powerful feature. User sets up filter "new urgent tickets in my team" and gets notified when a matching record appears. Essentially a watchdog.
- **Cursor-based pagination** — offset pagination breaks down on large datasets and during concurrent changes (records skip or duplicate). Cursor-based is more robust.
- **Fallback strategy** — if you use Elasticsearch as search engine, you need a plan B for outages. Degraded search via DB is better than no search.
