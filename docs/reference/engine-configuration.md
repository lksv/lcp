# Engine Configuration Reference

Configure LCP Ruby in `config/initializers/lcp_ruby.rb`:

```ruby
LcpRuby.configure do |config|
  config.metadata_path = Rails.root.join("config", "lcp_ruby")
  config.role_method = :lcp_role
  config.user_class = "User"
  config.mount_path = "/admin"
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

Method called on the current user object to determine their role. The return value is matched against role names in [permissions YAML](permissions.md). Your User model must implement this method.

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
| **Default** | `"/admin"` |

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
