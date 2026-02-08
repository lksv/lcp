# LCP Ruby Documentation

## Getting Started

### Installation

Add to your Gemfile:

```ruby
gem "lcp_ruby", path: "path/to/lcp-ruby"
```

Mount the engine in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount LcpRuby::Engine => "/admin"
end
```

### Configuration

Create an initializer at `config/initializers/lcp_ruby.rb`:

```ruby
LcpRuby.configure do |config|
  config.metadata_path = Rails.root.join("config", "lcp_ruby")  # default
  config.role_method = :lcp_role                                  # default
  config.user_class = "User"                                      # default
  config.mount_path = "/admin"                                    # default
  config.auto_migrate = true                                      # default
  config.label_method_default = :to_s                             # default
  config.parent_controller = "::ApplicationController"            # default
end
```

### Directory Structure

Create the metadata directories:

```
config/lcp_ruby/
  ├── models/         # Model definitions (fields, associations, scopes, events)
  ├── presenters/     # UI definitions (index, show, form, actions, navigation)
  └── permissions/    # Role-based access control
```

Metadata auto-loads on Rails boot via the `lcp_ruby.load_metadata` initializer.

---

## Defining Models

File: `config/lcp_ruby/models/<name>.yml`

### Structure

```yaml
model:
  name: <model_name>          # snake_case, used as table name and AR class
  label: "Display Name"
  label_plural: "Display Names"

  fields:
    - name: <field_name>
      type: <field_type>
      label: "Field Label"
      default: <value>          # optional
      column_options: {}        # optional, passed to AR migration
      enum_values: []           # required for type: enum
      validations: []           # optional

  associations: []              # optional
  scopes: []                    # optional
  events: []                    # optional

  options:
    timestamps: true            # adds created_at, updated_at
    label_method: <field_name>  # method used for display labels
```

### Field Types

| Type | Description |
|------|-------------|
| `string` | Short text (varchar) |
| `text` | Long text |
| `integer` | Whole number |
| `float` | Floating point number |
| `decimal` | Precise decimal (use `column_options: { precision:, scale: }`) |
| `boolean` | True/false |
| `date` | Date only |
| `datetime` | Date and time |
| `enum` | Enumerated values (requires `enum_values`) |
| `file` | File attachment |
| `rich_text` | Rich text content |
| `json` | JSON data |
| `uuid` | UUID identifier |

### Validations

| Type | Options |
|------|---------|
| `presence` | — |
| `length` | `minimum`, `maximum`, `is`, `in` |
| `numericality` | `greater_than`, `greater_than_or_equal_to`, `less_than`, `less_than_or_equal_to`, `equal_to`, `allow_nil` |
| `format` | `with` (regex pattern) |
| `inclusion` | `in` (array of allowed values) |
| `exclusion` | `in` (array of excluded values) |
| `uniqueness` | `scope`, `case_sensitive` |
| `confirmation` | — |
| `custom` | `method` (name of custom validation method) |

Example:

```yaml
validations:
  - type: presence
  - type: length
    options: { minimum: 3, maximum: 100 }
  - type: numericality
    options: { greater_than_or_equal_to: 0, allow_nil: true }
```

### Associations

```yaml
associations:
  - type: belongs_to        # belongs_to, has_many, or has_one
    name: company           # association name
    target_model: company   # target model name (must be defined in models/)
    foreign_key: company_id # FK column (for belongs_to)
    required: true          # optional, defaults vary by type
    dependent: destroy      # optional (for has_many/has_one)
```

### Scopes

```yaml
scopes:
  - name: open_deals
    where_not: { stage: ["closed_won", "closed_lost"] }
  - name: won
    where: { stage: "closed_won" }
  - name: recent
    order: { created_at: desc }
    limit: 10
```

- `where` — generates `scope :name, -> { where(...) }`
- `where_not` — generates `scope :name, -> { where.not(...) }`
- `order` — generates `scope :name, -> { order(...) }`
- `limit` — generates `scope :name, -> { limit(...) }`

### Events

```yaml
events:
  - name: on_stage_change
    type: field_change      # field_change or lifecycle
    field: stage            # required for field_change
  - name: after_create
    type: lifecycle
