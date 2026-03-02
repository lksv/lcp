# Userstamps Guide

This guide covers automatic user tracking in LCP Ruby. When enabled, userstamps automatically record **who created** and **who last modified** each record — analogous to how Rails manages `created_at` / `updated_at` timestamps, but for user identity.

## Quick Start

Add `userstamps` to your model definition:

**YAML:**

```yaml
model:
  name: document
  fields:
    - { name: title, type: string }
  options:
    userstamps: true
    timestamps: true
```

**DSL:**

```ruby
define_model :document do
  field :title, :string

  userstamps
  timestamps true
end
```

This automatically:
- Creates `created_by_id` and `updated_by_id` columns (`bigint`, nullable, indexed)
- Adds a `before_save` callback that sets them from `LcpRuby::Current.user`
- Adds `belongs_to :created_by` and `belongs_to :updated_by` associations

No additional setup is required — the platform handles column creation, callbacks, and associations.

## How It Works

The `UserstampsApplicator` registers a `before_save` callback on the model:

- **On create** (`new_record?`): sets both `created_by_id` and `updated_by_id` to `Current.user.id`
- **On update**: sets only `updated_by_id` — the creator is never overwritten
- **No user** (`Current.user` is nil): writes `nil` to the fields without raising an error

`LcpRuby::Current.user` is set automatically in `ApplicationController` for web requests. In seeds, jobs, or console sessions, set it manually:

```ruby
LcpRuby::Current.user = LcpRuby::User.find_by(email: "admin@example.com")
# ... create/update records ...
LcpRuby::Current.user = nil
```

> **Note:** `update_columns` bypasses the callback by design, just like Rails timestamps.

## Name Snapshots

By default, userstamps only store user IDs. Enable `store_name: true` to also capture a denormalized copy of the user's name at the time of create/update:

**YAML:**

```yaml
options:
  userstamps:
    store_name: true
```

**DSL:**

```ruby
userstamps store_name: true
```

This adds two additional `string` columns:
- `created_by_name` — set once on create
- `updated_by_name` — refreshed on every save

Name snapshots are useful when:
- You want to display "Created by Jane Doe" without a JOIN
- The user's name might change later, but you want to preserve the name at creation time
- You need fast index rendering without eager-loading the user association

The name is read from `Current.user.name`. Ensure your user model responds to `name`.

## Custom Column Names

Override the default column names when your domain model uses different terminology:

**YAML:**

```yaml
options:
  userstamps:
    created_by: author_id
    updated_by: editor_id
    store_name: true
```

**DSL:**

```ruby
userstamps created_by: :author_id, updated_by: :editor_id, store_name: true
```

This creates:
- `author_id` / `editor_id` (FK columns)
- `author_name` / `editor_name` (name columns, derived by replacing `_id` with `_name`)
- `belongs_to :author` / `belongs_to :editor` associations

## Displaying in Presenters

Userstamp fields are not regular model fields — they are auto-generated columns. To display them, reference them directly in your presenter:

### Index Columns

```ruby
index do
  column :title, link_to: :show
  column :created_by_name, label: "Created by"
  column :updated_by_name, label: "Last modified by"
  column :updated_at, renderer: :relative_date
end
```

### Show Page

```ruby
show do
  section "Details" do
    field :title, renderer: :heading
  end

  section "Audit Trail", columns: 2 do
    field :created_by_name, label: "Created by"
    field :created_at, renderer: :datetime
    field :updated_by_name, label: "Last modified by"
    field :updated_at, renderer: :datetime
  end
end
```

### Forms

Userstamp fields should **not** appear in forms — they are set automatically by the platform. Simply omit them from your form sections:

```ruby
form do
  section "Document" do
    field :title
    field :status, input_type: :select
  end
end
```

## Permissions

When `readable: all` is used in permissions, userstamp columns (and timestamp columns) are automatically included. No additional configuration is needed.

If you use explicit field lists, add the userstamp columns you want to expose:

```yaml
permissions:
  model: document
  roles:
    viewer:
      crud: [index, show]
      fields:
        readable: [title, status, created_by_name, updated_by_name, created_at, updated_at]
        writable: []
    editor:
      crud: [index, show, create, update]
      fields:
        readable: all
        writable: [title, status]
```

> **Note:** Userstamp columns should never be writable — the `before_save` callback manages them.

## Validation

The `ConfigurationValidator` checks for:

- **Field conflicts** — error if `created_by_id` (or custom name) is also defined as an explicit field
- **Name column conflicts** — error if `created_by_name` collides with an explicit field (when `store_name: true`)
- **Missing timestamps** — warning if userstamps are enabled without `timestamps: true` (not an error, but recommended)

## Complete Example

### Model

```ruby
define_model :tracked_document do
  label "Tracked Document"
  label_plural "Tracked Documents"

  field :title, :string, limit: 200, null: false do
    validates :presence
  end
  field :content, :text
  field :status, :enum, default: "draft",
    values: { draft: "Draft", review: "Review", published: "Published", archived: "Archived" }

  scope :published, where: { status: "published" }
  scope :drafts, where: { status: "draft" }

  userstamps store_name: true
  timestamps true
  label_method :title
end
```

### Presenter

```ruby
define_presenter :tracked_document do
  model :tracked_document
  label "Documents"
  slug "documents"

  index do
    default_sort :updated_at, :desc
    column :title, link_to: :show, sortable: true
    column :status, renderer: :badge
    column :created_by_name, label: "Created by"
    column :updated_by_name, label: "Modified by"
    column :updated_at, renderer: :relative_date, sortable: true
  end

  show do
    section "Document" do
      field :title, renderer: :heading
      field :status, renderer: :badge
    end

    section "Content" do
      field :content
    end

    section "Audit Trail", columns: 2 do
      field :created_by_name, label: "Created by"
      field :created_at, renderer: :datetime
      field :updated_by_name, label: "Last modified by"
      field :updated_at, renderer: :datetime
    end
  end

  form do
    section "Document" do
      field :title, autofocus: true
      field :status, input_type: :select
    end

    section "Content" do
      field :content, input_type: :textarea
    end
  end

  action :create, type: :built_in, on: :collection
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
```

### Seeds

```ruby
admin = LcpRuby::User.find_by(email: "admin@example.com")
LcpRuby::Current.user = admin

DocumentModel = LcpRuby.registry.model_for("tracked_document")
DocumentModel.create!(title: "First Document", content: "Created by admin.", status: "published")

LcpRuby::Current.user = nil
```

## Configuration Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `created_by` | string | `"created_by_id"` | Creator FK column name |
| `updated_by` | string | `"updated_by_id"` | Updater FK column name |
| `store_name` | boolean | `false` | Add denormalized `_name` snapshot columns |

The `user_class` engine configuration option determines which class the `belongs_to` associations point to. See [Engine Configuration — user_class](../reference/engine-configuration.md#user_class).

Source: `lib/lcp_ruby/model_factory/userstamps_applicator.rb`
