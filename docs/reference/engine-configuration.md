# Engine Configuration Reference

Configure LCP Ruby in `config/initializers/lcp_ruby.rb`:

```ruby
LcpRuby.configure do |config|
  config.metadata_path = Rails.root.join("config", "lcp_ruby")
  config.role_method = :lcp_role
  config.user_class = "User"
  config.mount_path = "/"
  config.auto_migrate = true
  config.label_method_default = :to_s
  config.parent_controller = "::ApplicationController"
end
```

## Options

### `authentication`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:external` |
| **Allowed values** | `:none`, `:built_in`, `:external` |

Controls how user authentication is handled.

| Value | Behavior |
|-------|----------|
| `:external` | The host application handles authentication (default). LCP Ruby expects `current_user` to be set by the host. |
| `:built_in` | LCP Ruby provides Devise-based authentication with login, registration, and session management. |
| `:none` | No authentication. All users are anonymous. Useful for public-facing or development setups. |

```ruby
LcpRuby.configure do |config|
  config.authentication = :built_in
end
```

When `authentication` is `:built_in`, additional authentication options are available:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `auth_allow_registration` | `Boolean` | `false` | Allow new user self-registration |
| `auth_password_min_length` | `Integer` | `8` | Minimum password length |
| `auth_session_timeout` | `Duration` | `nil` | Session timeout (e.g., `30.minutes`). `nil` means no timeout. |
| `auth_lock_after_attempts` | `Integer` | `0` | Lock account after N failed login attempts. `0` disables locking. |
| `auth_lock_duration` | `Duration` | `30.minutes` | How long accounts remain locked |
| `auth_mailer_sender` | `String` | `"noreply@example.com"` | From address for authentication emails |
| `auth_after_login_path` | `String` | `"/"` | Redirect path after successful login |
| `auth_after_logout_path` | `String` | `nil` | Redirect path after logout. `nil` uses the default. |

```ruby
LcpRuby.configure do |config|
  config.authentication = :built_in
  config.auth_allow_registration = true
  config.auth_session_timeout = 30.minutes
  config.auth_lock_after_attempts = 5
  config.auth_after_login_path = "/dashboard"
end
```

### `metadata_path`

| | |
|---|---|
| **Type** | `Pathname` or `String` |
| **Default** | `Rails.root.join("config", "lcp_ruby")` |

Directory containing `models/`, `presenters/`, and `permissions/` YAML subdirectories. Change this when you want metadata in a non-standard location (e.g., a shared gem or a monorepo subdirectory).

### `role_method`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:lcp_role` |

Method called on the current user object to determine their roles. Must return an **array of role name strings** (e.g., `["admin", "sales_rep"]`). The values are matched against role names in [permissions YAML](permissions.md). Your User model must implement this method.

```ruby
class User < ApplicationRecord
  def lcp_role
    roles.pluck(:name)  # => ["admin", "sales_rep"]
  end
end
```

