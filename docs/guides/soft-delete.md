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

## Associations and Soft Delete

### No Default Scope

Soft delete does **not** set a `default_scope` on the model. The `kept` scope is applied explicitly by the controller based on the presenter's `scope` attribute. This means:

- `Project.all` returns **all** records (kept + discarded)
- `Project.kept` returns only active records
- `Project.discarded` returns only archived records
- `project.tasks` returns **all** tasks (kept + discarded)

This is intentional — a hidden `default_scope` causes subtle bugs with joins, aggregation, and custom queries. The platform applies the right scope at the controller level so you get predictable behavior everywhere else.

### `dependent` Options for has_many

When the parent model has `soft_delete`, you have three choices for `dependent` on `has_many` associations:

| `dependent` value | On discard (parent) | On permanent destroy (parent) | Child requires soft_delete? |
|---|---|---|---|
| `:discard` | Cascade soft-delete to children | Hard-deletes parent only (children become orphans) | Yes |
| `:destroy` | No effect on children | Hard-deletes all children via `destroy!` | No |
| `:nullify` | No effect on children | Sets FK to `NULL` on all children | No |
| _(none)_ | No effect on children | Raises `ActiveRecord::InvalidForeignKey` if children exist | No |

**Rule of thumb:** Use `dependent: :discard` when children should follow the parent into the archive and back. Use `dependent: :destroy` when children have no meaning without the parent and should be deleted on permanent destroy.

### Cascade Discard

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

### belongs_to a Soft-Deletable Parent

A `belongs_to` association does not filter by `discarded_at`. If a project is discarded, `task.project` still returns the project object:

```ruby
task = Task.find(1)
task.project          # => #<Project id: 5, discarded_at: "2026-03-01 ...">
task.project.discarded?  # => true
```