```

### Full Example (`todo_item.yml`)

```yaml
model:
  name: todo_item
  label: "Todo Item"
  label_plural: "Todo Items"

  fields:
    - name: title
      type: string
      label: "Title"
      column_options:
        limit: 255
        "null": false
      validations:
        - type: presence

    - name: completed
      type: boolean
      label: "Completed"
      default: false

    - name: due_date
      type: date
      label: "Due Date"

  associations:
    - type: belongs_to
      name: todo_list
      target_model: todo_list
      foreign_key: todo_list_id
      required: true

  options:
    timestamps: true
    label_method: title
```

---

## Defining Presenters

File: `config/lcp_ruby/presenters/<name>.yml`

### Structure

```yaml
presenter:
  name: <presenter_name>
  model: <model_name>       # which model this presents
  label: "Display Label"
  slug: <url_slug>          # used in URL: /admin/<slug>
  icon: <icon_name>         # optional
  read_only: false          # optional, disables create/edit/destroy

  index: {}
  show: {}
  form: {}
  search: {}
  actions: {}
  navigation: {}
```

### Index Configuration

```yaml
index:
  default_view: table
  default_sort: { field: created_at, direction: desc }
  per_page: 25
  table_columns:
    - field: title
      width: "30%"
      link_to: show       # makes the cell a link to the show page
      sortable: true
    - field: stage
      width: "20%"
      display: badge      # display type
      sortable: true
    - field: value
      width: "20%"
      display: currency
      sortable: true
```

**Display types for columns:** `badge`, `currency`, `relative_date`

### Show Configuration

```yaml
show:
  layout:
    - section: "Section Title"
      columns: 2
      fields:
        - { field: title, display: heading }
        - { field: stage, display: badge }
        - { field: value, display: currency }
    - section: "Related Items"
      type: association_list   # renders associated records as a list
      association: contacts
```

**Display types for show fields:** `heading`, `badge`, `link`, `rich_text`, `currency`, `relative_date`

### Form Configuration

```yaml
form:
  sections:
    - title: "Section Title"
      columns: 2
      fields:
        - { field: title, placeholder: "Enter title...", autofocus: true }
        - { field: stage, input_type: select }
        - { field: value, input_type: number }
        - { field: company_id, input_type: association_select }
```

**Input types:**

| Input Type | Description |
|------------|-------------|
| `text` | Text input (default for string) |
| `textarea` | Multi-line text (default for text type) |
| `select` | Dropdown (default for enum type) |
| `number` | Numeric input |
| `date` / `date_picker` | Date picker |
| `datetime` | Datetime picker |
| `boolean` | Checkbox |
| `association_select` | Dropdown populated from associated model's records |
| `rich_text_editor` | Rich text editor |

### Search Configuration

```yaml
search:
  enabled: true
  searchable_fields: [title, description]
  placeholder: "Search..."
  predefined_filters:
    - { name: all, label: "All", default: true }
    - { name: open, label: "Open", scope: open_deals }
    - { name: won, label: "Won", scope: won }
```

Predefined filters render as buttons above the table. Each filter maps to a named scope defined in the model YAML.

### Actions Configuration

```yaml
actions:
  collection:
    - { name: create, type: built_in, label: "New Deal", icon: plus }
  single:
    - { name: show, type: built_in, icon: eye }
    - { name: edit, type: built_in, icon: pencil }
    - name: close_won
      type: custom
      label: "Close as Won"
      icon: check-circle
      confirm: true
      confirm_message: "Mark this deal as won?"
      visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
    - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
  batch: []
```

**Action types:**
- `built_in` — standard CRUD actions (`show`, `edit`, `destroy`, `create`); checked against `PermissionEvaluator.can?`
- `custom` — user-defined actions; checked against `can_execute_action?`; dispatched to registered action classes

**Action options:**
- `name` — action identifier
- `type` — `built_in` or `custom`
- `label` — display text
- `icon` — icon name
- `confirm` — show confirmation dialog (boolean)
- `confirm_message` — custom confirmation text
- `style` — CSS style hint (e.g., `danger`)
- `visible_when` — condition object `{ field, operator, value }` evaluated via ConditionEvaluator

### Navigation

```yaml
navigation:
  menu: main
  position: 3
