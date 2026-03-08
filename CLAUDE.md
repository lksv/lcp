# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

LCP Ruby is a **low-code platform** implemented as a Rails mountable engine for building **full-featured information systems** (not just admin panels). It generates complete CRUD applications from YAML metadata — models, presenters (UI config), and permissions are defined in YAML files. The engine dynamically builds ActiveRecord models, database tables, controllers, and views at runtime.

**Important:** The UI quality target is a production information system, not a quick admin scaffold. Form controls, display renderers, and interaction patterns should match the standards of professional business applications (e.g., proper disabled states via widget APIs, not just CSS overlays).

**Pre-production stage:** This platform is not yet used in production. There is no need to worry about breaking changes, backward compatibility, migration guides, or changelogs. Just make the best design decisions without legacy constraints.

## Configuration Source Principle

**Every platform configuration concept** (custom fields, roles, permissions, groups, workflows, approval processes, etc.) **must support three input sources:**

1. **DSL (or YAML)** — Static definition in code, version-controlled, deployed with the app. YAML files in `config/lcp_ruby/` or Ruby DSL blocks.
2. **Dynamic table (DB)** — Runtime-managed records in the database. Enables end-user configuration through the platform's own UI (generated presenters, management screens).
3. **Host application contract API** — The host app provides its own implementation via a defined interface/contract. The platform consumes it through a registry or adapter pattern.

This principle applies to all existing concepts and **must be followed for every future concept** (workflow, approval process, organizational units, notification rules, etc.). The platform should define a clear contract (required fields, methods, or interface) for each concept, and the three sources are just different ways to fulfill that contract.

**Current status of this principle:**
| Concept | DSL/YAML | DB (dynamic) | Host API |
|---------|----------|--------------|----------|
| Models | YAML + DSL | — | — |
| Presenters | YAML + DSL | — | — |
| Permissions | YAML | — | — |
| Roles | implicit (YAML keys) | `role_source: :model` | `role_method` on user |
| Custom Fields | generator (DSL/YAML) | DB definitions | contract validator |
| Types | YAML | — | — |
| Menu | YAML | — | — |
| Groups | YAML (`groups.yml`) | DB definitions (`group_source: :model`) | host adapter (`group_source: :host`) |
| Saved Filters | presets (presenter YAML/DSL) | DB model via generator | — |
| Workflows | — | — | — |

**Table creation rule:** All database tables must be defined through the platform's YAML model definitions (which `SchemaManager` creates at boot) or through generators. Never create tables via ad-hoc `create_table` calls in Ruby code. If a feature needs internal tables (e.g., audit logs, workflow logs), provide a generator that creates the model YAML/DSL, or let the user define them as standard YAML models.

## i18n Principle

**All user-visible text must use Rails i18n.** No hardcoded strings in views, controllers, or helpers. No `label` keys in YAML metadata — YAML defines structure only, locale files define text.

**Lookup convention:** `I18n.t("lcp_ruby.<namespace>.<key>", default: "Humanized fallback")`

Key namespaces:
- `lcp_ruby.toolbar.*` — toolbar buttons (copy_url, back_to_list, etc.)
- `lcp_ruby.actions.*` — CRUD action labels (show, edit, delete, create, confirm_delete)
- `lcp_ruby.filters.<name>` — predefined filter labels (derived from scope name)
- `lcp_ruby.presenters.<presenter>.sections.<section>` — section titles
- `lcp_ruby.flash.*` — flash messages (created, updated, deleted) with `%{model}` interpolation
- `lcp_ruby.search.*` — search placeholder and submit
- `lcp_ruby.errors.*` — error pages (not_found, etc.)
- `lcp_ruby.empty_value` — placeholder for nil/empty values in display
- `lcp_ruby.audit_history.*` — audit history section (title, action labels, change labels)

The fallback (`default:`) is always the humanized key name so the app works without a locale file.

## Documentation