See [Multiple Roles](permissions.md#multiple-roles) for merge semantics when a user has more than one role.

### `user_class`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"User"` |

Class name of your application's user model. Used by:
- **Authorization** — resolving the user class for permission evaluation
- **Userstamps** — `belongs_to` associations on `created_by` / `updated_by` FK columns point to this class

The user model must respond to `id` and `name` (the latter is used for `store_name` snapshots).

### `mount_path`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"/"` |

The path prefix where the engine is mounted. Must match the path in your `config/routes.rb` mount statement. Used by internal path helpers.

### `auto_migrate`

| | |
|---|---|
| **Type** | `Boolean` |
| **Default** | `true` |

When `true`, the engine automatically creates and updates database tables on boot to match model definitions. Set to `false` in production if you manage migrations manually or want to prevent schema changes at startup.

### `label_method_default`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:to_s` |

Default method called on records to generate display labels (e.g., in association selects). Overridden per-model via the `options.label_method` attribute in [model YAML](models.md#options).

### `parent_controller`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"::ApplicationController"` |

The host application controller that LCP Ruby's controllers inherit from. Change this to inherit authentication, locale settings, or other before-filters from a different base controller.

### `strict_loading`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:never` |

Controls whether ActiveRecord `strict_loading` is applied to records in index, show, and edit views. When enabled, accessing a lazy-loaded association raises `ActiveRecord::StrictLoadingViolationError`, helping catch N+1 queries during development.

| Value | Behavior |
|-------|----------|
| `:never` | Disabled (default) |
| `:development` | Enabled in `development` and `test` environments |
| `:always` | Enabled in all environments |

```ruby
LcpRuby.configure do |config|
  config.strict_loading = :development
end
```

See [Eager Loading](eager-loading.md) for details on the auto-detection system.

### `role_source`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:implicit` |
| **Allowed values** | `:implicit`, `:model` |

Controls where role definitions come from. When set to `:model`, roles are validated against a DB-backed model at authorization time. Unknown role names are filtered out and logged as warnings.

```ruby
LcpRuby.configure do |config|
  config.role_source = :model
end
```

See [Role Source Reference](role-source.md) for the model contract, registry API, and setup details.

### `role_model`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"role"` |

Name of the LCP Ruby model that stores role definitions. Only used when `role_source` is `:model`. The model must satisfy the [role model contract](role-source.md#model-contract).

### `role_model_fields`

| | |
|---|---|
| **Type** | `Hash` |
| **Default** | `{ name: "name", active: "active" }` |

Maps the role model contract's logical fields to actual field names on your model. Only used when `role_source` is `:model`.

```ruby
LcpRuby.configure do |config|
  config.role_model_fields = { name: "role_key", active: "enabled" }
end
```

### `impersonation_roles`

| | |
|---|---|
| **Type** | `Array` |
| **Default** | `[]` |

List of role names allowed to impersonate other roles. When empty (default), impersonation is disabled. Only users whose real role is in this list can activate impersonation.

```ruby
LcpRuby.configure do |config|
  config.impersonation_roles = ["admin"]
end
```

See the [Impersonation Guide](../guides/impersonation.md) for setup and usage details.

### `menu_mode`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:auto` |

Controls how the navigation menu is built.

| Value | Behavior |
|-------|----------|
| `:auto` | Auto-generate from view groups if no `menu.yml`; use `menu.yml` + auto-append unreferenced view groups if it exists |
| `:strict` | `menu.yml` is required and is the sole source of truth; no auto-append |

```ruby
LcpRuby.configure do |config|
  config.menu_mode = :strict
end
```

See [Menu Reference](menu.md) for the full `menu.yml` YAML schema and [Menu Guide](../guides/menu.md) for setup examples.

### `attachment_max_size`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"50MB"` |

Global default maximum file size for attachment fields. Individual fields can override this with their own `max_size` option. Supports `KB`, `MB`, and `GB` suffixes.

```ruby
LcpRuby.configure do |config|
  config.attachment_max_size = "50MB"
end
```

### `breadcrumb_home_path`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"/"` |

Path for the "Home" breadcrumb link. Useful when the engine is mounted at a sub-path and you want the Home crumb to point to the host application's root or a custom dashboard.

```ruby
LcpRuby.configure do |config|
  config.breadcrumb_home_path = "/dashboard"
end
```

### `not_found_handler`

| | |
|---|---|
| **Type** | `Symbol` |
| **Default** | `:default` |
| **Allowed values** | `:default`, `:raise` |

Controls how the engine handles unknown slugs (`MetadataError`) and missing records (`ActiveRecord::RecordNotFound`).

| Value | Behavior |
|-------|----------|
| `:default` | Renders a styled 404 error page with a "Back to home" link (default) |
| `:raise` | Re-raises the exception so the host application's error handling takes over |

When set to `:default`, the engine renders `lcp_ruby/errors/not_found` with appropriate i18n messages. JSON requests receive a JSON error response with a 404 status.

```ruby
LcpRuby.configure do |config|
  config.not_found_handler = :raise  # Let the host app handle 404s
end
```

### `empty_value`

| | |
|---|---|
| **Type** | `String` or `nil` |
| **Default** | `nil` (uses i18n key `lcp_ruby.empty_value`, which defaults to `"—"`) |

Text to display when a field value is nil, empty string, whitespace-only, or empty array on index and show pages. The placeholder is rendered as a `<span class="lcp-empty-value">` element.

**Important:** `false` and `0` are **not** considered empty and are rendered as-is.

The resolution order is:
1. Per-presenter `empty_value` in the presenter YAML
2. Global `config.empty_value`
3. `I18n.t("lcp_ruby.empty_value", default: "—")`

```ruby
LcpRuby.configure do |config|
  config.empty_value = "N/A"
end
```

Per-presenter override in YAML:

```yaml
presenter:
  name: deals
  model: deal
  slug: deals
  empty_value: "-"
```

### `audit_writer`

| | |
|---|---|
| **Type** | Object responding to `#log` or `nil` |
| **Default** | `nil` |

Custom audit writer for models with `auditing: true`. When set, the auditing system delegates change persistence to this object instead of writing to the built-in audit log model.

The object must respond to `#log(action:, record:, changes:, user:, metadata:)`:

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | Symbol | `:create`, `:update`, `:destroy`, `:discard`, `:undiscard` |
| `record` | ActiveRecord::Base | The changed record instance |
| `changes` | Hash | Field-level diffs: `{ "field" => [old, new] }` |
| `user` | Object or nil | Current user from `LcpRuby::Current.user` |
| `metadata` | Hash or nil | `{ "request_id" => "..." }` when available |

```ruby
LcpRuby.configure do |config|
  config.audit_writer = MyCustomAuditWriter.new
end
```

See [Auditing Guide](../guides/auditing.md) for setup and usage examples.

### `audit_model`

| | |
|---|---|
| **Type** | `String` |
| **Default** | `"audit_log"` |

Name of the LCP Ruby model that stores audit entries. Only used with the built-in audit writer (when `audit_writer` is `nil`). The model must satisfy the [audit model contract](auditing.md#audit-log-model-contract).

### `audit_model_fields`

| | |
|---|---|
| **Type** | `Hash` |
| **Default** | `{ auditable_type: "auditable_type", auditable_id: "auditable_id", action: "action", changes_data: "changes_data", user_id: "user_id", user_snapshot: "user_snapshot", metadata: "metadata" }` |

Maps the audit model contract's logical fields to actual field names on your audit log model. Use this when your audit model has different column names than the defaults.

```ruby
LcpRuby.configure do |config|
  config.audit_model_fields = {
    auditable_type: "entity_type",
    auditable_id: "entity_id",
    action: "operation",
    changes_data: "diff",
    user_id: "actor_id",
    user_snapshot: "actor_snapshot",
    metadata: "meta"
  }
end
```

### `attachment_allowed_content_types`

| | |
|---|---|
| **Type** | `Array` or `nil` |
| **Default** | `nil` (allow all) |

Global default list of allowed MIME types for attachment fields. When `nil`, all content types are accepted. Individual fields can override this with their own `content_types` option. Supports wildcards like `"image/*"`.

```ruby
LcpRuby.configure do |config|
  config.attachment_allowed_content_types = %w[
    image/jpeg image/png image/webp image/gif
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ]
end
```

## Service Auto-Discovery

The engine automatically discovers and registers custom services from `app/lcp_services/` in your host application. Services are organized by category:

```
app/
  lcp_services/
    transforms/          # Value normalization (strip, titlecase, etc.)
      titlecase.rb       # LcpRuby::HostServices::Transforms::Titlecase
    validators/          # Service validators (cross-record business rules)
      deal_credit_limit.rb  # LcpRuby::HostServices::Validators::DealCreditLimit
    defaults/            # Dynamic default value providers
      thirty_days_out.rb    # LcpRuby::HostServices::Defaults::ThirtyDaysOut
    computed/            # Computed field calculators
      weighted_deal_value.rb  # LcpRuby::HostServices::Computed::WeightedDealValue
    conditions/          # Custom condition evaluators
      credit_check.rb       # LcpRuby::HostServices::Conditions::CreditCheck
```

### Namespace Convention

Service classes must be namespaced under `LcpRuby::HostServices::{Category}::{ClassName}`. The file path relative to the category directory determines the class name. For example, `app/lcp_services/transforms/titlecase.rb` maps to `LcpRuby::HostServices::Transforms::Titlecase`.

### Service Contracts

| Category | Contract | Used In |
|----------|----------|---------|
| `transforms` | `def call(value) -> value` | Field `transforms:`, type `transforms:` |
| `validators` | `def self.call(record, **opts) -> void` | Validation `type: service` |
| `defaults` | `def self.call(record, field_name) -> value` | Field `default: { service: }` |
| `computed` | `def self.call(record) -> value` | Field `computed: { service: }` |
| `conditions` | `def self.call(record) -> boolean` | `visible_when: { service: }`, `when: { service: }` |

### Discovery in Initializer

For the engine to discover services, add `Services::Registry.discover!` to your initializer:

```ruby
# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  LcpRuby::Services::Registry.discover!(Rails.root.join("app").to_s)
end
```

See the [Extensibility Guide](../guides/extensibility.md) for detailed examples of each service category.

## Dedicated Registries

In addition to `Services::Registry`, LCP Ruby has four dedicated registries with their own auto-discovery. These use separate directory paths and namespaces:

```
app/
  actions/                # Custom actions
    deal/
      close_won.rb        # LcpRuby::HostActions::Deal::CloseWon
  event_handlers/         # Event handlers
    deal/
      on_stage_change.rb  # LcpRuby::HostEventHandlers::Deal::OnStageChange
  condition_services/     # Condition services for visible_when/disable_when
    credit_check.rb       # LcpRuby::HostConditionServices::CreditCheck
  renderers/              # Custom display renderers
    conditional_badge.rb  # LcpRuby::HostRenderers::ConditionalBadge
```

These directories use `LcpRuby::Host*` namespaces which conflict with Zeitwerk autoloading. You must exclude them — see [Extensibility Guide — Auto-Discovery Setup](../guides/extensibility.md#auto-discovery-setup) for the required `config/application.rb` initializer.

Each registry requires its own `discover!` call in the initializer:

```ruby
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app").to_s

  LcpRuby::Actions::ActionRegistry.discover!(app_path)
  LcpRuby::Events::HandlerRegistry.discover!(app_path)
  LcpRuby::ConditionServiceRegistry.discover!(app_path)
  LcpRuby::Display::RendererRegistry.discover!(app_path)
  LcpRuby::Services::Registry.discover!(app_path)
end
```

> **Note:** The `conditions` category under `Services::Registry` (`app/lcp_services/conditions/`) and the dedicated `ConditionServiceRegistry` (`app/condition_services/`) are separate registries. Both can serve condition services for `visible_when: { service: }`. See the [Extensibility Guide](../guides/extensibility.md) for details on choosing between them.

Source: `lib/lcp_ruby/configuration.rb`, `lib/lcp_ruby/services/registry.rb`
