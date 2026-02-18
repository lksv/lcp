# Architecture

## Overview

LCP Ruby is a Rails mountable engine that generates full CRUD information systems from YAML metadata. Models, presenters (UI config), and permissions are defined in YAML files. The engine dynamically builds ActiveRecord models, database tables, controllers, and views at runtime.

**Data flow:**
```
YAML metadata (config/lcp_ruby/)
  ├── types/*.yml        → Metadata::Loader → TypeDefinition → TypeRegistry
  ├── models/*.yml       → Metadata::Loader → ModelDefinition
  ├── presenters/*.yml   → Metadata::Loader → PresenterDefinition
  └── permissions/*.yml  → Metadata::Loader → PermissionDefinition
                                ↓
              ModelFactory::Builder.build → LcpRuby::Dynamic::<Name>
              (creates AR class + DB table + validations + transforms + associations + scopes)
                                ↓
              LcpRuby.registry.register(name, model_class)
                                ↓
              Engine routes (/:lcp_slug/*) → ResourcesController
              (CRUD with Pundit authorization, presenter-driven UI)
```

## Core Modules

### Metadata (`lib/lcp_ruby/metadata/`)

Parses YAML into typed definition objects.

- **Loader** — loads YAML and DSL from `config/lcp_ruby/{types,models,presenters,permissions}/`; provides `load_all` (types → models → presenters → permissions), and accessors for `model_definitions`, `presenter_definitions`, `permission_definitions`
- **ModelDefinition** — fields, associations, scopes, events, options
- **PresenterDefinition** — index/show/form config, search, actions, navigation
- **PermissionDefinition** — roles, field_overrides, record_rules
- **FieldDefinition** — name, type, label, column_options, validations, default, enum_values
- **AssociationDefinition** — type, name, target_model, class_name, foreign_key, dependent, required
- **ValidationDefinition** — type, options, validator_class
- **EventDefinition** — name, type (lifecycle or field_change), field, condition
- **ConfigurationValidator** — cross-validates all loaded definitions (referenced models exist, field types valid, etc.); used by `lcp_ruby:validate` rake task
- **ErdGenerator** — generates Entity Relationship Diagrams in mermaid, dot, or plantuml formats; used by `lcp_ruby:erd` rake task

**Base field types:** string, text, integer, float, decimal, boolean, date, datetime, enum, file, rich_text, json, uuid

**Built-in business types:** email, phone, url, color (see Types module below)

**Supported validation types:** presence, length, numericality, format, inclusion, exclusion, uniqueness, confirmation, custom

**Association types:** belongs_to, has_many, has_one

### Types (`lib/lcp_ruby/types/`)

Business type system that bundles storage type, transforms, validations, and UI hints into reusable definitions.

- **TypeRegistry** — maps type name (string) → `TypeDefinition`; `register`, `resolve`, `registered?`, `clear!`
- **TypeDefinition** — value object: `name`, `base_type`, `transforms`, `validations`, `input_type`, `display_type`, `column_options`, `html_input_attrs`; `.from_hash` factory, `#column_type` delegates to base type
- **BuiltInTypes** — registers 4 built-in types: `email`, `phone`, `url`, `color`
- **Transforms** — `BaseTransform` + concrete transform classes (`Strip`, `Downcase`, `NormalizeUrl`, `NormalizePhone`); each implements `#call(value)` → value

### Model Factory (`lib/lcp_ruby/model_factory/`)

Builds dynamic ActiveRecord models from metadata definitions.

- **Builder** — orchestrator; creates AR class under `LcpRuby::Dynamic::` namespace, applies enums, validations, transforms, associations, scopes, callbacks, label method, and registers the model in the Registry
- **SchemaManager** — auto-creates/updates DB tables when `auto_migrate: true` is set in configuration; merges type-level column_options before field-level (field wins)
- **ValidationApplicator** — applies AR validations from metadata (standard + custom); after explicit field validations, applies type-default validations (skips if field already has a validation of the same type)
- **TransformApplicator** — for fields with transforms, assembles transform chain from `Services::Registry` and applies `model_class.normalizes :field, with: -> { chain }`
- **AssociationApplicator** — sets up belongs_to, has_many, has_one with options (foreign_key, class_name, dependent, required)
- **ScopeApplicator** — generates scopes from `where`, `where_not`, `order`, `limit`, and custom scope definitions
- **CallbackApplicator** — registers lifecycle callbacks and field_change event triggers that dispatch to the Events system
- **Registry** — central model store; `register`, `model_for`, `registered?`, `all`, `names`, `clear!`