- [Documentation Index](docs/README.md) — Links to all documentation
- [Getting Started](docs/getting-started.md) — Installation and first model tutorial
- [Models Reference](docs/reference/models.md) — Complete model YAML reference (fields, associations, scopes, events, virtual columns)
- [API-Backed Models Reference](docs/reference/api-backed-models.md) — External data sources: REST JSON adapter, host providers, cross-source associations, caching
- [Types Reference](docs/reference/types.md) — Custom business types (email, phone, url, color, and user-defined)
- [Presenters Reference](docs/reference/presenters.md) — Complete presenter YAML reference
- [View Groups Reference](docs/reference/view-groups.md) — Navigation menu, view switching, auto-creation
- [Menu Reference](docs/reference/menu.md) — Configurable navigation: top bar, sidebar, dropdowns, badges, role visibility
- [Custom Fields Reference](docs/reference/custom-fields.md) — Runtime user-defined fields: definitions, types, permissions, querying
- [Role Source Reference](docs/reference/role-source.md) — DB-backed role model: contract, registry, cache invalidation, generator
- [Permission Source Reference](docs/reference/permission-source.md) — DB-backed permissions: JSON definitions, registry, cache invalidation, generator
- [Groups Reference](docs/reference/groups.md) — Organizational groups: YAML, DB, host adapter, role mapping
- [Permissions Reference](docs/reference/permissions.md) — Complete permission YAML reference
- [Condition Operators](docs/reference/condition-operators.md) — Shared operator reference (15 operators, dynamic value references incl. lookup, collection quantifiers)
- [Auditing Reference](docs/reference/auditing.md) — Change tracking: audit log model, field diffs, JSON/custom field expansion, configuration
- [Eager Loading Reference](docs/reference/eager-loading.md) — Auto-detection, manual overrides, strategy resolution, strict_loading
- [Tree Structures Reference](docs/reference/tree-structures.md) — Declarative tree hierarchies: model options, traversal, reparenting, tree index view
- [Pages Reference](docs/reference/pages.md) — Page YAML format, zones, widget types (kpi_card, text, list), grid positioning, auto-pages, dialog-only pages, composite pages (semantic layout, tabs, scope_context)
- [Dialogs Reference](docs/reference/dialogs.md) — Dialog actions, confirm variants (boolean, role, styled, page-based), routing, virtual model flow
- [View Slots Reference](docs/reference/view-slots.md) — Extensible page layout: slot registry, slot names, SlotContext, position ordering
- [Engine Configuration](docs/reference/engine-configuration.md) — `LcpRuby.configure` options
- [Model DSL Reference](docs/reference/model-dsl.md) — Ruby DSL alternative to YAML for models
- [Presenter DSL Reference](docs/reference/presenter-dsl.md) — Ruby DSL alternative to YAML for presenters (with inheritance)
- [Presenters Guide](docs/guides/presenters.md) — Step-by-step guide to building presenters with YAML and DSL examples
- [Selectbox Guide](docs/guides/selectbox.md) — Association select, cascading selects, remote search, multi-select, tree select, scoping, disabled options, legacy records, codelists
- [Custom Types Guide](docs/guides/custom-types.md) — Practical examples of custom business types
- [Virtual Columns Guide](docs/guides/virtual-columns.md) — Query-time computed columns: declarative aggregates, SQL expressions, JOINs, GROUP BY, services, auto-include
- [Computed Fields Guide](docs/guides/computed-fields.md) — Auto-calculated persisted fields: template interpolation, service logic, arithmetic
- [Sequence Fields Guide](docs/guides/sequences.md) — Gap-free auto-numbering: scoped counters, format templates, counter management
- [Extensibility Guide](docs/guides/extensibility.md) — All extension mechanisms: actions, events, transforms, validations, scopes, condition services
- [Conditional Rendering](docs/guides/conditional-rendering.md) — `visible_when`, `disable_when`, `item_classes`: simple, compound (all/any/not), dot-path, dynamic references, collection conditions, lookup value references, DSL builder
- [Custom Actions](docs/guides/custom-actions.md) — Writing custom actions
- [Event Handlers](docs/guides/event-handlers.md) — Writing event handlers
- [Custom Renderers Guide](docs/guides/custom-renderers.md) — Custom renderers for host applications
- [Attachments Guide](docs/guides/attachments.md) — File upload with Active Storage
- [Userstamps Guide](docs/guides/userstamps.md) — Automatic created_by / updated_by tracking: setup, name snapshots, presenter display
- [Soft Delete Guide](docs/guides/soft-delete.md) — Discard/restore, cascade, archive presenters, permissions
- [Auditing Guide](docs/guides/auditing.md) — Change tracking: setup, field filtering, JSON expansion, custom writer, show page integration
- [Eager Loading Guide](docs/guides/eager-loading.md) — N+1 prevention, strict_loading, manual overrides
- [Tree Structures Guide](docs/guides/tree-structures.md) — Declarative tree hierarchies: setup, tree index view, drag-and-drop reparenting, search
- [View Groups Guide](docs/guides/view-groups.md) — Multi-view navigation and view switcher setup
- [Menu Guide](docs/guides/menu.md) — Custom navigation menus: dropdowns, sidebar, combined layouts, badges
- [Custom Fields Guide](docs/guides/custom-fields.md) — Runtime user-defined fields: enabling, defining, sections, permissions
- [Role Source Guide](docs/guides/role-source.md) — DB-backed role management: setup, validation, cache, testing
- [Permission Source Guide](docs/guides/permission-source.md) — DB-backed permission management: runtime editing, JSON definitions
- [Groups Guide](docs/guides/groups.md) — Organizational groups: YAML, DB, host adapter, testing
- [Hierarchical Authorization](docs/guides/hierarchical-authorization.md) — Multi-level parent-child access control (factory → production line → machine → sensor reading)
- [Impersonation Guide](docs/guides/impersonation.md) — "View as Role X" for testing permissions
- [Tiles View Guide](docs/guides/tiles.md) — Card grid layout: tile configuration, sort dropdown, per-page selector, summary bar
- [View Slots Guide](docs/guides/view-slots.md) — Extending page layouts: custom toolbar buttons, widgets, conditional components
- [API-Backed Models Guide](docs/guides/api-backed-models.md) — Integrating external REST APIs and host-provided data sources
- [Dashboards Guide](docs/guides/dashboards.md) — Standalone grid pages: KPI cards, text widgets, list widgets, presenter zones, landing page
- [Composite Pages Guide](docs/guides/composite-pages.md) — Record-bound multi-zone pages: semantic layout, tabs, scope_context, per-zone authorization
- [Dialogs Guide](docs/guides/dialogs.md) — Quick create/edit dialogs, virtual model dialogs, styled/page-based confirms
- [Developer Tools](docs/guides/developer-tools.md) — Validate, ERD, and permissions rake tasks
- [Host Application Guide](docs/guides/host-application.md) — Creating a new host application from scratch: scaffold, models, presenters, permissions, groups, seeds
- [Architecture](docs/architecture.md) — Module structure, data flow, controllers, views
- [Examples](docs/examples.md) — TODO and CRM app walkthroughs

