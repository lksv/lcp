# Presentation Layer (Presenter) — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## View Definitions from Metadata

- [x] Views defined purely in metadata (without writing templates) — YAML + DSL presenters
- [~] Multiple view types per entity (list, detail, form, card, kanban, calendar, timeline, tree, map...) — list, detail, form, tree supported; kanban/calendar/timeline/card/map not implemented
- [x] Multiple variants of one view type per entity (e.g., "compact list" vs. "detailed list") — view groups
- [x] View per role (different view for admin vs. regular user) — presenter-level role permissions
- [ ] View per context (embedded vs. standalone, modal vs. full-page)
- [ ] View definition versioning (rollback on error)

## List / Table View

- [x] Visible column definition from metadata — ColumnSet
- [x] Default sorting and direction (ASC/DESC, multi-column sort)
- [ ] User column reordering (drag & drop, persisted per user)
- [ ] User column show/hide toggle
- [x] Column widths (fixed, auto, user-adjustable) — `width` in presenter
- [ ] Column freezing (freeze first N columns on horizontal scroll)
- [x] Row actions (inline buttons per record) — ActionSet single actions
- [~] Bulk selection and bulk actions — backend API implemented (batch_actions route, `ActionsController#execute_batch`, `BaseAction` with `records`), multiselect checkbox UI not yet
- [ ] Inline editing directly in table
- [~] Row highlighting by condition (background color, icon — e.g., overdue = red) — badge renderer with color_map
- [ ] Row grouping (group by field — with collapse/expand)
- [~] Summary row (SUM, COUNT, AVG at column bottom) — metadata schema supports `summary: sum|avg|count` on columns, rendering not yet implemented
- [x] Virtual scrolling / pagination (configurable: paging vs. infinite scroll) — Kaminari pagination
- [ ] Exports (CSV, XLSX, PDF) respecting current filter and sorting

## Detail / Read-Only View

- [x] Layout defined from metadata (sections, columns, tabs) — LayoutBuilder with form/show sections
- [x] Related record display (embedded list, inline cards) — association lists on show page
- [x] Timeline / change history on detail — `audit_history` section type on show page with field-level diffs
- [ ] Workflow state with visualization (current position in process)
- [x] Quick actions on detail (approve, reject, edit... by permission and state) — ActionSet
- [ ] Record navigation (previous / next in list context)
- [ ] Print-friendly detail version

## Forms

- [x] Form layout from metadata (sections, columns, tabs, accordion) — LayoutBuilder
- [~] Different layout for create vs. edit vs. clone — separate presenters possible via view groups
- [x] Conditional field visibility (show field only when another field has specific value) — `visible_when`
- [x] Conditional field required (required only in certain context) — conditional validations with `when:`
- [x] Dynamic addition / removal of field groups (repeatable sections — e.g., multiple addresses) — nested fields
- [ ] Wizard / multi-step form (divided into steps with navigation)
- [ ] Autosave / draft save
- [ ] Dirty state detection (warning on leaving unsaved form)
- [ ] Inline validation (real-time while filling, not just on save)
- [x] Field-level help text / tooltip from metadata — `description` on fields
- [x] Placeholder texts from metadata
- [x] Readonly / disabled fields by context (state, role, condition) — `disable_when` + field-level permissions

## Filters and Search

- [x] Available filter definition from metadata per view — `search` config in presenter
- [x] Quick filter (search bar with full-text across selected fields) — text search on searchable fields
- [x] Advanced filter builder (user composes conditions: field + operator + value) — visual filter builder with `FilterMetadataBuilder` + `advanced_filter.js`
- [x] Operators by data type (text: contains, starts_with; number: =, >, <, between; date: before, after, range...) — `OperatorRegistry` with type-aware operator sets
- [x] Filters across related entities (filter orders by customer name) — dot-path association fields via Ransack
- [x] Saved / named filters (per user and shared per team) — `SavedFiltersController` + generator + visibility levels (personal/role/group/global)
- [x] Default filter per view / per role — `default_scope` in presenter
- [x] AND / OR condition combinations in advanced filter — nested AND/OR groups with configurable `max_nesting_depth`
- [x] Filtering by workflow state — predefined filters with scopes
- [ ] Filtering by tags / labels
- [x] Active filters visually displayed (chips / badges with removal option) — predefined filter dropdown

## Card / Kanban View

- [ ] Card layout definition from metadata (which fields to display, order, format)
- [ ] Kanban columns driven by field (typically workflow state or enum)
- [ ] Drag & drop between columns (= state change)
- [ ] WIP limits per column (maximum card count per column)
- [ ] Swimlanes (horizontal grouping — e.g., per assignee)
- [ ] Quick preview / hover card
- [ ] Color labels / priorities on cards

## Calendar View