### Authorization (`lib/lcp_ruby/authorization/`)

Permission enforcement via Pundit integration.

- **PermissionEvaluator** — resolves user role via configurable `role_method`; provides `can?(action)` with action aliases (edit->update, new->create); `readable_fields`, `writable_fields` for field-level access; `can_execute_action?`, `can_access_presenter?`, `apply_scope` for row-level filtering; record-level rules evaluation via ConditionEvaluator
- **PolicyFactory** — generates Pundit policy classes dynamically with `index?`, `show?`, `create?`, `update?`, `destroy?`, `new?`, `edit?` + `permitted_attributes` + `Scope` inner class
- **ScopeBuilder** — row-level filtering with scope types: `field_match`, `association`, `where`, `custom`

### ConditionEvaluator (`lib/lcp_ruby/condition_evaluator.rb`)

Evaluates field conditions for record rules and action visibility.

Operators: `eq`, `not_eq`/`neq`, `in`, `not_in`, `gt`, `gte`, `lt`, `lte`, `present`, `blank`

### Presenter (`lib/lcp_ruby/presenter/`)

UI layer that determines what to display and how.

- **Resolver** — `find_by_name`, `find_by_slug`, `presenters_for_model`, `routable_presenters`
- **LayoutBuilder** — builds `form_sections` and `show_sections`; enriches FK fields with synthetic FieldDefinition + AssociationDefinition via foreign_key metadata matching
- **ColumnSet** — permission-filtered `visible_table_columns`, `visible_form_fields`, `visible_show_fields`; `fk_association_map` returns FK-to-association mapping filtered by visible columns (used by index view to render associated object labels instead of raw FK integers)
- **ActionSet** — permission-filtered `collection_actions`, `single_actions` (with visibility conditions via ConditionEvaluator), `batch_actions`
- **IncludesResolver** — auto-detects and resolves association eager loading from presenter metadata. Sub-components: `AssociationDependency` (value object), `DependencyCollector` (gathers deps from presenter/sort/search/manual config), `StrategyResolver` (maps deps to includes/eager_load/joins), `LoadingStrategy` (applies to AR scope)

### Events (`lib/lcp_ruby/events/`)

Event dispatching system for lifecycle and field change hooks.

- **Dispatcher** — `dispatch(event_name:, record:, changes:)`
- **HandlerRegistry** — `register`, `handlers_for`, `discover!` (auto-discovers from `app/event_handlers/`)
- **HandlerBase** — abstract base; `call`, `self.handles_event`, `async?`, `old_value(field)`, `new_value(field)`, `field_changed?(field)`; access to `record`, `changes`, `current_user`, `event_name`
- **AsyncHandlerJob** — ActiveJob wrapper for handlers that return `async? == true`

**Event types:**
- Lifecycle: `after_create`, `after_update`, `before_destroy`, `after_destroy`
- Field change: triggered when a specific field's value changes (configured in model YAML)

### Actions (`lib/lcp_ruby/actions/`)

Custom action system for operations beyond basic CRUD.

- **BaseAction** — abstract base; `call`, `param_schema`, `visible?`, `authorized?`; access to `record`, `records`, `current_user`, `params`, `model_class`; returns `success(message:, redirect_to:, data:)` or `failure(message:, errors:)`
- **ActionRegistry** — `register`, `action_for`, `registered?`, `discover!` (auto-discovers from `app/actions/`)
- **ActionExecutor** — `execute` with authorization check and exception wrapping

**Action types:** `single` (one record), `collection` (no record), `batch` (multiple records)

**Result:** success flag, message, redirect_to, data, errors

### Routing (`lib/lcp_ruby/routing/`)

- **PresenterRoutes** — exists but is unused; only static engine routes defined in `config/routes.rb` are active
- Engine routes use `:lcp_slug` scope with CRUD + action endpoints

## Controller Stack

### ApplicationController (`app/controllers/lcp_ruby/application_controller.rb`)

- Inherits from host app's controller (configurable via `parent_controller`)
- Includes `Pundit::Authorization`
- Before filters: `authenticate_user!` -> `set_presenter_and_model` -> `authorize_presenter_access`
- Helper methods: `current_presenter`, `current_model_definition`, `current_evaluator`, `resource_path`, `resources_path`, `new_resource_path`, `edit_resource_path`, `toggle_direction`
- Error handlers: `Pundit::NotAuthorizedError` (403), `MetadataError` (500)

### ResourcesController (`app/controllers/lcp_ruby/resources_controller.rb`)