## Commands

```bash
# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/lib/lcp_ruby/authorization/permission_evaluator_spec.rb

# Run a single test by line
bundle exec rspec spec/integration/todo_spec.rb:31

# Run only unit tests
bundle exec rspec spec/lib/

# Run only integration tests
bundle exec rspec spec/integration/

# Run tests with coverage report (HTML report in tmp/coverage/index.html)
COVERAGE=1 bundle exec rspec

# Lint
bundle exec rubocop

# Lint with auto-fix
bundle exec rubocop -a

# Generate custom fields metadata (run from host app directory)
bundle exec rails generate lcp_ruby:custom_fields          # DSL format (default)
bundle exec rails generate lcp_ruby:custom_fields --format=yaml  # YAML format

# Validate YAML metadata (run from example app directory when changing examples/)
bundle exec rake lcp_ruby:validate

# Run example apps (from their directory)
cd examples/todo && bundle exec rails db:prepare && bundle exec rails s -p 3000
cd examples/crm && bundle exec rails db:prepare && bundle exec rails s -p 3001
```

**Important:** When making changes in `examples/` apps, always run `bundle exec rake lcp_ruby:validate` from that example app's directory to verify YAML metadata is valid.

**Important:** When changing or extending the YAML config schema (models, presenters, permissions, view groups), always update `ConfigurationValidator` (`lib/lcp_ruby/metadata/configuration_validator.rb`) and its tests accordingly.

