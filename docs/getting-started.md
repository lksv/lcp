# Getting Started

This guide walks you through building a two-model TODO application with LCP Ruby — from installation to custom actions and event handlers. By the end, you'll have task lists and tasks with associations, search filters, a custom action, and an event handler.

All examples use the **Ruby DSL** as the primary format. YAML equivalents are provided in collapsible blocks.

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Ruby | >= 3.1 |
| Rails | >= 7.1, < 9.0 |
| Database | SQLite (development), PostgreSQL (production recommended) |

LCP Ruby works with any Rails-supported database. SQLite is fine for development and this tutorial.

## Installation

Add LCP Ruby to your Gemfile:

```ruby
gem "lcp_ruby", path: "path/to/lcp-ruby"
```

Run `bundle install`.

Mount the engine in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount LcpRuby::Engine => "/"
end
```

> **Tip:** If you want `http://localhost:3000/` to redirect to your first model's index, add a root route pointing to the engine's slug (e.g., `root to: redirect("/task_lists")`).

## Configuration

Create an initializer at `config/initializers/lcp_ruby.rb`:

```ruby
LcpRuby.configure do |config|
  config.authentication = :none
end
```

This is the minimal configuration for a quickstart. All other options have sensible defaults.

### Authentication Modes

| Mode | Use Case | `current_user` |
|------|----------|----------------|
| `:none` | Quickstart / prototyping | Not required |
| `:external` | Existing app with its own auth (Devise, etc.) | Provided by host app |
| `:built_in` | Standalone app without existing auth | Managed by LCP Ruby |