```

### Full Example (`deal_admin.yml`)

```yaml
presenter:
  name: deal_admin
  model: deal
  label: "Deals"
  slug: deals
  icon: dollar-sign

  index:
    default_view: table
    default_sort: { field: created_at, direction: desc }
    per_page: 25
    table_columns:
      - { field: title, width: "30%", link_to: show, sortable: true }
      - { field: stage, width: "20%", display: badge, sortable: true }
      - { field: value, width: "20%", display: currency, sortable: true }

  show:
    layout:
      - section: "Deal Information"
        columns: 2
        fields:
          - { field: title, display: heading }
          - { field: stage, display: badge }
          - { field: value, display: currency }

  form:
    sections:
      - title: "Deal Details"
        columns: 2
        fields:
          - { field: title, placeholder: "Deal title...", autofocus: true }
          - { field: stage, input_type: select }
          - { field: value, input_type: number }
          - { field: company_id, input_type: association_select }
          - { field: contact_id, input_type: association_select }

  search:
    enabled: true
    searchable_fields: [title]
    placeholder: "Search deals..."
    predefined_filters:
      - { name: all, label: "All", default: true }
      - { name: open, label: "Open", scope: open_deals }
      - { name: won, label: "Won", scope: won }
      - { name: lost, label: "Lost", scope: lost }

  actions:
    collection:
      - { name: create, type: built_in, label: "New Deal", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - name: close_won
        type: custom
        label: "Close as Won"
        icon: check-circle
        confirm: true
        confirm_message: "Mark this deal as won?"
        visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }

  navigation:
    menu: main
    position: 3
```

---

## Defining Permissions

File: `config/lcp_ruby/permissions/<name>.yml`

### Structure

```yaml
permissions:
  model: <model_name>     # or "_default" for fallback permissions

  roles:
    <role_name>:
      crud: [index, show, create, update, destroy]
      fields:
        readable: all     # "all" or array of field names
        writable: all     # "all" or array of field names
      actions: all        # "all" or { allowed: [], denied: [] }
      scope: all          # "all" or type-specific scope config
      presenters: all     # "all" or array of presenter names

  default_role: <role_name>

  field_overrides: {}     # optional
  record_rules: []        # optional
```

### Action Aliases

The following aliases are automatically resolved:
- `edit` -> `update`
- `new` -> `create`

You only need to include `update` and `create` in the CRUD list; `edit` and `new` are inferred.

### Field Overrides

Override field-level access for specific roles, independent of the role's general `fields` setting:

```yaml
field_overrides:
  value:
    writable_by: [admin]
    readable_by: [admin, sales_rep]
```

### Record Rules

Deny CRUD operations on records matching a condition, with role exceptions:

```yaml
record_rules:
  - name: closed_deals_readonly
    condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
    effect:
      deny_crud: [update, destroy]
      except_roles: [admin]
```

**Condition operators:** `eq`, `not_eq`/`neq`, `in`, `not_in`, `gt`, `gte`, `lt`, `lte`, `present`, `blank`

### Full Example (`deal.yml`)

```yaml
permissions:
  model: deal

  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all
      presenters: all

    sales_rep:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [title, stage, company_id, contact_id]
      actions:
        allowed: [close_won]
        denied: []
      scope: all
      presenters: [deal_admin]

    viewer:
      crud: [index, show]
      fields: { readable: [title, stage, value], writable: [] }
      actions: { allowed: [] }
      scope: all
      presenters: [deal_pipeline]

  default_role: viewer

  field_overrides:
    value:
      writable_by: [admin]
      readable_by: [admin, sales_rep]

  record_rules:
    - name: closed_deals_readonly
      condition: { field: stage, operator: in, value: [closed_won, closed_lost] }
      effect:
        deny_crud: [update, destroy]
        except_roles: [admin]
```

---

## Custom Actions

Custom actions let host apps define domain-specific operations beyond CRUD.

### Creating an Action

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

### BaseAction API

**Available in `#call`:**
- `record` — the target record (single actions)
- `records` — array of records (batch actions)
- `current_user` — the current user
- `params` — request parameters
- `model_class` — the dynamic AR model class

