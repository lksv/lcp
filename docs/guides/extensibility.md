# Extensibility Guide

LCP Ruby generates full CRUD applications from YAML metadata, but real-world systems need custom business logic. This guide covers all extensibility mechanisms.

## Overview

LCP Ruby provides extensibility through two systems:

1. **Services::Registry** — unified auto-discover registry for transforms, validators, defaults, computed fields, conditions, and data providers. Services live in `app/lcp_services/{category}/` and are discovered automatically.
2. **Dedicated registries** — custom actions (`app/actions/`), event handlers (`app/event_handlers/`), condition services (`app/condition_services/`), and custom renderers (`app/renderers/`) use their own registries with auto-discovery.

### Service Categories

| Category | Contract | Side Effects? | Directory | Used In |
|----------|----------|---------------|-----------|---------|
| `transforms` | `def call(value) -> value` | No | `app/lcp_services/transforms/` | Field `transforms:`, type `transforms:` |
| `validators` | `def self.call(record, **opts) -> void` | No | `app/lcp_services/validators/` | Validation `type: service` |
| `defaults` | `def self.call(record, field_name) -> value` | No | `app/lcp_services/defaults/` | Field `default: { service: }` |
| `computed` | `def self.call(record) -> value` | No | `app/lcp_services/computed/` | Field `computed: { service: }` |
| `conditions` | `def self.call(record) -> boolean` | No | `app/lcp_services/conditions/` | `visible_when: { service: }`, `when: { service: }` |
| `data_providers` | `def self.call(user:) -> data or nil` | No | `app/lcp_services/data_providers/` | Menu badge `provider:` |

### Other Extension Points