- CRUD: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`
- Index pipeline: `policy_scope` -> `apply_search` -> `apply_sort` -> paginate (Kaminari)
- Search: predefined_filters (scope-based) + text search (LIKE on searchable_fields)
- `permitted_params`: writable fields + FK fields from belongs_to associations

### ActionsController (`app/controllers/lcp_ruby/actions_controller.rb`)

- `execute_single`, `execute_collection`, `execute_batch`
- Supports HTML redirect + CSV `send_data` + JSON responses

## Engine Routes (`config/routes.rb`)

```
scope ":lcp_slug" do
  GET  /                                → resources#index
  GET  /new                             → resources#new
  POST /                                → resources#create
  GET  /:id                             → resources#show
  GET  /:id/edit                        → resources#edit
  PATCH/PUT /:id                        → resources#update
  DELETE /:id                           → resources#destroy
  POST /actions/:action_name            → actions#execute_collection
  POST /:id/actions/:action_name        → actions#execute_single
  POST /batch_actions/:action_name      → actions#execute_batch
end
```

## Configuration (`lib/lcp_ruby/configuration.rb`)

| Attribute | Default | Description |
|-----------|---------|-------------|
| `metadata_path` | `Rails.root.join("config", "lcp_ruby")` | Directory containing YAML metadata |
| `role_method` | `:lcp_role` | Method called on user to determine role |
| `user_class` | `"User"` | User model class name |
| `mount_path` | `"/admin"` | Engine mount path |
| `auto_migrate` | `true` | Auto-create/update DB tables on boot |
| `label_method_default` | `:to_s` | Default method for record display labels |
| `parent_controller` | `"::ApplicationController"` | Host app controller to inherit from |

## Engine Loading (`lib/lcp_ruby/engine.rb`)

**Required libraries:** pundit, ransack, kaminari, view_component, turbo-rails, stimulus-rails

**Initializers (in order):**
1. `lcp_ruby.configuration` — sets default metadata_path
2. `lcp_ruby.load_metadata` (after `:load_config_initializers`) — calls `Engine.load_metadata!`
3. `lcp_ruby.assets` — precompiles `lcp_ruby/application.css`

**`load_metadata!` sequence:**
1. `BuiltInTypes.register_all!` + `BuiltInTransforms.register_all!` + `BuiltInDefaults.register_all!` — register built-in types and services
2. `Services::Registry.discover!` — auto-discover host app services from `app/lcp_services/`
3. `Loader.load_all` — load types → models → presenters → permissions (YAML + DSL)
4. Iterate `model_definitions` — for each: `SchemaManager.ensure_table!` + `Builder.build`
5. `Registry.register(name, model_class)` for each built model
6. `check_services!` — verify all service references are valid

**`reload!`** — calls `reset!` then re-runs `load_metadata!`

## Views

Plain ERB templates (no ViewComponents despite gemspec dependency).

- **Layout** (`application.html.erb`) — inline CSS (Bootstrap-inspired), confirm dialog JS
- **Index** (`index.html.erb`) — table with sortable columns, search bar, predefined filter buttons, Kaminari pagination, row actions; display types: `badge`, `currency`, `relative_date`
- **Show** (`show.html.erb`) — sections with field grid or `association_list`; display types: `heading`, `badge`, `link`, `rich_text`, `currency`, `relative_date`
- **Form** (`_form.html.erb`) — sections with grid; resolves input type as: explicit presenter `input_type` → `type_definition.input_type` → base field type. Supported inputs: text/textarea, select (enum), number, date, datetime, boolean, `association_select`, `rich_text_editor`, email, tel, url, color
- **New/Edit** — thin wrappers that render the `_form` partial

## Error Classes (`lib/lcp_ruby.rb`)

- `LcpRuby::Error < StandardError` — base error
- `LcpRuby::MetadataError < Error` — YAML parsing/validation errors
- `LcpRuby::SchemaError < Error` — database schema errors

## Dependencies (gemspec)

| Gem | Version | Purpose |
|-----|---------|---------|
| `rails` | >= 7.1, < 9.0 | Framework |
| `pundit` | ~> 2.3 | Authorization |
| `ransack` | ~> 4.0 | Search |
| `kaminari` | ~> 1.2 | Pagination |
| `view_component` | ~> 3.0 | Listed but unused in views |
| `turbo-rails` | ~> 2.0 | Listed but unused in views |
| `stimulus-rails` | ~> 1.3 | Listed but unused in views |

Ruby requirement: >= 3.1