- [ ] Record display with date fields in calendar (day, week, month)
- [ ] Drag & drop for moving / changing date
- [ ] Resize for duration change (date range)
- [ ] Color differentiation by category / state / priority
- [ ] Overlap / collision detection
- [ ] External calendar integration (iCal export)

## Timeline / Gantt View

- [ ] Record display on timeline
- [ ] Dependencies between records (predecessor / successor)
- [ ] Milestones
- [ ] Critical path
- [ ] Drag & drop for rescheduling
- [ ] Zoom levels (day, week, month, quarter)

## Dashboard and Widgets

- [ ] Dashboard defined from metadata (grid layout of widgets)
- [ ] Widget types: number (KPI), chart, table, list, filter, custom HTML
- [ ] Charts: bar, line, pie, donut, area, scatter — driven from metadata
- [ ] Widgets connected to data via configurable queries
- [ ] Interactive widgets (click on chart segment → filters list)
- [ ] Refresh interval per widget
- [ ] User dashboard personalization (rearrange, hide widgets)
- [ ] Dashboard per role / per context

## Field Formatting and Rendering

- [x] Number formatting (thousand separators, decimal places, currency) — currency, percentage, number renderers
- [x] Date formatting (locale-aware, relative time — "3 hours ago") — date, datetime, relative_date renderers
- [x] Custom renderers per field type (progress bar, rating stars, color, avatar...) — 28 built-in renderers + custom renderer registry
- [~] Conditional formatting (red if negative, green if positive) — badge renderer with color_map, limited
- [x] Truncation with tooltip for long texts — truncate renderer
- [x] Value linking (clicking FK value → navigate to related record detail) — internal_link renderer
- [x] Copy-to-clipboard on values — `copy_url` toolbar button + `copy_value` on field values
- [x] Empty value display (empty vs. "—" vs. "N/A" — configurable) — `empty_value_placeholder` helper, configurable per presenter and globally
- [x] Sensitive data masking in UI (by role) — field masking in permissions

## Layout System

- [x] Grid layout (column definition, gaps) — responsive columns per section
- [ ] Responsive breakpoints (how layout changes on mobile / tablet / desktop)
- [~] Sections with collapsible / accordion behavior — `collapsible: true` on form sections; show page sections do not support collapsible
- [~] Tabs for content organization — tabs work on form layout; show page does not support tabs
- [ ] Splitter / resizable panels
- [ ] Sticky header / sidebar
- [ ] Full-screen mode for individual views

## Navigation and Routing

- [x] Menu / navigation generated from metadata — menu.yml with roles, badges, dropdowns
- [x] Breadcrumbs automatically from entity hierarchy — BreadcrumbBuilder
- [ ] Deep linking (every view and filter has unique URL)
- [ ] Back button / navigation history respects context
- [ ] Favorites / bookmarks per user
- [ ] Recently visited records
- [ ] Quick switcher / command palette (Ctrl+K → search entity, record, action)

## Localization and Theming

- [x] All labels, placeholders from localization keys — comprehensive i18n with `lcp_ruby.*` namespaces (toolbar, actions, search, filters, audit, flash, errors, etc.)
- [ ] RTL language support
- [ ] Light / dark mode
- [ ] Custom theme per tenant (colors, logo, fonts)
- [ ] Language switching without reload
- [ ] Format localization (numbers, dates, currencies by locale)

## Print and Export

- [ ] Print layout per view (optimized for print)
- [ ] PDF export with configurable template
- [ ] Current view export (table → XLSX/CSV, detail → PDF)
- [ ] Bulk print (multiple records at once)
- [ ] Print templates (letterhead, invoice, protocol...)

## Accessibility (a11y)

- [~] Keyboard navigation in all views — basic form field navigation via browser defaults, no custom keyboard handling
- [~] ARIA attributes on components — breadcrumbs have `aria-label` and `aria-current`, incomplete coverage elsewhere
- [ ] Screen reader support
- [ ] Sufficient contrast (WCAG AA/AAA)
- [ ] Focus management (correct focus order, focus trap in modals)
- [ ] Skip links for navigation

---

## Key Points

- **Multiple view types per entity** — this is the heart of a metadata-driven presenter. Same data displayed as table, kanban, or calendar just by switching view definition, without writing code.
- **Different layout for create vs. edit** — in practice, the create form is often simpler (fewer fields), edit shows everything. Many platforms don't distinguish this and users are overwhelmed when creating.
- **Warning vs. error in inline validation** — ties into model specification. Presenter must display both types differently (yellow vs. red).
- **Deep linking** — every UI state (view + filter + sorting + page + tab) must have a unique URL. Without this, users can't share links to specific views, which is critical in enterprise environments.
- **Command palette (Ctrl+K)** — modern UX standard. For power users it's often the fastest navigation method and dramatically improves productivity.
- **Conditional formatting** — seems minor but drastically improves table readability (red = problem, green = OK) and is one of the first user requests.