## Architecture

### Data Flow

```
YAML metadata (config/lcp_ruby/)
  ├── types/*.yml        → Metadata::Loader → TypeDefinition → TypeRegistry
  ├── models/*.yml       → Metadata::Loader → ModelDefinition
  ├── presenters/*.yml   → Metadata::Loader → PresenterDefinition
  ├── permissions/*.yml  → Metadata::Loader → PermissionDefinition
  └── menu.yml           → Metadata::Loader → MenuDefinition → MenuItem (with badges)
                                ↓
              ModelFactory::Builder.build → LcpRuby::Dynamic::<Name>
              (creates AR class + DB table + validations + transforms + associations + scopes)
              (virtual models with table_name: _virtual are skipped — metadata only, no AR class)
              (API models → ApiBuilder creates ActiveModel class, skips DB/AR-specific applicators)
                                ↓
              LcpRuby.registry.register(name, model_class)
                                ↓
              DataSource::Setup.apply!(loader) → instantiate adapters, wrap with cache/resilient,
              attach to API model classes, apply cross-source associations
                                ↓
              CustomFields::Setup.apply!(loader) → contract validation, registry, handlers, accessors, scopes
                                ↓
              Roles::Setup.apply!(loader) → contract validation, registry, change handler (if role_source == :model)
                                ↓
              Permissions::Setup.apply!(loader) → contract validation, registry, change handler, definition validator (if permission_source == :model)
                                ↓
              Groups::Setup.apply!(loader) → YAML/DB/host loader, registry, change handler (if group_source != :none)
                                ↓
              Auditing::Setup.apply!(loader) → contract validation, registry mark_available! (if any model has auditing: true)
                                ↓
              ConditionServiceRegistry.discover! → condition services from app/condition_services/
              Services::Registry.discover! → data providers from app/lcp_services/data_providers/
              Display::RendererRegistry.register_built_ins! → 26 built-in renderers + badge renderers
              Display::RendererRegistry.discover! → custom renderers from app/renderers/
              ViewSlots::Registry.register_built_ins! → 11 built-in slot components (toolbar, filters, pagination)
                                ↓
              Pages::Resolver → slug/name lookup → PageDefinition → zones → presenters
                                ↓
              Engine routes (/:lcp_slug/*) → ResourcesController
              Dialog routes (/lcp_dialog/:page_name/*) → DialogsController
              (CRUD with Pundit authorization, presenter-driven UI, conditional rendering,
               composite pages with semantic layout, tabs, scope_context scoping)
```

