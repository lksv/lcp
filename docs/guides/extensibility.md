# Extensibility Guide

LCP Ruby generates full CRUD applications from YAML metadata, but real-world systems need custom business logic. This guide covers all extensibility mechanisms available today and outlines the planned architecture for future versions.

## Overview

LCP Ruby provides six extensibility points, each designed for a specific category of customization:

| Mechanism | Contract | Side Effects? | Base Class | Docs |
|-----------|----------|---------------|------------|------|
| Custom Actions | `(record, user, params) -> Result` | Yes | `Actions::BaseAction` | [Guide](custom-actions.md) |
| Event Handlers | `(record, changes) -> void` | Yes | `Events::HandlerBase` | [Guide](event-handlers.md) |
| Custom Transforms | `(value) -> value` | No (pure) | `Types::Transforms::BaseTransform` | [Reference](../reference/types.md#custom-transforms) |
| Custom Validations | `(record, field) -> errors` | No (pure) | `ActiveModel::Validator` | [Reference](../reference/models.md#validations) |
| Condition Services | `(record) -> boolean` | No (pure) | Class with `self.call` | [Guide](conditional-rendering.md) |
| Scopes | `(relation) -> relation` | No | YAML/DSL config | [Reference](../reference/models.md#scopes) |

## Choosing the Right Mechanism

Use this decision tree to pick the right extensibility point:

- **User clicks a button** (explicit action) -> [Custom Action](#custom-actions)
- **React to data changes** (implicit side effect) -> [Event Handler](#event-handlers)
- **Normalize field values on write** (transform input) -> [Custom Transform](#custom-transforms)
- **Enforce data constraints** (reject invalid data) -> [Custom Validation](#custom-validations)
- **Compute field/section visibility dynamically** (server-side condition) -> [Condition Service](#condition-services)
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
```

See the [Event Handlers guide](event-handlers.md) for async handlers, lifecycle events, and the full `HandlerBase` API.

### Custom Transforms

Transforms normalize field values on assignment. They are pure functions: `value in -> value out`.

```ruby
# lib/transforms/titlecase.rb
class TitlecaseTransform < LcpRuby::Types::Transforms::BaseTransform
  def call(value)
    value.respond_to?(:titlecase) ? value.titlecase : value
  end
end

# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  LcpRuby::Types::ServiceRegistry.register("transform", "titlecase", TitlecaseTransform.new)
end
```

Use in a type definition:

```yaml
type:
  name: proper_name
  base_type: string
  transforms:
    - strip
    - titlecase
```

Transforms chain in order via `ActiveRecord.normalizes` — each transform's output feeds the next. See the [Types Reference](../reference/types.md#custom-transforms) for details.

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

  # Register custom transforms
  LcpRuby::Types::ServiceRegistry.register(
    "transform", "titlecase", TitlecaseTransform.new
  )
end
```

### Directory Convention

```
app/
  actions/
    deal/
      close_won.rb          # LcpRuby::HostActions::Deal::CloseWon
  event_handlers/
    deal/
      on_stage_change.rb    # LcpRuby::HostEventHandlers::Deal::OnStageChange
  condition_services/
    credit_check.rb           # LcpRuby::HostConditionServices::CreditCheck
  validators/
    business_rule_validator.rb  # BusinessRuleValidator
lib/
  transforms/
    titlecase.rb            # TitlecaseTransform
config/
  lcp_ruby/
    types/
      proper_name.yml       # references "titlecase" transform
    models/
      deal.yml              # references custom scope, events, validations
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

### Computed Fields and Dynamic Defaults

Future function types beyond actions and handlers:

- **Computed fields** — derive values from other fields (e.g., `full_name` from `first_name` + `last_name`)
- **Dynamic defaults** — calculate default values at record creation time (e.g., next invoice number from a sequence)
- **Field-level visibility functions** — programmatic `visible_when` logic beyond the declarative operator set

These would follow the same pattern: a Ruby class with a simple contract, registered via the same discovery mechanism.

### ProcessRunner

A `ProcessRunner` would manage external process lifecycle for the cross-language protocol:

- Start/stop external processes on demand
- Health checks and automatic restart
- Timeout and circuit-breaker patterns
- Stdin/stdout JSON-RPC communication

This enables a deployment model where the host Rails app manages extension processes as children, without requiring separate infrastructure.
