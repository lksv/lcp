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

Class name of your application's user model. Used for resolving the user class when needed by the authorization system.

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

Source: `lib/lcp_ruby/configuration.rb`, `lib/lcp_ruby/services/registry.rb`