**Return values:**
- `success(message:, redirect_to:, data:)` — successful result
- `failure(message:, errors:)` — failure result

**Optional overrides:**
- `#visible?(record, user)` — control visibility in the UI
- `#authorized?(record, user)` — additional authorization check
- `#param_schema` — define expected parameters

### Registering Actions

Reference the action in a presenter YAML:

```yaml
actions:
  single:
    - name: close_won
      type: custom
      label: "Close as Won"
      confirm: true
```

The action class is resolved by convention: `LcpRuby::HostActions::<Model>::<ActionName>`.

Enable auto-discovery in your initializer:

```ruby
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
end
```

---

## Event Handlers

Event handlers respond to model lifecycle events and field changes.

### Creating a Handler

Create a file at `app/event_handlers/<model>/<event>.rb`:

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
          Rails.logger.info("[CRM] Deal '#{record.title}' stage changed: #{old_stage} -> #{new_stage}")
        end
      end
    end
  end
end
```

### HandlerBase API

**Available in `#call`:**
- `record` — the affected record
- `changes` — hash of changed attributes
- `current_user` — the current user
- `event_name` — name of the triggered event
- `old_value(field)` — previous value of a field
- `new_value(field)` — new value of a field
- `field_changed?(field)` — whether a field changed

**Required class method:**
- `self.handles_event` — returns the event name string this handler responds to

**Optional overrides:**
- `async?` — return `true` to run via ActiveJob (`AsyncHandlerJob`)

### Registering Handlers

Enable auto-discovery in your initializer:

```ruby
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
```

---

## Host App Initializer Pattern

A complete initializer for a host app using both actions and event handlers:

```ruby
# config/initializers/lcp_ruby.rb
Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
```

---

## Association Selects

To render a dropdown populated from an associated model's records:

1. Use `input_type: association_select` on the FK field in the presenter form config:
   ```yaml
   form:
     sections:
       - fields:
           - { field: company_id, input_type: association_select }
   ```

2. **How it works internally:**
   - `LayoutBuilder` matches the FK field name (e.g., `company_id`) against `association.foreign_key` in model metadata
   - Creates a synthetic `FieldDefinition` (type: integer) with the `AssociationDefinition` attached
   - The form template renders a `<select>` populated from the target model's records via `LcpRuby.registry.model_for(assoc.target_model)`
   - Display text uses `to_label` (if defined) or `to_s`
   - Falls back to a number input if the target model is not registered in LCP

3. FK fields bypass the `field_writable?` permission check — they are permitted separately in the controller's `permitted_params`.

---

## Example Apps

### TODO (`examples/todo/`)

A minimal example demonstrating basic CRUD with associations.

**Models:** TodoList, TodoItem (has_many/belongs_to)

**Presenters:** todo_list_admin (lists), todo_item_admin (items)

**Permissions:** Single admin role with full access

**Features demonstrated:** basic CRUD, association_select, search, timestamps

```bash
cd examples/todo
bundle exec rails db:prepare
bundle exec rails s -p 3000
# Visit http://localhost:3000/admin
```

### CRM (`examples/crm/`)

A more complete example demonstrating advanced features.

**Models:** Company, Contact, Deal (1:N relationships)

**Presenters:**
- company_admin — company management
- contact_admin — contact management
- deal_admin — deal management with custom actions
- deal_pipeline — read-only pipeline view

**Roles:**
- `admin` — full access to everything
- `sales_rep` — restricted write access, can execute close_won action
- `viewer` — read-only access to limited fields and pipeline presenter

**Features demonstrated:**
- Custom action: `close_won` (marks deal as won)
- Event handler: `on_stage_change` (logs stage transitions)
- Scopes: `open_deals` (where_not closed), `won`, `lost`
- Predefined filters on deals index
- Field-level permissions (value writable only by admin)
- Record rules (closed deals read-only for non-admin)
- Field overrides (value readable by admin and sales_rep only)
- Enum fields with display badges
- Decimal fields with currency display

```bash
cd examples/crm
bundle exec rails db:prepare
bundle exec rails s -p 3001
# Visit http://localhost:3001/admin
```
