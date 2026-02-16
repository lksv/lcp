# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

LCP Ruby is a **Rails mountable engine** that generates full CRUD information systems from YAML metadata. Models, presenters (UI config), and permissions are defined in YAML files. The engine dynamically builds ActiveRecord models, database tables, controllers, and views at runtime.

## Documentation

- [Documentation Index](docs/README.md) — Links to all documentation
- [Getting Started](docs/getting-started.md) — Installation and first model tutorial
- [Models Reference](docs/reference/models.md) — Complete model YAML reference
- [Types Reference](docs/reference/types.md) — Custom business types (email, phone, url, color, and user-defined)
- [Presenters Reference](docs/reference/presenters.md) — Complete presenter YAML reference
- [Permissions Reference](docs/reference/permissions.md) — Complete permission YAML reference
- [Condition Operators](docs/reference/condition-operators.md) — Shared operator reference
- [Engine Configuration](docs/reference/engine-configuration.md) — `LcpRuby.configure` options
- [Model DSL Reference](docs/reference/model-dsl.md) — Ruby DSL alternative to YAML for models
- [Presenter DSL Reference](docs/reference/presenter-dsl.md) — Ruby DSL alternative to YAML for presenters (with inheritance)
- [Custom Types Guide](docs/guides/custom-types.md) — Practical examples of custom business types
- [Extensibility Guide](docs/guides/extensibility.md) — All extension mechanisms: actions, events, transforms, validations, scopes
- [Custom Actions](docs/guides/custom-actions.md) — Writing custom actions
- [Event Handlers](docs/guides/event-handlers.md) — Writing event handlers
- [Developer Tools](docs/guides/developer-tools.md) — Validate and ERD rake tasks
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

# Run example apps (from their directory)
cd examples/todo && bundle exec rails db:prepare && bundle exec rails s -p 3000
cd examples/crm && bundle exec rails db:prepare && bundle exec rails s -p 3001
```

## Architecture

### Data Flow

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

### Key Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `Metadata` | `lib/lcp_ruby/metadata/` | Parses YAML into definition objects (ModelDefinition, PresenterDefinition, etc.) |
| `Types` | `lib/lcp_ruby/types/` | TypeRegistry, TypeDefinition, ServiceRegistry, built-in types (email, phone, url, color), transforms (strip, downcase, normalize_url, normalize_phone) |
| `ModelFactory` | `lib/lcp_ruby/model_factory/` | Builds dynamic AR models: Builder orchestrates SchemaManager, ValidationApplicator, TransformApplicator, AssociationApplicator, ScopeApplicator |
| `Presenter` | `lib/lcp_ruby/presenter/` | UI layer: Resolver (find by slug), LayoutBuilder (form/show sections), ColumnSet (visible columns), ActionSet (visible actions) |
| `Authorization` | `lib/lcp_ruby/authorization/` | PolicyFactory (dynamic Pundit policies), PermissionEvaluator (can?, readable_fields, writable_fields), ScopeBuilder |
| `Events` | `lib/lcp_ruby/events/` | Dispatcher + HandlerRegistry. Host apps define handlers in `app/event_handlers/` |
| `Actions` | `lib/lcp_ruby/actions/` | ActionExecutor + ActionRegistry. Host apps define custom actions in `app/actions/` |

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

Engine mounts at a configurable path (default `/admin`). All resources use a slug-based pattern:
```
/admin/:lcp_slug          → resources#index
/admin/:lcp_slug/new      → resources#new
/admin/:lcp_slug/:id      → resources#show
/admin/:lcp_slug/:id/edit → resources#edit
```

The slug comes from the presenter YAML (e.g., `slug: deals` → `/admin/deals`).

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
- **Dummy app**: `spec/dummy/` — minimal Rails app that mounts the engine at `/admin`
- **Integration helper**: `spec/support/integration_helper.rb` — provides `load_integration_metadata!` and `stub_current_user` for request specs
- Each test resets `LcpRuby.reset!` and clears Dynamic constants before running (see `spec_helper.rb`)

## YAML Metadata Conventions

**Model fields**: base types are `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`, `datetime`, `enum`, `file`, `rich_text`, `json`, `uuid`. Built-in business types: `email`, `phone`, `url`, `color`. Custom types can be defined in `config/lcp_ruby/types/`.

**Scopes**: support `where`, `where_not`, `order`, `limit`. The `where_not` key generates `scope :name, -> { where.not(...) }`.

**Presenter actions**: `type: built_in` actions (show, edit, destroy, create) check `PermissionEvaluator.can?`. `type: custom` actions check `can_execute_action?` and dispatch to registered action classes.

## Dependencies

Core: `rails` (>= 7.1), `pundit` (authorization), `kaminari` (pagination), `ransack` (search). Linting: `rubocop-rails-omakase`.