### Key Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `Metadata` | `lib/lcp_ruby/metadata/` | Parses YAML into definition objects (ModelDefinition, PresenterDefinition, etc.) |
| `Types` | `lib/lcp_ruby/types/` | TypeRegistry, TypeDefinition, ServiceRegistry, built-in types (email, phone, url, color), transforms (strip, downcase, normalize_url, normalize_phone) |
| `ModelFactory` | `lib/lcp_ruby/model_factory/` | Builds dynamic AR models: Builder orchestrates SchemaManager, ValidationApplicator, TransformApplicator, AssociationApplicator, VirtualColumnApplicator, ScopeApplicator, PositioningApplicator, UserstampsApplicator, SoftDeleteApplicator, AuditingApplicator, TreeApplicator, SequenceApplicator (gap-free auto-numbering with scoped counters). ApiBuilder builds ActiveModel classes for API-backed models. ApiAssociationApplicator creates cross-source association accessors |
| `Sequences` | `lib/lcp_ruby/sequences/` | SequenceManager (admin API: set/current/list counter values), `build_scope_key` (scope hash to string key). Counter table via generator (`lcp_ruby:gapfree_sequences`) |
| `DataSource` | `lib/lcp_ruby/data_source/` | API-backed model infrastructure: Base (contract), RestJson (HTTP adapter), Host (provider delegation), CachedWrapper (Rails.cache TTL), ResilientWrapper (error handling), ApiModelConcern (ActiveModel mixin), ApiFilterTranslator (Ransack→portable filter translation), ApiPreloader (batch N+1 prevention), ApiErrorPlaceholder (graceful degradation), Registry, Setup (boot orchestration) |
| `VirtualColumns` | `lib/lcp_ruby/virtual_columns/` | Builder: injects SQL subqueries, expressions, JOINs, and GROUP BY into ActiveRecord scopes. Collector: auto-detects needed VCs from presenter metadata per context. Supports declarative aggregates, expression columns, JOIN-based columns, service-based VCs with `:current_user` placeholder, soft-delete filtering, and COALESCE defaults. `Aggregates::QueryBuilder` is a backward-compat alias |
| `Presenter` | `lib/lcp_ruby/presenter/` | UI layer: Resolver (find by slug), LayoutBuilder (form/show sections + normalize_json_field_section for json_field: sources + sub-section enrichment), ColumnSet (visible columns), ActionSet (visible actions with record_rules integration via action_permitted_for_record?), IncludesResolver (auto-detects and applies eager loading from presenter metadata), FieldValueResolver (dot-path, template, FK, and simple field resolution with permission checks) |
| `CustomFields` | `lib/lcp_ruby/custom_fields/` | Registry (per-model definition cache), Applicator (dynamic accessors + validations + defaults + stale cleanup), ContractValidator (boot-time model contract checks), Query (DB-portable JSON queries with field name validation), DefinitionChangeHandler (cache invalidation), Setup (shared boot logic with contract validation), Utils (env-aware JSON/numeric parsing) |
| `Roles` | `lib/lcp_ruby/roles/` | Registry (thread-safe role name cache), ContractValidator (boot-time model contract checks), ChangeHandler (after_commit cache invalidation), Setup (boot orchestration). Only active when `role_source == :model` |
| `Permissions` | `lib/lcp_ruby/permissions/` | Registry (per-model PermissionDefinition cache), ContractValidator (boot-time model contract checks), ChangeHandler (after_commit cache invalidation + PolicyFactory clear), DefinitionValidator (JSON validation on save), SourceResolver (DB → YAML priority chain), Setup (boot orchestration). Only active when `permission_source == :model` |
| `Groups` | `lib/lcp_ruby/groups/` | Contract (interface), Registry (thread-safe, delegates to loader), YamlLoader (static groups from YAML), ModelLoader (DB queries), HostLoader (adapter delegation), ContractValidator (group/membership/mapping models), ChangeHandler (after_commit cache invalidation), Setup (boot orchestration by group_source). Integrates with PermissionEvaluator via role_resolution_strategy |
| `Display` | `lib/lcp_ruby/display/` | BaseRenderer (base class), 26 built-in renderer classes in `renderers/`, badge renderers (CountBadge, TextBadge, IconBadge), RendererRegistry (registers built-ins + auto-discovers host renderers from `app/renderers/`) |
| `Authorization` | `lib/lcp_ruby/authorization/` | PolicyFactory (dynamic Pundit policies), PermissionEvaluator (can?, can_for_record? with alias resolution, readable_fields, writable_fields, with optional role validation via Roles::Registry), ScopeBuilder |
| `Events` | `lib/lcp_ruby/events/` | Dispatcher + HandlerRegistry. Host apps define handlers in `app/event_handlers/` |
| `Actions` | `lib/lcp_ruby/actions/` | ActionExecutor + ActionRegistry. Host apps define custom actions in `app/actions/` |
| `Conditions` | `lib/lcp_ruby/condition_evaluator.rb`, `lib/lcp_ruby/condition_service_registry.rb`, `lib/lcp_ruby/dsl/condition_builder.rb` | ConditionEvaluator (strict: 15 operators, raises ConditionError on unknown operator/missing field), ConditionServiceRegistry. Supports compound (all/any/not), dot-path fields, collection quantifiers, dynamic value references (field_ref, current_user, date, service, lookup). DSL via `ConditionBuilder.build` block and `ConditionBuilder.lookup` helper. All condition callers (PermissionEvaluator, ActionSet, views) delegate to ConditionEvaluator. Host apps define condition services in `app/condition_services/` |
| `Search` | `lib/lcp_ruby/search/` | QuickSearch (type-aware text search), ParamSanitizer (filter param cleanup), FilterParamBuilder (LCP operators to Ransack predicates), OperatorRegistry (type-to-operator mapping), CustomFilterInterceptor (filter_* method detection and interception), CustomFieldFilter (JSON column queries with type casting), FilterMetadataBuilder (permission-aware JSON metadata for the visual filter builder), QueryLanguageParser (recursive descent QL parser), QueryLanguageSerializer (condition tree to QL text), ParameterizedScopeApplicator (typed parameter casting, min/max clamping, filter_*/scope dispatch). Ransack model setup (`ransackable_attributes`, `ransackable_associations`) handled by `ModelFactory::RansackApplicator` at boot |
| `SavedFilters` | `lib/lcp_ruby/saved_filters/` | Generator-based saved filter model (not hardcoded). SavedFiltersGenerator creates model/presenter/permissions YAML. Presenter config via `saved_filters` block inside `advanced_filter` (enabled, display mode, max_visible_pinned). Visibility: personal/role/group/global with ownership record_rules |
| `Attachments` | `lib/lcp_ruby/model_factory/attachment_applicator.rb` | Applies Active Storage macros (has_one_attached/has_many_attached), validations (size, content_type, max_files), and variant config to dynamic models |
| `Positioning` | `lib/lcp_ruby/model_factory/positioning_applicator.rb` | Applies `positioning` gem macro to positioned models; SchemaManager creates unique indices on scope + position columns (except SQLite) |
| `Auditing` | `lib/lcp_ruby/auditing/` | Registry (available? flag), ContractValidator (audit model contract checks), AuditWriter (field diffs, JSON/custom field expansion, nested changes), Setup (boot orchestration). AuditingApplicator installs AR callbacks on audited models |
| `UserSnapshot` | `lib/lcp_ruby/user_snapshot.rb` | Captures `{id, email, name, role}` from user objects; used by auditing and userstamps |
| `BulkUpdater` | `lib/lcp_ruby/bulk_updater.rb` | `tracked_update_all` wrapper with yield hook for post-update callbacks (auditing, events) |
| `Pages` | `lib/lcp_ruby/pages/` | Resolver (slug/name lookup), ScopeContextResolver (dynamic reference resolution: `:record_id`, `:record.<field>`, `:current_user`, `:current_user_id`, `:current_year`, `:current_date`; single-level dot-path depth limit enforced via `MAX_DOT_PATH_DEPTH = 1`), auto-page creation from presenters, PageDefinition (name, slug, model, layout, dialog_config, zones; composite helpers: `composite?`, `semantic?`, `zones_for_area`, `tab_zones`, `has_tabs?`, `has_sidebar?`, `has_below?`), ZoneDefinition (presenter/widget zones, grid positioning, visible_when, scope_context, label_key) |
| `Widgets` | `lib/lcp_ruby/widgets/` | DataResolver (kpi_card aggregate, text i18n, list records; accepts scope_context), PresenterZoneResolver (accepts scope_context), ScopeApplicator (shared scope/model resolution, policy scope, soft delete filtering, scope_context WHERE/filter_* application) |
| `ViewSlots` | `lib/lcp_ruby/view_slots/` | Registry (page+slot component store with position ordering), SlotComponent (immutable value object: name, partial, position, enabled callback), SlotContext (immutable data bag for slot partials: presenter, evaluator, params, records, record, locals). ViewSlotHelper provides `render_slot` for ERB templates. 11 built-in components registered at boot |
| `JsonItemWrapper` | `lib/lcp_ruby/json_item_wrapper.rb` | ActiveModel wrapper for JSON hash items; dynamic getter/setter per field from ModelDefinition; type coercion (integer, float, boolean); `validate_with_model_rules!` (presence, length, numericality, format); `to_hash` for persistence. Used by `json_field:` + `target_model:` nested sections |

