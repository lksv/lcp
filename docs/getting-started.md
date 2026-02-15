# Getting Started

This guide walks you through installing LCP Ruby, defining your first model, presenter, and permission file, and running the application.

## Installation

Add LCP Ruby to your Gemfile:

```ruby
gem "lcp_ruby", path: "path/to/lcp-ruby"
```

Run `bundle install`.

Mount the engine in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount LcpRuby::Engine => "/admin"
end
```

## Configuration

Create an initializer at `config/initializers/lcp_ruby.rb`:

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

All options have sensible defaults. See [Engine Configuration](reference/engine-configuration.md) for details on each option.

## Directory Structure

Create the metadata directories:

```
config/lcp_ruby/
  models/         # Model definitions (fields, associations, scopes, events)
  presenters/     # UI definitions (index, show, form, actions, navigation)
  permissions/    # Role-based access control
```

Metadata auto-loads on Rails boot via the `lcp_ruby.load_metadata` initializer.

## Your First Model

Create `config/lcp_ruby/models/task.yml`:

```yaml
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

    - name: completed
      type: boolean
      label: "Completed"
      default: false

    - name: due_date
      type: date
      label: "Due Date"

  options:
    timestamps: true
    label_method: title
```

This creates a `tasks` database table with `title`, `completed`, and `due_date` columns, plus `created_at`/`updated_at` timestamps. See [Models Reference](reference/models.md) for all field types, validations, associations, and more.

> **Alternative:** You can also define models using a [Ruby DSL](reference/model-dsl.md) instead of YAML. The same model above in DSL syntax is `config/lcp_ruby/models/task.rb`.

## Your First Presenter

Create `config/lcp_ruby/presenters/task_admin.yml`:

```yaml
presenter:
  name: task_admin
  model: task
  label: "Tasks"
  slug: tasks
  icon: check-square

  index:
    default_sort: { field: created_at, direction: desc }
    per_page: 25
    table_columns:
      - { field: title, link_to: show, sortable: true }
      - { field: completed, sortable: true }
      - { field: due_date, sortable: true }

  show:
    layout:
      - section: "Task Details"
        columns: 2
        fields:
          - { field: title, display: heading }
          - { field: completed }
          - { field: due_date }

  form:
    sections:
      - title: "Task Details"
        columns: 2
        fields:
          - { field: title, placeholder: "Enter title...", autofocus: true }
          - { field: completed }
          - { field: due_date, input_type: date }

  search:
    enabled: true
    searchable_fields: [title]
    placeholder: "Search tasks..."

  actions:
    collection:
      - { name: create, type: built_in, label: "New Task", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }

  navigation:
    menu: main
    position: 1
```

See [Presenters Reference](reference/presenters.md) for all index, show, form, and action options.

## Your First Permission

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

  default_role: viewer
```

See [Permissions Reference](reference/permissions.md) for field overrides, record rules, and scope types.

## Run the Application

```bash
bundle exec rails db:prepare
bundle exec rails server
```

Visit `http://localhost:3000/admin/tasks` to see your task management interface.

## Next Steps

- [Models Reference](reference/models.md) — Add associations, scopes, events, and complex validations
- [Custom Actions](guides/custom-actions.md) — Add domain-specific operations
- [Event Handlers](guides/event-handlers.md) — React to model changes
- [Developer Tools](guides/developer-tools.md) — Validate configuration and generate ERD diagrams
- [Example Apps](examples.md) — See TODO and CRM examples