| Mechanism | Contract | Side Effects? | Base Class | Docs |
|-----------|----------|---------------|------------|------|
| Custom Actions | `(record, user, params) -> Result` | Yes | `Actions::BaseAction` | [Guide](custom-actions.md) |
| Event Handlers | `(record, changes) -> void` | Yes | `Events::HandlerBase` | [Guide](event-handlers.md) |
| Custom Renderers | `(value, options) -> HTML` | No | `Display::BaseRenderer` | [Guide](custom-renderers.md) |
| Custom Validations | `(record, field) -> errors` | No | `ActiveModel::Validator` | [Reference](../reference/models.md#validations) |
| Scopes | `(relation) -> relation` | No | YAML/DSL config | [Reference](../reference/models.md#scopes) |

## Choosing the Right Mechanism

Use this decision tree to pick the right extensibility point:

- **User clicks a button** (explicit action) -> [Custom Action](#custom-actions)
- **React to data changes** (implicit side effect) -> [Event Handler](#event-handlers)
- **Normalize field values on write** (transform input) -> [Custom Transform](#custom-transforms)
- **Enforce data constraints on a single field** (reject invalid data) -> [Custom Validation](#custom-validations) or declarative [comparison](../reference/models.md#comparison)
- **Enforce cross-record business rules** (e.g., aggregate limits) -> [Service Validator](#service-validators)
- **Calculate a field from other fields** -> [Computed Field](#computed-fields)
- **Set field default at record creation** -> [Dynamic Default](#dynamic-defaults)
- **Compute field/section visibility dynamically** (server-side condition) -> [Condition Service](#condition-services)
- **Run validation only in certain states** -> [Conditional Validation](../reference/models.md#conditional-validations-when) (declarative `when:`)
- **Reusable query filters** (named queries) -> [Scope](#scopes)

## Quick Examples

### Custom Actions

Actions execute business logic when a user clicks a button in the UI. They receive a record, user, and params, and return a success/failure result.

```ruby
# app/actions/invoice/send_email.rb
module LcpRuby
  module HostActions
    module Invoice
      class SendEmail < LcpRuby::Actions::BaseAction
        def call
          return failure(message: "No invoice specified") unless record

          InvoiceMailer.send_invoice(record, current_user).deliver_later
          success(message: "Invoice ##{record.number} sent!")
        end
      end
    end
  end
end
```

Register in presenter YAML:

```yaml
actions:
  single:
    - name: send_email
      type: custom
      label: "Send Invoice"
      icon: mail
      confirm: true
```

See the [Custom Actions guide](custom-actions.md) for the full API including `visible?`, `authorized?`, and `param_schema`.

### Event Handlers

Handlers respond to lifecycle events and field changes. They run automatically when data changes — no user interaction required.

```ruby
# app/event_handlers/deal/on_stage_change.rb
module LcpRuby
  module HostEventHandlers
    module Deal
      class OnStageChange < LcpRuby::Events::HandlerBase
        def self.handles_event
          "on_stage_change"
        end

        def call
          if new_value("stage") == "closed_won"
            Rails.logger.info("[CRM] Deal '#{record.title}' won!")
          end
        end
      end
    end
  end
end
```

Declare the event in model YAML:

```yaml
events:
  - name: on_stage_change
    type: field_change
    field: stage
    condition:
      field: stage
      operator: not_in
      value: [lead]
```

See the [Event Handlers guide](event-handlers.md) for async handlers, lifecycle events, and the full `HandlerBase` API.

### Custom Transforms

Transforms normalize field values on assignment. They are pure functions: `value in -> value out`.

Transforms can be used at the **field level** (directly on a field) or at the **type level** (bundled with a custom type). For simple cases, field-level transforms avoid the need for a custom type entirely.

**Field-level transform** (no custom type needed):

```yaml
# YAML
- name: title
  type: string
  transforms: [strip]
```

```ruby
# DSL
field :first_name, :string, transforms: [:strip, :titlecase]
```

**Custom transform service** — register in `app/lcp_services/transforms/`:

```ruby
# app/lcp_services/transforms/titlecase.rb
module LcpRuby
  module HostServices
    module Transforms
      class Titlecase
        def call(value)
          value.respond_to?(:titlecase) ? value.titlecase : value
        end
      end
    end
  end
end
```

The service is auto-discovered and can be referenced by key (`titlecase`) in both field-level `transforms:` and type-level `transforms:`.

Transforms chain in order via `ActiveRecord.normalizes` — each transform's output feeds the next. Field-level transforms extend type-level transforms (deduplicated). See the [Types Reference](../reference/types.md#custom-transforms) for details.

### Custom Validations

Custom validators enforce business rules that go beyond the built-in validation types. They follow the standard ActiveModel validator pattern.

```ruby
# app/validators/business_rule_validator.rb
class BusinessRuleValidator < ActiveModel::Validator
  def validate(record)
    if record.respond_to?(:start_date) && record.respond_to?(:end_date)
      if record.start_date.present? && record.end_date.present? && record.end_date < record.start_date
        record.errors.add(:end_date, "must be after start date")
      end
    end
  end
end
```

Reference in model YAML:

```yaml
# Field-level
fields:
  - name: email
    type: string
    validations:
      - type: custom
        validator_class: "EmailFormatValidator"

# Model-level (cross-field validation)
validations:
  - type: custom
    validator_class: "BusinessRuleValidator"
```

The engine calls `validator_class.constantize` at build time, so the class must be loaded before models are built.

> **Tip:** For cross-field date/number comparisons, consider using the declarative [`comparison`](../reference/models.md#comparison) validation type instead of writing a custom validator class. For cross-record business rules, use a [service validator](#service-validators).

### Service Validators

Service validators enforce business rules that span multiple records or require database queries. They are auto-discovered from `app/lcp_services/validators/`.

```ruby
# app/lcp_services/validators/deal_credit_limit.rb
module LcpRuby
  module HostServices
    module Validators
      class DealCreditLimit
        def self.call(record, **opts)
          return unless record.respond_to?(:company_id) && record.company_id

          company_deals = record.class.where(company_id: record.company_id)
          company_deals = company_deals.where.not(id: record.id) if record.persisted?
          total = company_deals.sum(:value).to_f + record.value.to_f

          if total > 1_000_000
            record.errors.add(:value, "total company deals exceed credit limit (1M)")
          end
        end
      end
    end
  end
end
```

Reference in model YAML/DSL:

```yaml
# Model-level service validation
validations:
  - type: service
    service: deal_credit_limit
```

```ruby
# DSL
validates_model :service, service: "deal_credit_limit"
```

### Computed Fields

Computed fields derive their values from other fields and are automatically calculated before save. They are rendered as readonly in forms.

**Template computed field** — string interpolation using `{field_name}` syntax:

```ruby
# DSL
field :full_name, :string, computed: "{first_name} {last_name}"
```

```yaml
# YAML
- name: full_name
  type: string
  computed: "{first_name} {last_name}"
```

**Service computed field** — delegates to a registered service in `app/lcp_services/computed/`:

```ruby
# app/lcp_services/computed/weighted_deal_value.rb
module LcpRuby
  module HostServices
    module Computed
      class WeightedDealValue
        def self.call(record)
          value = record.value.to_f
          progress = record.progress.to_f
          (value * progress / 100.0).round(2)
        end
      end
    end
  end
end
```

```ruby
# DSL
field :weighted_value, :decimal, computed: { service: "weighted_deal_value" }
```

See [Computed Fields](../reference/models.md#computed) in the Models Reference.

### Dynamic Defaults

Dynamic defaults set field values at record creation time using runtime logic. They run via `after_initialize` on new records only.

**Built-in defaults:**

```yaml
- name: start_date
  type: date
  default: current_date
```

Built-in keys: `current_date`, `current_datetime`, `current_user_id`.

**Service defaults** — custom logic in `app/lcp_services/defaults/`:

```ruby
# app/lcp_services/defaults/thirty_days_out.rb
module LcpRuby
  module HostServices
    module Defaults
      class ThirtyDaysOut
        def self.call(record, field_name)
          Date.current + 30
        end
      end
    end
  end
end
```

```yaml
- name: expected_close_date
  type: date
  default:
    service: thirty_days_out
```

See [Dynamic Defaults](../reference/models.md#default) in the Models Reference.

### Condition Services

Condition services compute dynamic visibility for fields or sections. They are pure functions: `record in -> boolean out`. Use them when declarative `visible_when` operators are not expressive enough.

```ruby
# app/condition_services/credit_check.rb
module LcpRuby
  module HostConditionServices
    class CreditCheck
      def self.call(record)
        record.credit_score.present? && record.credit_score > 500
      end
    end
  end
end
```

Used in presenter YAML:

```yaml
fields:
  - field: premium_options
    visible_when: { service: credit_check }
```

When the presenter evaluates `visible_when` and encounters a `service` key, it looks up the named condition service in the `ConditionServiceRegistry` and calls it with the current record. The field is visible only if the service returns `true`.

Condition services can also be used in validation `when:` conditions:

```yaml
validations:
  - type: presence
    when:
      service: requires_approval
```

### Scopes

Declarative scopes are defined in YAML using `where`, `where_not`, `order`, and `limit`:

```yaml
scopes:
  - name: active
    where: { status: active }
  - name: recent
    order: { created_at: desc }
    limit: 10
```

For complex queries, mark the scope as `type: custom` and define it in Ruby via a model extension (see [Model Extensions](#model-extensions) below):

```yaml
scopes:
  - name: overdue
    type: custom
```

## Model Extensions

Dynamic models live under `LcpRuby::Dynamic::<ModelName>`. You can extend them with custom methods after the engine builds them. This is necessary for:

- Custom scopes (`type: "custom"` in YAML)
- Conditional validation methods (`if: "active?"`, `unless: "draft?"`)
- Custom instance methods referenced elsewhere

### Defining Extensions

Add methods to the dynamic model class in an initializer, after LCP Ruby has built the models:

```ruby
# config/initializers/lcp_ruby_extensions.rb
Rails.application.config.after_initialize do
  # Custom scope — must match a scope with type: "custom" in model YAML
  LcpRuby::Dynamic::Task.scope :overdue, -> {
    where("due_date < ?", Date.current).where(completed: false)
  }

  # Predicate methods for conditional validations
  LcpRuby::Dynamic::Task.class_eval do
    def active?
      status == "active"
    end

    def draft?
      status == "draft"
    end
  end
end
```

### How It Connects

The `ScopeApplicator` skips code generation for scopes marked `type: "custom"`:

```ruby
# lib/lcp_ruby/model_factory/scope_applicator.rb
if scope_config["type"] == "custom"
  # Custom scopes are defined by Ruby code in model extensions
  return
end
```

The scope entry in YAML serves as documentation and allows it to be referenced from predefined filters in presenters. The actual query logic comes from the Ruby extension.

Conditional validation options (`if`, `unless`) reference method names on the model instance:

```yaml
validations:
  - type: presence
    options: { if: "active?" }
```

The `active?` method must exist on the model — either from a model extension or a custom validator.

## Auto-Discovery Setup

A typical host app registers all extensibility points in a single initializer:

```ruby
# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")

  # Discover custom actions from app/actions/
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)

  # Discover event handlers from app/event_handlers/
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)

  # Discover condition services from app/condition_services/
  LcpRuby::ConditionServiceRegistry.discover!(app_path.to_s)

  # Discover custom renderers from app/renderers/
  LcpRuby::Display::RendererRegistry.discover!(app_path.to_s)

  # Discover services (transforms, validators, defaults, computed, conditions)
  # from app/lcp_services/
  LcpRuby::Services::Registry.discover!(app_path.to_s)
end
```

### Directory Convention

```
app/
  actions/
    deal/
      close_won.rb              # LcpRuby::HostActions::Deal::CloseWon
  event_handlers/
    deal/
      on_stage_change.rb        # LcpRuby::HostEventHandlers::Deal::OnStageChange
  renderers/
    conditional_badge.rb        # LcpRuby::HostRenderers::ConditionalBadge
    charts/
      sparkline.rb              # LcpRuby::HostRenderers::Charts::Sparkline
  condition_services/
    credit_check.rb             # LcpRuby::HostConditionServices::CreditCheck
  lcp_services/
    transforms/
      titlecase.rb              # LcpRuby::HostServices::Transforms::Titlecase
    validators/
      deal_credit_limit.rb      # LcpRuby::HostServices::Validators::DealCreditLimit
    defaults/
      thirty_days_out.rb        # LcpRuby::HostServices::Defaults::ThirtyDaysOut
    computed/
      weighted_deal_value.rb    # LcpRuby::HostServices::Computed::WeightedDealValue
  validators/
    business_rule_validator.rb  # BusinessRuleValidator
config/
  lcp_ruby/
    types/
      proper_name.yml           # references "titlecase" transform
    models/
      deal.yml                  # references scopes, events, validations, computed, defaults
```

## Future Architecture

This section outlines planned evolution of the extensibility system. None of this is implemented yet — it represents the target architecture.

### Typed Parameter Contracts

Actions currently receive raw `params`. The planned `param` DSL will provide typed, validated parameters with automatic form generation:

```ruby
class CloseWon < LcpRuby::Actions::BaseAction
  param :reason, :string, required: true
  param :close_date, :date, default: -> { Date.current }

  def call
    record.update!(stage: "closed_won", close_reason: params[:reason])
    success(message: "Deal closed")
  end
end
```

The `param` declarations would:
- Validate and coerce parameter types before `call` executes
- Generate a `to_contract` representation for cross-language clients
- Auto-generate form UIs for actions that require user input

### Snapshot with Eager-Loaded Associations

Actions and handlers currently receive a live ActiveRecord instance. A future `includes` declaration would eager-load associations into a snapshot, reducing N+1 queries and making the data available for serialization:

```ruby
class GenerateReport < LcpRuby::Actions::BaseAction
  includes :line_items, :customer

  def call
    # record.line_items and record.customer are pre-loaded
  end
end
```

### Cross-Language Protocol

The current extensibility system is Ruby-only. A future protocol layer would allow actions and handlers to be implemented in any language via JSON-RPC:

```
┌─────────────┐    JSON-RPC     ┌──────────────────┐
│  LCP Ruby   │ ──────────────> │  External Process │
│  (host)     │ <────────────── │  (Python, Node)   │
└─────────────┘                 └──────────────────┘
```

Three approaches are under consideration:

| Approach | What Crosses the Wire | Extension Complexity | Engine Complexity |
|----------|----------------------|---------------------|-------------------|
| **Thin protocol** | Minimal context, extensions call back for data | Low engine work | Extensions must handle API calls |
| **Rich snapshot** | Pre-built data snapshot with eager-loaded associations | Medium engine work | Extensions are simpler |
| **Full SDK** | Client SDK with ORM-like API over the wire | High engine work | Extensions feel native |

The likely path is starting with the rich snapshot approach — serialize the record plus declared `includes` into a JSON payload, send to the external process, receive a result or mutation list back.

### ProcessRunner

A `ProcessRunner` would manage external process lifecycle for the cross-language protocol:

- Start/stop external processes on demand
- Health checks and automatic restart
- Timeout and circuit-breaker patterns
- Stdin/stdout JSON-RPC communication

This enables a deployment model where the host Rails app manages extension processes as children, without requiring separate infrastructure.