### Controller Stack

`ApplicationController` (`app/controllers/lcp_ruby/application_controller.rb`):
- Inherits from host app's controller (configurable via `parent_controller`)
- Resolves presenter + model from `:lcp_slug` URL param
- Sets up `current_evaluator` (PermissionEvaluator) for the current user/role
- Provides path helpers: `resource_path`, `resources_path`, `edit_resource_path`

`ResourcesController` (`app/controllers/lcp_ruby/resources_controller.rb`):
- Standard CRUD (index/show/new/create/edit/update/destroy)
- Composite pages: `show` branches on `current_page.composite?` → `load_composite_page` resolves main zone, active tab (`?tab=`), scope_context per zone via `ScopeContextResolver`, per-zone authorization, `visible_when` conditions, and delegates to `PresenterZoneResolver`/`DataResolver`
- `permitted_params` filters by writable fields + association FK fields
- `apply_advanced_search` 7-step pipeline: default scope, predefined filter scope, param sanitization, custom filter interception, Ransack query, quick search (`?qs=`), custom field filters (`?cf[...]`)
- Authorization via Pundit on every action

`CustomFieldsController` (`app/controllers/lcp_ruby/custom_fields_controller.rb`):
- Nested under `/:lcp_slug/custom-fields` for managing custom field definitions
- Dual context: parent model from `:lcp_slug`, CFD model + generated presenter for views
- Records scoped by `target_model` from parent URL context (prevents cross-model access)
- Reuses `lcp_ruby/resources` views via `controller_path` override
- Separate authorization via `custom_field_definition` permissions