The default is `:external`. This tutorial uses `:none` so you can skip authentication setup entirely. See [Authentication Setup](#authentication-setup) below when you're ready to add auth.

See [Engine Configuration](reference/engine-configuration.md) for all available options.

## Directory Structure

Create the metadata directories:

```
config/lcp_ruby/
  types/          # Custom business type definitions (optional)
  models/         # Model definitions — .rb (DSL) or .yml (YAML)
  presenters/     # UI definitions — .rb (DSL) or .yml (YAML)
  permissions/    # Role-based access control — .yml only
```

Both `.rb` (DSL) and `.yml` (YAML) files are supported for models and presenters. Each model/presenter name must be unique across all files — defining the same name in both formats raises `MetadataError`.

> **Note:** Permissions are YAML-only. There is no DSL loader for permission files.

Metadata auto-loads on Rails boot via the `lcp_ruby.load_metadata` initializer.

## Authentication Setup

> **Skip this section** if you're using `authentication: :none` (as in this tutorial).

When using `authentication: :external`, your host app must provide a `current_user` object. The user model must implement the method configured by `role_method` (default: `lcp_role`), returning an **array of role name strings**:

```ruby
class User < ApplicationRecord
  def lcp_role
    roles.pluck(:name)  # => ["admin", "sales_rep"]
  end
end
```

Your `ApplicationController` must provide `current_user` (typically via Devise, Sorcery, or a custom session-based auth):

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user
end
```

The role strings must match the role names defined in your [permissions YAML](reference/permissions.md).

## Your First Model: Task List

Create `config/lcp_ruby/models/task_list.rb`:

```ruby
define_model :task_list do
  label "Task List"
  label_plural "Task Lists"

  field :title, :string, label: "Title" do
    validates :presence
    validates :length, minimum: 3, maximum: 255
  end

  field :description, :text, label: "Description"

  timestamps true
  label_method :title
end
```

This creates a `task_lists` database table with `title` and `description` columns, plus `created_at`/`updated_at` timestamps.

Key concepts:
- **`field`** — defines a database column with a name and type
- **`validates`** — adds ActiveRecord validations (inside a field block, the field context is implicit)
- **`timestamps`** — adds `created_at` and `updated_at` columns
- **`label_method`** — the method called on records to generate display text (e.g., in association select dropdowns)

<details>
<summary>YAML equivalent</summary>

```yaml
# config/lcp_ruby/models/task_list.yml
model:
  name: task_list
  label: "Task List"
  label_plural: "Task Lists"

  fields:
    - name: title
      type: string
      label: "Title"
      validations:
        - type: presence
        - type: length
          minimum: 3
          maximum: 255

    - name: description
      type: text
      label: "Description"

  options:
    timestamps: true
    label_method: title
```
</details>

See [Models Reference](reference/models.md) for all field types, validations, associations, and more. See [Model DSL Reference](reference/model-dsl.md) for the full DSL syntax.

## Your First Presenter: Task List

Create `config/lcp_ruby/presenters/task_list.rb`:

```ruby
define_presenter :task_list do
  model :task_list
  label "Task Lists"
  slug "task_lists"
  icon "list"

  index do
    default_sort :created_at, :desc
    per_page 25
    empty_message "No task lists yet. Create your first list to get started."
    column :title, link_to: :show, sortable: true
    column :description
  end

  show do
    section "List Details" do
      field :title, renderer: :heading
      field :description
    end
  end

  form do
    section "List Details" do
      field :title, placeholder: "My shopping list...", autofocus: true
      field :description, input_type: :textarea, placeholder: "Optional description..."
    end
  end

  search do
    searchable_fields :title, :description
    placeholder "Search lists..."
  end

  action :create, type: :built_in, on: :collection, label: "New List", icon: "plus"
  action :show,   type: :built_in, on: :single, icon: "eye"
  action :edit,   type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger

  navigation menu: :main, position: 1
end
```

Key concepts:
- **`index`** — configures the list/table view (columns, sorting, pagination, empty state)
- **`show`** — configures the detail view with sections and renderers
- **`form`** — configures create/edit forms with input types and placeholders
- **`search`** — enables text search across specified fields
- **`action`** — defines UI buttons (built-in CRUD or custom business logic)
- **`navigation`** — places the model in the navigation menu

<details>
<summary>YAML equivalent</summary>

```yaml
# config/lcp_ruby/presenters/task_list.yml
presenter:
  name: task_list
  model: task_list
  label: "Task Lists"
  slug: task_lists
  icon: list

  index:
    default_sort: { field: created_at, direction: desc }
    per_page: 25
    empty_message: "No task lists yet. Create your first list to get started."
    table_columns:
      - { field: title, link_to: show, sortable: true }
      - { field: description }

  show:
    layout:
      - section: "List Details"
        fields:
          - { field: title, renderer: heading }
          - { field: description }

  form:
    sections:
      - title: "List Details"
        fields:
          - { field: title, placeholder: "My shopping list...", autofocus: true }
          - { field: description, input_type: textarea, placeholder: "Optional description..." }

  search:
    enabled: true
    searchable_fields: [title, description]
    placeholder: "Search lists..."

  actions:
    collection:
      - { name: create, type: built_in, label: "New List", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }

  navigation:
    menu: main
    position: 1
```
</details>

See [Presenters Reference](reference/presenters.md) for all options. See [Presenter DSL Reference](reference/presenter-dsl.md) for the full DSL syntax.

## Your First Permissions: Task List

Create `config/lcp_ruby/permissions/task_list.yml`:

```yaml
permissions:
  model: task_list

  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all
      presenters: all

    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      actions: { allowed: [] }
      scope: all
      presenters: all

  default_role: admin
```

Key concepts:
- **`roles`** — each key is a role name matched against `current_user.lcp_role`
- **`crud`** — which operations the role can perform (`index`, `show`, `create`, `update`, `destroy`)
- **`fields`** — which fields the role can read and write (`all` or an explicit list)
- **`default_role`** — assigned when the user has no matching role (set to `admin` here since we're using `authentication: :none`)

> **Warning:** We use `default_role: admin` only because this tutorial runs without authentication. When you switch to `authentication: :external` or `:built_in`, change `default_role` to a restrictive role like `viewer` so unauthenticated or unknown users don't get full access.

> **Tip:** You can create `config/lcp_ruby/permissions/_default.yml` with `model: _default` to provide fallback permissions for all models that don't have their own permission file.

See [Permissions Reference](reference/permissions.md) for field overrides, record rules, and scope types.

## Run and Verify

```bash
bundle exec rails db:prepare
bundle exec rails server
```

Visit `http://localhost:3000/task_lists`. You should see:

1. **Empty state** — the message "No task lists yet. Create your first list to get started."
2. **"New List" button** — click it to open the create form
3. **Form** — `title` field with placeholder text and autofocus, `description` textarea
4. **After saving** — redirects to the show page with your list details
5. **Navigation menu** — "Task Lists" link in the top navigation

Try creating a list, editing it, and searching for it by title.

## Second Model with Association: Task

Now add a `task` model that belongs to a task list.

### Update the Task List Model

First, update `config/lcp_ruby/models/task_list.rb` to add a `has_many` association:

```ruby
define_model :task_list do
  label "Task List"
  label_plural "Task Lists"

  field :title, :string, label: "Title" do
    validates :presence
    validates :length, minimum: 3, maximum: 255
  end

  field :description, :text, label: "Description"

  has_many :tasks, model: :task, dependent: :destroy

  timestamps true
  label_method :title
end
```

### Update the Task List Presenter

Now that task_list has tasks, update the show section in `config/lcp_ruby/presenters/task_list.rb` to display them:

```ruby
show do
  section "List Details" do
    field :title, renderer: :heading
    field :description
  end

  association_list "Tasks", association: :tasks
end
```

The `association_list` renders a list of associated records below the detail section. This is auto-detected for eager loading — no manual `includes` needed.

<details>
<summary>YAML equivalent — updated show section</summary>

```yaml
show:
  layout:
    - section: "List Details"
      fields:
        - { field: title, renderer: heading }
        - { field: description }
    - section: "Tasks"
      type: association_list
      association: tasks
```
</details>

### Create the Task Model

Create `config/lcp_ruby/models/task.rb`:

```ruby
define_model :task do
  label "Task"
  label_plural "Tasks"

  field :title, :string, label: "Title" do
    validates :presence
  end

  field :status, :enum, label: "Status", default: "pending",
    values: { pending: "Pending", in_progress: "In Progress", completed: "Completed" }

  field :due_date, :date, label: "Due Date"

  field :notes, :text, label: "Notes"

  belongs_to :task_list, model: :task_list, required: true

  scope :active,    where_not: { status: "completed" }
  scope :completed, where: { status: "completed" }

  on_field_change :on_status_change, field: :status

  timestamps true
  label_method :title
end
```

Key concepts:
- **`belongs_to`** — creates a foreign key (`task_list_id`) linking each task to a task list
- **`has_many`** — on the parent model, declares the inverse relationship (with `dependent: :destroy` to cascade deletes)
- **`:enum`** with **`values:`** — a string field constrained to a set of labeled values, rendered as a `<select>` by default
- **`scope`** — named query filters (used by presenter filter tabs)
- **`on_field_change`** — declares a field change event that triggers when `status` changes (handler created [later](#adding-an-event-handler))

<details>
<summary>YAML equivalent — task_list.yml (updated)</summary>

```yaml
# config/lcp_ruby/models/task_list.yml
model:
  name: task_list
  label: "Task List"
  label_plural: "Task Lists"

  fields:
    - name: title
      type: string
      label: "Title"
      validations:
        - type: presence
        - type: length
          minimum: 3
          maximum: 255

    - name: description
      type: text
      label: "Description"

  associations:
    - type: has_many
      name: tasks
      target_model: task
      dependent: destroy

  options:
    timestamps: true
    label_method: title
```
</details>

<details>
<summary>YAML equivalent — task.yml</summary>

```yaml
# config/lcp_ruby/models/task.yml
model:
  name: task
  label: "Task"
  label_plural: "Tasks"

  fields:
    - name: title
      type: string
      label: "Title"
      validations:
        - type: presence

    - name: status
      type: enum
      label: "Status"
      default: "pending"
      enum_values:
        - { value: pending, label: "Pending" }
        - { value: in_progress, label: "In Progress" }
        - { value: completed, label: "Completed" }

    - name: due_date
      type: date
      label: "Due Date"

    - name: notes
      type: text
      label: "Notes"

  associations:
    - type: belongs_to
      name: task_list
      target_model: task_list
      required: true

  scopes:
    - name: active
      where_not: { status: "completed" }
    - name: completed
      where: { status: "completed" }

  events:
    - name: on_status_change
      type: field_change
      field: status

  options:
    timestamps: true
    label_method: title
```
</details>

## Second Presenter: Task

Create `config/lcp_ruby/presenters/task.rb`:

```ruby
define_presenter :task do
  model :task
  label "Tasks"
  slug "tasks"
  icon "check-square"

  index do
    default_sort :created_at, :desc
    per_page 25
    empty_message "No tasks yet. Create your first task to get started."
    column :title, link_to: :show, sortable: true
    column "task_list.title", label: "List", sortable: true
    column :status, renderer: :badge, sortable: true
    column :due_date, sortable: true
  end

  show do
    section "Task Details", columns: 2 do
      field :title, renderer: :heading
      field :status, renderer: :badge
      field "task_list.title", label: "List"
      field :due_date
      field :notes
    end
  end

  form do
    section "Task Details", columns: 2 do
      field :title, placeholder: "What needs to be done?", autofocus: true
      field :task_list_id, input_type: :association_select
      field :status, input_type: :select
      field :due_date, input_type: :date
    end

    section "Notes" do
      field :notes, input_type: :textarea, placeholder: "Additional details..."
    end
  end

  search do
    searchable_fields :title
    placeholder "Search tasks..."
    filter :all, label: "All", default: true
    filter :active, label: "Active", scope: :active
    filter :completed, label: "Completed", scope: :completed
  end

  action :create,  type: :built_in, on: :collection, label: "New Task", icon: "plus"
  action :show,    type: :built_in, on: :single, icon: "eye"
  action :edit,    type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger

  navigation menu: :main, position: 2
end
```

Key concepts:
- **`"task_list.title"`** — dot-notation traverses the `belongs_to` association to display the related list's title
- **`label: "List"`** — overrides the auto-generated column header for dot-notation fields
- **`input_type: :association_select`** — renders a `<select>` dropdown populated from the target model's records (uses `label_method` for display text)
- **`renderer: :badge`** — renders enum values as colored badges
- **`filter`** — creates tabbed filters that apply named scopes from the model

<details>
<summary>YAML equivalent</summary>

```yaml
# config/lcp_ruby/presenters/task.yml
presenter:
  name: task
  model: task
  label: "Tasks"
  slug: tasks
  icon: check-square

  index:
    default_sort: { field: created_at, direction: desc }
    per_page: 25
    empty_message: "No tasks yet. Create your first task to get started."
    table_columns:
      - { field: title, link_to: show, sortable: true }
      - { field: "task_list.title", label: "List", sortable: true }
      - { field: status, renderer: badge, sortable: true }
      - { field: due_date, sortable: true }

  show:
    layout:
      - section: "Task Details"
        columns: 2
        fields:
          - { field: title, renderer: heading }
          - { field: status, renderer: badge }
          - { field: "task_list.title", label: "List" }
          - { field: due_date }
          - { field: notes }

  form:
    sections:
      - title: "Task Details"
        columns: 2
        fields:
          - { field: title, placeholder: "What needs to be done?", autofocus: true }
          - { field: task_list_id, input_type: association_select }
          - { field: status, input_type: select }
          - { field: due_date, input_type: date }
      - title: "Notes"
        fields:
          - { field: notes, input_type: textarea, placeholder: "Additional details..." }

  search:
    enabled: true
    searchable_fields: [title]
    placeholder: "Search tasks..."
    predefined_filters:
      - { name: all, label: "All", default: true }
      - { name: active, label: "Active", scope: active }
      - { name: completed, label: "Completed", scope: completed }

  actions:
    collection:
      - { name: create, type: built_in, label: "New Task", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }

  navigation:
    menu: main
    position: 2
```
</details>

## Second Permissions: Task

Create `config/lcp_ruby/permissions/task.yml`:

```yaml
permissions:
  model: task

  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions: all
      scope: all
      presenters: all

    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      actions: { allowed: [] }
      scope: all
      presenters: all

  default_role: admin
```

## Run and Verify: Associations

Restart the server (the database tables are created on boot when `auto_migrate` is enabled):

```bash
bundle exec rails server
```

Now you should see:

1. **Navigation** — both "Task Lists" and "Tasks" in the top menu
2. **Create a task list first** — go to Task Lists and create one (tasks need a list to belong to)
3. **Create a task** — go to Tasks, click "New Task"; the "Task list" dropdown shows your lists
4. **Dot-notation column** — the "List" column on the tasks index shows the related list's title
5. **Association list** — the task list show page displays its tasks below the detail section
6. **Filter tabs** — "All", "Active", and "Completed" tabs filter tasks by status scope

## Adding a Custom Action

Let's add a "Mark Completed" button that sets a task's status to `completed`.

### Step 1: Create the Action Class

Create `app/actions/task/mark_completed.rb`:

```ruby
module LcpRuby
  module HostActions
    module Task
      class MarkCompleted < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No task specified")
          end

          if record.status == "completed"
            return failure(message: "Task is already completed")
          end

          record.update!(status: "completed")
          success(message: "Task '#{record.title}' marked as completed!")
        end
      end
    end
  end
end
```

The class is resolved by naming convention: `LcpRuby::HostActions::<Model>::<ActionName>`.

### Step 2: Add the Action to the Presenter

Update `config/lcp_ruby/presenters/task.rb` — add this action alongside the existing ones:

```ruby
action :mark_completed, type: :custom, on: :single,
  label: "Mark Completed", icon: "check",
  confirm: true, confirm_message: "Mark this task as completed?",
  visible_when: { field: :status, operator: :not_eq, value: "completed" }
```

The `visible_when` condition hides the button when the task is already completed.

### Step 3: Add to Permissions

Update `config/lcp_ruby/permissions/task.yml` — change `actions: all` to an explicit list that includes `mark_completed`:

```yaml
permissions:
  model: task

  roles:
    admin:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      actions:
        allowed: [mark_completed]
      scope: all
      presenters: all

    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      actions: { allowed: [] }
      scope: all
      presenters: all

  default_role: admin
```

### Step 4: Enable Auto-Discovery

Update `config/initializers/lcp_ruby.rb` to discover action and event handler classes:

```ruby
LcpRuby.configure do |config|
  config.authentication = :none
end

Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
```

Restart the server. Tasks that are not yet completed now show a "Mark Completed" button on the show page and in the index row actions.

## Adding an Event Handler

The task model already declares `on_field_change :on_status_change, field: :status`. Let's create the handler that responds when a task's status changes.

Create `app/event_handlers/task/on_status_change.rb`:

```ruby
module LcpRuby
  module HostEventHandlers
    module Task
      class OnStatusChange < LcpRuby::Events::HandlerBase
        def self.handles_event
          "on_status_change"
        end

        def call
          old_status = old_value("status")
          new_status = new_value("status")
          Rails.logger.info(
            "[TODO] Task '#{record.title}' status changed: #{old_status} -> #{new_status}"
          )
        end
      end
    end
  end
end
```

Key concepts:
- **`self.handles_event`** — returns the event name string matching the model's `on_field_change` declaration
- **`old_value` / `new_value`** — access the previous and current field values
- **`record`** — the affected ActiveRecord instance
- Auto-discovered via `HandlerRegistry.discover!` (added in the previous step)

The class is resolved by convention: `LcpRuby::HostEventHandlers::<Model>::<HandlerName>`.

Restart the server, then change a task's status. Check the Rails log to see the event handler output.

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `NoMethodError: undefined method 'lcp_role'` | User model missing role method | Add `lcp_role` method to your User model or use `authentication: :none` |
| `MetadataError: Duplicate model` | Same model defined in both `.rb` and `.yml` | Use one format per model |
| Action class not found | Not auto-discovered | Add `ActionRegistry.discover!` to your initializer |
| Table not created | Server not restarted after adding a model | Restart the server (`auto_migrate` creates tables on boot) |
| Association select is empty | No records exist in the target model | Create target records first (e.g., create a task list before a task) |
| `Pundit::NotAuthorizedError` | Missing permissions file for the model | Create a permissions YAML file or a `_default.yml` fallback |
| Custom action button not visible | `visible_when` hides it or action not in `actions.allowed` | Check both presenter `visible_when` conditions and permissions `actions.allowed` |
| Search returns no results | Field not included in `searchable_fields` | Add the field to the `search` block's `searchable_fields` |
| Event handler not firing | Event not declared in model or handler not discovered | Verify `on_field_change` in model DSL, `handles_event` return value matches the event name, and `HandlerRegistry.discover!` in initializer |

## Next Steps

- [Models Reference](reference/models.md) — All field types, validations, associations, scopes, and events
- [Model DSL Reference](reference/model-dsl.md) — Full Ruby DSL syntax for models
- [Presenters Reference](reference/presenters.md) — All index, show, form, search, and action options
- [Presenter DSL Reference](reference/presenter-dsl.md) — Full Ruby DSL syntax for presenters (with inheritance)
- [Permissions Reference](reference/permissions.md) — Field overrides, record rules, scope types
- [Types Reference](reference/types.md) — Business types (email, phone, url, color) and custom types
- [Custom Types Guide](guides/custom-types.md) — Practical custom type examples
- [Attachments Guide](guides/attachments.md) — File upload with Active Storage
- [Custom Actions](guides/custom-actions.md) — Advanced action patterns
- [Event Handlers](guides/event-handlers.md) — Async handlers, lifecycle events
- [Conditional Rendering](guides/conditional-rendering.md) — `visible_when` and `disable_when` on fields, sections, and actions
- [Extensibility Guide](guides/extensibility.md) — Transforms, validators, defaults, computed fields, condition services
- [View Groups Guide](guides/view-groups.md) — Multi-view navigation and view switcher
- [Menu Guide](guides/menu.md) — Custom navigation menus
- [Custom Fields Guide](guides/custom-fields.md) — Runtime user-defined fields
- [Developer Tools](guides/developer-tools.md) — Validate configuration, generate ERD diagrams, inspect permissions
- [Engine Configuration](reference/engine-configuration.md) — All `LcpRuby.configure` options
- [Example Apps](examples.md) — Complete TODO and CRM walkthroughs
