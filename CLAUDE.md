# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

LCP Ruby is a **low-code platform** implemented as a Rails mountable engine for building **full-featured information systems** (not just admin panels). It generates complete CRUD applications from YAML metadata — models, presenters (UI config), and permissions are defined in YAML files. The engine dynamically builds ActiveRecord models, database tables, controllers, and views at runtime.

**Important:** The UI quality target is a production information system, not a quick admin scaffold. Form controls, display renderers, and interaction patterns should match the standards of professional business applications (e.g., proper disabled states via widget APIs, not just CSS overlays).

**Pre-production stage:** This platform is not yet used in production. There is no need to worry about breaking changes, backward compatibility, migration guides, or changelogs. Just make the best design decisions without legacy constraints.

## Documentation

- [Documentation Index](docs/README.md) — Links to all documentation
- [Getting Started](docs/getting-started.md) — Installation and first model tutorial
- [Models Reference](docs/reference/models.md) — Complete model YAML reference
- [Types Reference](docs/reference/types.md) — Custom business types (email, phone, url, color, and user-defined)
- [Presenters Reference](docs/reference/presenters.md) — Complete presenter YAML reference
- [View Groups Reference](docs/reference/view-groups.md) — Navigation menu, view switching, auto-creation
- [Menu Reference](docs/reference/menu.md) — Configurable navigation: top bar, sidebar, dropdowns, badges, role visibility
- [Custom Fields Reference](docs/reference/custom-fields.md) — Runtime user-defined fields: definitions, types, permissions, querying
- [Role Source Reference](docs/reference/role-source.md) — DB-backed role model: contract, registry, cache invalidation, generator
- [Permissions Reference](docs/reference/permissions.md) — Complete permission YAML reference
- [Condition Operators](docs/reference/condition-operators.md) — Shared operator reference
- [Eager Loading Reference](docs/reference/eager-loading.md) — Auto-detection, manual overrides, strategy resolution, strict_loading
- [Engine Configuration](docs/reference/engine-configuration.md) — `LcpRuby.configure` options
- [Model DSL Reference](docs/reference/model-dsl.md) — Ruby DSL alternative to YAML for models
- [Presenter DSL Reference](docs/reference/presenter-dsl.md) — Ruby DSL alternative to YAML for presenters (with inheritance)
- [Presenters Guide](docs/guides/presenters.md) — Step-by-step guide to building presenters with YAML and DSL examples
- [Custom Types Guide](docs/guides/custom-types.md) — Practical examples of custom business types
- [Extensibility Guide](docs/guides/extensibility.md) — All extension mechanisms: actions, events, transforms, validations, scopes, condition services
- [Conditional Rendering](docs/guides/conditional-rendering.md) — `visible_when` and `disable_when` on fields, sections, and actions
- [Custom Actions](docs/guides/custom-actions.md) — Writing custom actions
- [Event Handlers](docs/guides/event-handlers.md) — Writing event handlers
- [Custom Renderers Guide](docs/guides/custom-renderers.md) — Custom renderers for host applications
- [Attachments Guide](docs/guides/attachments.md) — File upload with Active Storage
- [Eager Loading Guide](docs/guides/eager-loading.md) — N+1 prevention, strict_loading, manual overrides
- [View Groups Guide](docs/guides/view-groups.md) — Multi-view navigation and view switcher setup
- [Menu Guide](docs/guides/menu.md) — Custom navigation menus: dropdowns, sidebar, combined layouts, badges
- [Custom Fields Guide](docs/guides/custom-fields.md) — Runtime user-defined fields: enabling, defining, sections, permissions
- [Role Source Guide](docs/guides/role-source.md) — DB-backed role management: setup, validation, cache, testing
- [Impersonation Guide](docs/guides/impersonation.md) — "View as Role X" for testing permissions
- [Developer Tools](docs/guides/developer-tools.md) — Validate, ERD, and permissions rake tasks
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

# Lint
bundle exec rubocop

