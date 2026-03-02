# Soft Delete

Soft delete lets you archive records instead of permanently deleting them. Discarded records are hidden from normal views but remain in the database for recovery, auditing, and referential integrity.

## Setup

Enable soft delete on a model by adding `soft_delete: true` to the options:

```yaml
# config/lcp_ruby/models/project.yml
model:
  name: project
  fields:
    - { name: title, type: string }
    - { name: description, type: text }
  options:
    soft_delete: true
```

This automatically creates:
- A `discarded_at` datetime column
- Tracking columns `discarded_by_type` and `discarded_by_id` (for cascade tracking)
- Indexes on the above columns

### Custom Column Name

Use a hash to specify a custom column name:

```yaml
options:
  soft_delete:
    column: deleted_at
```

## How It Works

### Controller Behavior

When `soft_delete` is enabled on a model:

- **DELETE action** calls `discard!` instead of `destroy!` — sets `discarded_at` to the current timestamp
- **Index** applies the `kept` scope by default — discarded records are hidden
- **Show/Edit** scopes to `kept` — discarded records return 404

The flash message says "archived" instead of "deleted".

### Instance Methods

| Method | Description |
|--------|-------------|
| `discard!(by: nil)` | Mark the record as discarded. Optionally pass `by:` to track the source (used for cascade). Raises `LcpRuby::Error` if already discarded. |
| `undiscard!` | Restore the record. Cascades to children that were cascade-discarded by this record. Raises `LcpRuby::Error` if not discarded. |
| `discarded?` | Returns `true` if the record has been discarded |
| `kept?` | Returns `true` if the record has not been discarded |
| `cascade_discarded?` | Returns `true` if the record was discarded by a cascade (has `discarded_by_type` and `discarded_by_id` set) |

### Scopes

| Scope | Description |
|-------|-------------|
| `kept` | Records where `discarded_at` is `NULL` |
| `discarded` | Records where `discarded_at` is not `NULL` |
| `with_discarded` | All records (no filtering) |

## Cascade Discard

Use `dependent: :discard` on `has_many` associations to cascade the discard operation:

```yaml
# config/lcp_ruby/models/project.yml
model:
  name: project
  fields:
    - { name: title, type: string }
  associations:
    - type: has_many
      name: tasks
      target_model: task
      dependent: discard
  options:
    soft_delete: true

# config/lcp_ruby/models/task.yml
model:
  name: task
  fields:
    - { name: title, type: string }
  associations:
    - type: belongs_to
      name: project
      target_model: project
  options:
    soft_delete: true
```

When a project is discarded:
1. All kept child tasks are discarded with `discarded_by_type` and `discarded_by_id` pointing to the project
2. Already-discarded tasks are left untouched
3. Cascade continues to grandchildren if they also have `dependent: :discard`

When the project is restored (`undiscard!`):
1. Only tasks that were cascade-discarded **by this project** are restored
2. Tasks that were manually discarded before the cascade remain discarded

This preserves the intent of manual discards while cleanly reversing cascade operations.

## Archive Presenter

To let users browse and manage discarded records, create a separate presenter with `scope: discarded`:

```yaml
# config/lcp_ruby/presenters/project_archive.yml
presenter:
  name: project_archive
  model: project
  label: "Archived Projects"
  slug: projects-archive
  scope: discarded

  index:
    default_view: table
    per_page: 25
    table_columns:
      - { field: title, sortable: true }
      - { field: description }

  show:
    layout:
      - section: "Details"
        fields:
          - { field: title }
          - { field: description }

  actions:
    collection: []
    single:
      - { name: show, type: built_in }
      - { name: restore, type: built_in }
      - { name: permanently_destroy, type: built_in, confirm: true }
```

The `scope: discarded` makes the index show only discarded records. The `restore` action calls `undiscard!` and the `permanently_destroy` action calls `destroy!`.

## Permissions

Add `restore` and `permanently_destroy` to the CRUD list for roles that should manage archived records:

```yaml
# config/lcp_ruby/permissions/project.yml
permissions:
  model: project
  roles:
    admin:
      crud: [index, show, create, update, destroy, restore, permanently_destroy]
      fields: { readable: all, writable: all }
      scope: all
      presenters: all

    editor:
      crud: [index, show, create, update, destroy]
      fields: { readable: all, writable: all }
      scope: all
      presenters: [project]  # no access to archive presenter

    viewer:
      crud: [index, show]
      fields: { readable: all, writable: [] }
      scope: all
      presenters: [project]
```

The `restore` and `permanently_destroy` permissions are checked via Pundit like any other CRUD action. A role without these permissions will see 403 when attempting the action.

## Events

Soft delete dispatches two lifecycle events:

| Event | When |
|-------|------|
| `after_discard` | After a record is discarded (including cascade) |
| `after_undiscard` | After a record is restored (including cascade) |

You can handle these in event handlers:

```yaml
# In model YAML
events:
  - name: after_discard
    type: lifecycle
  - name: after_undiscard
    type: lifecycle
```

```ruby
# app/event_handlers/project/on_discard.rb
module LcpRuby
  module HostEventHandlers
    module Project
      class OnDiscard < LcpRuby::Events::HandlerBase
        def self.handles_event
          "after_discard"
        end

        def call
          Rails.logger.info("[App] Project '#{record.title}' was archived")
        end
      end
    end
  end
end
```

## DSL Usage

The same configuration can be expressed with the Ruby DSL:

```ruby
LcpRuby.define_model(:project) do
  field :title, :string
  field :description, :text

  has_many :tasks, model: :task, dependent: :discard

  soft_delete                      # uses default discarded_at column
  # soft_delete column: "deleted_at"  # custom column name
end
```

## Non-Soft-Deletable Models

Models without `soft_delete` continue to use hard delete. The `destroy` action calls `destroy!` as before, and no scopes or instance methods are added.

Source: `lib/lcp_ruby/model_factory/soft_delete_applicator.rb`, `lib/lcp_ruby/model_factory/schema_manager.rb`, `app/controllers/lcp_ruby/resources_controller.rb`
