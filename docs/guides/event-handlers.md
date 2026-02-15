# Event Handlers

Event handlers respond to model lifecycle events (create, update, destroy) and field value changes. Use them for logging, notifications, side effects, and workflow automation.

## When to Use Event Handlers

Use event handlers when you need to:
- Log important state transitions (e.g., deal stage changes)
- Send notifications when records change
- Trigger external integrations (e.g., sync to CRM, send webhooks)
- Enforce business rules as side effects (e.g., auto-assign records)

For operations that the user explicitly triggers, use [custom actions](custom-actions.md) instead.

## Defining Events in Model YAML

First, declare the events in your [model YAML](../reference/models.md#events):

```yaml
events:
  - name: after_create
    type: lifecycle
  - name: on_stage_change
    type: field_change
    field: stage
```

### Event Types

| Type | Trigger | Requires `field` |
|------|---------|-----------------|
| `lifecycle` | ActiveRecord callbacks (`after_create`, `after_update`, `before_destroy`, `after_destroy`) | no |
| `field_change` | A specific field's value changes during an update | yes |

## Creating a Handler

Create a file at `app/event_handlers/<model>/<handler>.rb`:

```ruby
module LcpRuby
  module HostEventHandlers
    module Deal
      class OnStageChange < LcpRuby::Events::HandlerBase
        def self.handles_event
          "on_stage_change"
        end

        def call
          old_stage = old_value("stage")
          new_stage = new_value("stage")
          Rails.logger.info("[CRM] Deal '#{record.title}' stage: #{old_stage} -> #{new_stage}")
        end
      end
    end
  end
end
```

The class follows the same nesting convention as actions: `LcpRuby::HostEventHandlers::<Model>::<HandlerName>`.

### Required Class Method

**`self.handles_event`** — returns the event name string this handler responds to. Must match the `name` in the model YAML event definition.

## HandlerBase API

### Available in `#call`

| Method | Type | Description |
|--------|------|-------------|
| `record` | AR instance | The affected record |
| `changes` | Hash | Hash of changed attributes (`{ "field" => [old, new] }`) |
| `current_user` | User | The current user |
| `event_name` | String | Name of the triggered event |

### Convenience Methods

| Method | Description |
|--------|-------------|
| `old_value(field)` | Previous value of a field (before the change) |
| `new_value(field)` | New value of a field (after the change) |
| `field_changed?(field)` | Whether a specific field changed |

## Async Handlers

For long-running operations (API calls, email sending), override `async?` to run the handler via ActiveJob:

```ruby
class SendNotification < LcpRuby::Events::HandlerBase
  def self.handles_event
    "after_create"
  end

  def async?
    true
  end

  def call
    NotificationMailer.new_deal(record).deliver_later
  end
end
```

Async handlers are executed by `AsyncHandlerJob`. Make sure your ActiveJob backend (Sidekiq, etc.) is configured.

## Auto-Discovery

Enable auto-discovery in your initializer:

```ruby
# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
```

This scans `app/event_handlers/` for classes following the naming convention and registers them.

## Complete Initializer Pattern

A host app typically registers both actions and event handlers together:

```ruby
# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
```

Source: `lib/lcp_ruby/events/handler_base.rb`, `lib/lcp_ruby/events/handler_registry.rb`, `lib/lcp_ruby/events/dispatcher.rb`, `lib/lcp_ruby/events/async_handler_job.rb`