`DialogsController` (`app/controllers/lcp_ruby/dialogs_controller.rb`):
- Handles dialog-only pages (no slug) at `/lcp_dialog/:page_name/*`
- Resolves presenter and model from the page definition
- Supports both persistent models (AR create/update) and virtual models (JsonItemWrapper validation + `dialog_submit` event)
- Uses `DialogRendering` concern for dialog frame rendering and success responses
- `DialogRendering` concern also mixed into `ResourcesController` for `?_dialog=1` context detection

### Routing

Engine mounts at a configurable path (default `/`). All resources use a slug-based pattern:
```
/:lcp_slug                     → resources#index
/:lcp_slug/new                 → resources#new
/:lcp_slug/:id                 → resources#show
/:lcp_slug/:id/edit            → resources#edit
/:lcp_slug/filter_fields           → resources#filter_fields (GET, JSON filter metadata)
/:lcp_slug/parse_ql                → resources#parse_ql (POST, QL text → condition tree)
/:lcp_slug/custom-fields           → custom_fields#index
/:lcp_slug/custom-fields/manage    → custom_fields#manage (bulk editor)
/:lcp_slug/custom-fields/:id       → custom_fields#show
/lcp_dialog/:page_name/new        → dialogs#new (dialog-only page)
/lcp_dialog/:page_name            → dialogs#create (POST)
/lcp_dialog/:page_name/:id/edit   → dialogs#edit
/lcp_dialog/:page_name/:id        → dialogs#update (PATCH)
```

The slug comes from the presenter YAML (e.g., `slug: deals` → `/deals`). Dialog routes use page names instead of slugs.

### How Association Selects Work