This is the expected behavior — child records need to reference their parent even when the parent is archived (e.g., to display the project name in the task's show page).

If you need to check whether the parent is still active:

```ruby
task.project&.kept?   # => false (parent is discarded)
```

### has_many and the kept Scope

Since there is no `default_scope`, a parent's `has_many` association returns **all** children regardless of their `discarded_at`:

```ruby
project = Project.find(1)
project.tasks              # => all tasks (kept + discarded)
project.tasks.kept         # => only active tasks
project.tasks.discarded    # => only archived tasks
project.tasks.count        # => total count including discarded
project.tasks.kept.count   # => count of active tasks only
```

When displaying child records in a presenter (e.g., `association_list`), the controller applies the appropriate scope. But in custom code (event handlers, actions, scopes), you must apply `.kept` or `.discarded` explicitly.

### has_many :through with Soft Delete

For `has_many :through` associations, the join model typically does not need `soft_delete`. When the parent or the far-side model is discarded, the join record stays in the database — it just points to a discarded record.

```yaml
# The join model does NOT need soft_delete
model:
  name: project_tag
  associations:
    - { type: belongs_to, name: project, target_model: project }
    - { type: belongs_to, name: tag, target_model: tag }

# The parent has_many :through still returns all tags
model:
  name: project
  associations:
    - { type: has_many, name: project_tags, target_model: project_tag }
    - { type: has_many, name: tags, target_model: tag, through: project_tags }
  options:
    soft_delete: true
```

When a project is discarded, its tags remain accessible (the join records are untouched). When the project is restored, the tag associations are intact. There is no need for cascade on join tables.

If you need to cascade-discard the join records (e.g., to hide them from counts), add `soft_delete` to the join model and use `dependent: :discard` on the `has_many :project_tags` association.

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

## Common Use Cases

### Uniqueness Validation with Soft Delete

Standard `validates :uniqueness` checks **all** records in the table, including discarded ones. This means a user cannot create a new record with the same name as a discarded record:

```ruby
# This prevents reusing names of archived records:
field :code, :string do
  validates :uniqueness
end
```

To allow reusing names when the original is discarded, scope the uniqueness to kept records using a custom validation in an event handler or a `conditions` option:

```ruby
# In an event handler or initializer:
model_class.validates :code, uniqueness: { conditions: -> { kept } }
```

Note: this requires adding the validation in Ruby code (e.g., via an `after_model_build` event or a custom initializer), since YAML uniqueness validation does not support scope conditions. This is a deliberate trade-off — in most cases, preventing duplicate names across kept and discarded records is the safer default.

### Counting Only Active Records

When displaying counts (e.g., badges, dashboards), always use `.kept`:

```ruby
# In a custom action or condition service:
active_count = Project.kept.count
archived_count = Project.discarded.count
total_count = Project.count  # includes both
```

In presenters, use the `count_badge` on the archive view to show how many records are in the archive:

```yaml
# In menu.yml or view_group badges
menu:
  top_menu:
    - view_group: projects
      badge:
        type: count
        scope: discarded
```

### Querying Across the Soft Delete Boundary

Use `with_discarded` when you need all records regardless of status:

```ruby
# Reports that include archived data:
Project.with_discarded.where(status: "active").count

# Finding a record that might be discarded:
Project.with_discarded.find_by(code: "LEGACY-001")
```

The `with_discarded` scope is equivalent to `.all` (it removes any kept/discarded filtering). It exists for readability — it signals that you intentionally want both kept and discarded records.

### Presenter with All Records (with_discarded)

If you need a presenter that shows both kept and discarded records (e.g., an admin overview):

```yaml
presenter:
  name: project_all
  model: project
  label: "All Projects"
  slug: projects-all
  scope: with_discarded
```

The three valid presenter scope values:
- _(empty/unset)_ — shows only `kept` records (default)
- `"discarded"` — shows only discarded records (for archive views)
- `"with_discarded"` — shows all records

### Soft Delete with Userstamps

Soft delete and userstamps work well together. When a record is discarded, the `updated_by` fields are **not** updated (because `discard!` uses `update_columns`, which skips callbacks). If you need to track who discarded a record, use the `discarded_by_type` and `discarded_by_id` columns — these are set automatically.

```ruby
define_model :document do
  field :title, :string

  soft_delete
  userstamps store_name: true  # adds created_by_*, updated_by_*

  timestamps true
end
```

The archive presenter can display who last updated the record (before discard) and who discarded it:

```yaml
show:
  layout:
    - section: "Audit"
      fields:
        - { field: updated_by_name }    # last editor before archive
        - { field: discarded_by_type }  # "LcpRuby::Dynamic::ParentModel" if cascade
        - { field: discarded_by_id }    # ID of the record that triggered cascade
```

### Mixed Hard/Soft Delete in Associations

Not every child needs soft delete. You can mix strategies in a single parent:

```ruby
define_model :project do
  field :title, :string

  # Tasks follow the parent into archive and back
  has_many :tasks, model: :task, dependent: :discard

  # Comments are permanently deleted when project is permanently destroyed
  has_many :comments, model: :comment, dependent: :destroy

  # Watchers are unlinked (FK set to NULL) on permanent destroy
  has_many :watchers, model: :watcher, dependent: :nullify

  soft_delete
end
```

When the project is discarded: only tasks are cascade-discarded. Comments and watchers are untouched.
When the project is permanently destroyed: tasks become orphans (their FK still points to the deleted project), comments are hard-deleted, and watchers have their FK set to NULL.

### Preventing Permanent Destroy with Existing Children

If you want to prevent permanent destruction when a parent still has children, omit the `dependent` option and let the foreign key constraint raise an error:

```ruby
define_model :department do
  has_many :employees, model: :employee  # no dependent option

  soft_delete
end
```

Discarding the department works (children are not affected). But permanently destroying it raises `ActiveRecord::InvalidForeignKey` if any employees still reference it. This forces the admin to reassign employees first.

## Non-Soft-Deletable Models

Models without `soft_delete` continue to use hard delete. The `destroy` action calls `destroy!` as before, and no scopes or instance methods are added.

Source: `lib/lcp_ruby/model_factory/soft_delete_applicator.rb`, `lib/lcp_ruby/model_factory/schema_manager.rb`, `app/controllers/lcp_ruby/resources_controller.rb`
