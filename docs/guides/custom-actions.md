# Custom Actions

Custom actions let host apps define domain-specific operations beyond standard CRUD. Use them for business logic like "Close Deal as Won," "Send Invoice," or "Archive Project."

## When to Use Custom Actions

Use a custom action when you need to:
- Execute business logic that goes beyond simple field updates
- Provide a user-facing button with confirmation dialogs
- Return custom responses (redirects, CSV downloads, JSON data)
- Enforce action-specific authorization beyond CRUD permissions

For simple field updates, standard CRUD (edit/update) is sufficient.

## Creating an Action

Create a file at `app/actions/<model>/<action>.rb`:

```ruby
module LcpRuby
  module HostActions
    module Deal
      class CloseWon < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No deal specified")
          end

          if record.stage.in?(["closed_won", "closed_lost"])
            return failure(message: "Deal is already closed")
          end

          record.update!(stage: "closed_won")
          success(message: "Deal '#{record.title}' marked as won!")
        end
      end
    end
  end
end
```

The class is resolved by convention: `LcpRuby::HostActions::<Model>::<ActionName>`.

- Module nesting matches the model name (e.g., `Deal` for model `deal`)
- Class name matches the action name in CamelCase (e.g., `CloseWon` for action `close_won`)

## BaseAction API

### Available in `#call`

| Method | Type | Description |
|--------|------|-------------|
| `record` | AR instance | The target record (single actions) |
| `records` | array | Array of records (batch actions) |
| `current_user` | User | The current user |
| `params` | Hash | Request parameters |
| `model_class` | Class | The dynamic AR model class |

### Return Values

Every `#call` must return a result object using one of these methods:

**`success(message:, redirect_to:, data:)`**

```ruby
# Simple success
success(message: "Done!")

# With redirect
success(message: "Created!", redirect_to: "/deals")

# With data (for JSON responses)
success(data: { count: 5 })
```

**`failure(message:, errors:)`**

```ruby
# Simple failure
failure(message: "Cannot close this deal")

# With error details
failure(message: "Validation failed", errors: record.errors.full_messages)
```

### Optional Overrides

**`#visible?(record, user)`** — control whether the action button appears in the UI for a given record and user. Defaults to `true`.

```ruby
def visible?(record, user)
  record.stage != "closed"
end
```

**`#authorized?(record, user)`** — additional authorization check beyond permission YAML. Defaults to `true`.

```ruby
def authorized?(record, user)
  user.department == record.department
end
```

**`#param_schema`** — define expected parameters for the action.

```ruby
def param_schema
  { reason: { type: :string, required: true } }
end
```

## Registering the Action in YAML

Reference the action in a [presenter YAML](../reference/presenters.md#actions-configuration):

```yaml
actions:
  single:
    - name: close_won
      type: custom
      label: "Close as Won"
      icon: check-circle
      confirm: true
      confirm_message: "Mark this deal as won?"
      visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
```

### Confirm Per Role

The `confirm` attribute can be role-specific. Use a hash with `except` or `only` to control which roles see the confirmation dialog:

```yaml
# Admin skips confirmation, everyone else sees it
- name: archive
  type: custom
  label: "Archive"
  confirm:
    except: [admin]
  confirm_message: "Are you sure you want to archive this?"

# Only viewers and sales_reps see confirmation
- name: force_delete
  type: custom
  label: "Force Delete"
  confirm:
    only: [viewer, sales_rep]
```

See [Presenters Reference — Confirm Per Role](../reference/presenters.md#confirm-per-role) for the full syntax.

### Action Categories

| Category | Use For |
|----------|---------|
| `collection` | Actions that don't target a specific record (e.g., "Export All") |
| `single` | Actions on one record (e.g., "Close Deal") |
| `batch` | Actions on multiple selected records (e.g., "Archive Selected") |

## Auto-Discovery

Enable auto-discovery in your initializer so action classes are automatically registered:

```ruby
# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
end
```

This scans `app/actions/` for classes following the naming convention and registers them.

## Permission Control

Custom action execution is controlled by the `actions` attribute in [permissions YAML](../reference/permissions.md#actions):

```yaml
roles:
  sales_rep:
    actions:
      allowed: [close_won]
      denied: []
```

The `PermissionEvaluator.can_execute_action?` method checks this configuration before executing the action.

## Response Handling

The `ActionsController` handles three response formats based on the result:

- **HTML** — redirects with a flash message (default)
- **CSV** — sends a file download when `data` contains CSV content
- **JSON** — returns JSON when requested

Source: `lib/lcp_ruby/actions/base_action.rb`, `lib/lcp_ruby/actions/action_registry.rb`, `lib/lcp_ruby/actions/action_executor.rb`