# Lint with auto-fix
bundle exec rubocop -a

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
                                ↓
              LcpRuby.registry.register(name, model_class)
                                ↓
              CustomFields::BuiltInModel → custom_field_definition model (auto-created)
              CustomFields::Setup.apply!(loader) → registry, handlers, accessors, scopes, presenters
                                ↓
              Roles::Setup.apply!(loader) → contract validation, registry, change handler (if role_source == :model)
                                ↓
              ConditionServiceRegistry.discover! → condition services from app/condition_services/
              Services::Registry.discover! → data providers from app/lcp_services/data_providers/
              Display::RendererRegistry.register_built_ins! → 26 built-in renderers + badge renderers
              Display::RendererRegistry.discover! → custom renderers from app/renderers/
                                ↓
              Engine routes (/:lcp_slug/*) → ResourcesController
              (CRUD with Pundit authorization, presenter-driven UI, conditional rendering)
```

### Key Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `Metadata` | `lib/lcp_ruby/metadata/` | Parses YAML into definition objects (ModelDefinition, PresenterDefinition, etc.) |
| `Types` | `lib/lcp_ruby/types/` | TypeRegistry, TypeDefinition, ServiceRegistry, built-in types (email, phone, url, color), transforms (strip, downcase, normalize_url, normalize_phone) |
| `ModelFactory` | `lib/lcp_ruby/model_factory/` | Builds dynamic AR models: Builder orchestrates SchemaManager, ValidationApplicator, TransformApplicator, AssociationApplicator, ScopeApplicator |
| `Presenter` | `lib/lcp_ruby/presenter/` | UI layer: Resolver (find by slug), LayoutBuilder (form/show sections), ColumnSet (visible columns), ActionSet (visible actions), IncludesResolver (auto-detects and applies eager loading from presenter metadata), FieldValueResolver (dot-path, template, FK, and simple field resolution with permission checks) |
| `CustomFields` | `lib/lcp_ruby/custom_fields/` | Registry (per-model definition cache), Applicator (dynamic accessors + validations + defaults + stale cleanup), BuiltInModel (definition schema), BuiltInPresenter (auto-generated management UI, scoped by target_model), Query (DB-portable JSON queries with field name validation), DefinitionChangeHandler (cache invalidation), Setup (shared boot logic), Utils (env-aware JSON/numeric parsing) |
| `Roles` | `lib/lcp_ruby/roles/` | Registry (thread-safe role name cache), ContractValidator (boot-time model contract checks), ChangeHandler (after_commit cache invalidation), Setup (boot orchestration). Only active when `role_source == :model` |
| `Display` | `lib/lcp_ruby/display/` | BaseRenderer (base class), 26 built-in renderer classes in `renderers/`, badge renderers (CountBadge, TextBadge, IconBadge), RendererRegistry (registers built-ins + auto-discovers host renderers from `app/renderers/`) |
| `Authorization` | `lib/lcp_ruby/authorization/` | PolicyFactory (dynamic Pundit policies), PermissionEvaluator (can?, readable_fields, writable_fields, with optional role validation via Roles::Registry), ScopeBuilder |
| `Events` | `lib/lcp_ruby/events/` | Dispatcher + HandlerRegistry. Host apps define handlers in `app/event_handlers/` |
| `Actions` | `lib/lcp_ruby/actions/` | ActionExecutor + ActionRegistry. Host apps define custom actions in `app/actions/` |
| `Conditions` | `lib/lcp_ruby/condition_evaluator.rb`, `lib/lcp_ruby/condition_service_registry.rb` | ConditionEvaluator (field-value + service conditions), ConditionServiceRegistry. Host apps define condition services in `app/condition_services/` |
| `Attachments` | `lib/lcp_ruby/model_factory/attachment_applicator.rb` | Applies Active Storage macros (has_one_attached/has_many_attached), validations (size, content_type, max_files), and variant config to dynamic models |

### Controller Stack

`ApplicationController` (`app/controllers/lcp_ruby/application_controller.rb`):
- Inherits from host app's controller (configurable via `parent_controller`)
- Resolves presenter + model from `:lcp_slug` URL param
- Sets up `current_evaluator` (PermissionEvaluator) for the current user/role
- Provides path helpers: `resource_path`, `resources_path`, `edit_resource_path`

`ResourcesController` (`app/controllers/lcp_ruby/resources_controller.rb`):
- Standard CRUD (index/show/new/create/edit/update/destroy)
- `permitted_params` filters by writable fields + association FK fields
- `apply_search` handles text search + predefined filter scopes
- Authorization via Pundit on every action

### Routing

Engine mounts at a configurable path (default `/`). All resources use a slug-based pattern:
```
/:lcp_slug          → resources#index
/:lcp_slug/new      → resources#new
/:lcp_slug/:id      → resources#show
/:lcp_slug/:id/edit → resources#edit
```

The slug comes from the presenter YAML (e.g., `slug: deals` → `/deals`).

### How Association Selects Work

When a form field has `input_type: association_select` (e.g., `todo_list_id`):
1. `LayoutBuilder.normalize_section` matches the FK field name against `association.foreign_key` metadata
2. Creates a synthetic `FieldDefinition` (type: integer) and attaches the `AssociationDefinition`
3. `_form.html.erb` renders a `<select>` populated from the target model's records via `LcpRuby.registry.model_for(assoc.target_model)`
4. FK fields bypass the `field_writable?` check (they're permitted separately in the controller)

### Permission System

Permissions YAML defines roles with: `crud` list, `fields` (readable/writable), `actions`, `scope`, `presenters`. The `PermissionEvaluator.can?` method maps action aliases (`edit` → `update`, `new` → `create`) before checking the CRUD list. Record-level rules can deny specific CRUD operations based on field conditions with role exceptions.

## Test Structure

- **Unit tests**: `spec/lib/lcp_ruby/` — test individual subsystems against YAML fixtures in `spec/fixtures/metadata/`
- **Integration tests**: `spec/integration/` — test full HTTP request cycle using fixtures in `spec/fixtures/integration/{todo,crm}/`
- **Dummy app**: `spec/dummy/` — minimal Rails app that mounts the engine at `/`
- **Integration helper**: `spec/support/integration_helper.rb` — provides `load_integration_metadata!` and `stub_current_user` for request specs
- Each test resets `LcpRuby.reset!` and clears Dynamic constants before running (see `spec_helper.rb`)

## YAML Metadata Conventions

**Model fields**: base types are `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`, `enum`, `file`, `rich_text`, `json`, `uuid`, `attachment`. Built-in business types: `email`, `phone`, `url`, `color`. Custom types can be defined in `config/lcp_ruby/types/`.

**Scopes**: support `where`, `where_not`, `order`, `limit`. The `where_not` key generates `scope :name, -> { where.not(...) }`.

**Presenter actions**: `type: built_in` actions (show, edit, destroy, create) check `PermissionEvaluator.can?`. `type: custom` actions check `can_execute_action?` and dispatch to registered action classes.

## Dependencies

Core: `rails` (>= 7.1), `pundit` (authorization), `kaminari` (pagination), `ransack` (search). Linting: `rubocop-rails-omakase`.