When a form field has `input_type: association_select` (e.g., `todo_list_id`):
1. `LayoutBuilder.normalize_section` matches the FK field name against `association.foreign_key` metadata
2. Creates a synthetic `FieldDefinition` (type: integer) and attaches the `AssociationDefinition`
3. `_form.html.erb` renders a `<select>` populated from the target model's records via `LcpRuby.registry.model_for(assoc.target_model)`
4. FK fields bypass the `field_writable?` check (they're permitted separately in the controller)

### Permission System

Permissions YAML defines roles with: `crud` list, `fields` (readable/writable), `actions`, `scope`, `presenters`. The `PermissionEvaluator.can?` method maps action aliases (`edit` → `update`, `new` → `create`) before checking the CRUD list. Record-level rules (`record_rules`) can deny specific CRUD operations based on field conditions with role exceptions. `can_for_record?` resolves action aliases and delegates condition evaluation to `ConditionEvaluator.evaluate_any` (all 15 operators, compound/collection/dot-path/lookup). Record rules automatically hide built-in `edit`/`destroy` action buttons on index pages via `ActionSet#action_permitted_for_record?`.

## Test Structure

- **Unit tests**: `spec/lib/lcp_ruby/` — test individual subsystems against YAML fixtures in `spec/fixtures/metadata/`
- **Integration tests**: `spec/integration/` — test full HTTP request cycle using fixtures in `spec/fixtures/integration/{todo,crm}/`
- **Dummy app**: `spec/dummy/` — minimal Rails app that mounts the engine at `/`
- **Integration helper**: `spec/support/integration_helper.rb` — provides `load_integration_metadata!` and `stub_current_user` for request specs
- Each test resets `LcpRuby.reset!` and clears Dynamic constants before running (see `spec_helper.rb`)

## YAML Metadata Conventions

**Model fields**: base types are `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`, `enum`, `file`, `rich_text`, `json`, `uuid`, `attachment`, `array`. Built-in business types: `email`, `phone`, `url`, `color`. Custom types can be defined in `config/lcp_ruby/types/`.

**Scopes**: support `where`, `where_not`, `order`, `limit`. The `where_not` key generates `scope :name, -> { where.not(...) }`.

**Presenter actions**: `type: built_in` actions (show, edit, destroy, create) check `PermissionEvaluator.can?`. `type: custom` actions check `can_execute_action?` and dispatch to registered action classes.

## Error Handling

**Never use `expression rescue nil`** or bare `rescue` to silently swallow exceptions. Always rescue the specific exception class you expect (`rescue KeyError`, `rescue ActiveRecord::RecordNotFound`, etc.).

If graceful degradation is genuinely needed (e.g., a renderer should not crash the whole page), use environment-aware handling:

```ruby
begin
  risky_operation
rescue SpecificError => e
  raise unless Rails.env.production?
  Rails.logger.error("[LcpRuby] #{e.class}: #{e.message} (model=#{model_name}, field=#{field_name})")
  nil # or fallback value
end
```

Log messages must include enough context to identify the source: model/table name, field name, presenter, record ID, or whatever is relevant to the call site. In development and test environments, exceptions must always propagate so bugs are caught early.

## Feature Specification Template

Feature Specifications live in `docs/design/` and describe **planned features at a high level** — the problem, user scenarios, configuration, and general approach. They are not implementation plans (no specific classes, files, or line numbers).

**Template structure:**

```markdown
# Feature Specification: <Feature Name>

**Status:** Proposed | In Progress | Implemented
**Date:** <YYYY-MM-DD>

## Problem / Motivation

What frustrates users today? What can't they do? Why does it matter?

## User Scenarios

Concrete "As a user, I want to..." stories showing how the feature will be used in practice.

## Configuration & Behavior

Settings, defaults, edge cases. Include DSL/YAML config examples where relevant.
Describe the user-facing behavior in enough detail that someone could test it.

## Usage Examples

## General Implementation Approach

Algorithm, architectural direction, key data flows. High-level description
of **how** the feature works — no specific classes, files, or line numbers.
Focus on the "shape" of the solution.

## Decisions

Chosen approach from open questions and high-level architecture decisions
that were already resolved. Record the decision and brief rationale.

## Open Questions

Unresolved design questions, trade-offs still under consideration,
areas that need user feedback or prototyping.
```

**Guidelines:**
- Write in English
- Keep it concise — the spec should be readable in 5 minutes
- DSL/YAML examples should show realistic configuration, not toy examples
- "General Implementation Approach" describes algorithms and data flows, not code structure
- Link related specs or design docs where relevant

## Dependencies

Core: `rails` (>= 7.1), `pundit` (authorization), `kaminari` (pagination), `ransack` (search). Linting: `rubocop-rails-omakase`.
