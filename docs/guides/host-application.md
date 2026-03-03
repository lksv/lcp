# Creating a Host Application

This guide walks through creating a new Rails application powered by the LCP Ruby platform, from scaffold to working app.

## Prerequisites

- Ruby >= 3.1
- Rails >= 7.1
- The `lcp_ruby` gem (local path or published)

## Step 1: Create the Rails App

```bash
rails new my-app --skip-test --skip-system-test --database=sqlite3
```

You can skip frameworks you don't need (e.g., `--skip-action-mailer`, `--skip-hotwire`), but LCP Ruby will pull in `turbo-rails` and `stimulus-rails` as dependencies.

## Step 2: Add LCP Ruby to the Gemfile

```ruby
# Gemfile
gem "lcp_ruby", path: "../lcp-ruby"  # or published gem source
```

Run `bundle install`.

## Step 3: Configure `config/application.rb`

Ensure `lcp_ruby` is required and Active Storage is available (needed for attachment fields):

```ruby
require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "lcp_ruby"

module MyApp
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
  end
end
```

## Step 4: Mount the Engine in Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount LcpRuby::Engine => "/app"  # or "/" for root mounting
  root to: redirect("/app/my-first-presenter-slug")
end
```

## Step 5: Set Up `current_user`

LCP Ruby expects `current_user` to respond to `id`, `lcp_role` (array of role strings), and `name`:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  def current_user
    role = session[:role] || "admin"
    @current_user ||= OpenStruct.new(
      id: 1,
      lcp_role: [role],
      name: "Demo User (#{role})"
    )
  end
  helper_method :current_user
end
```

For production apps, replace this with your real authentication (Devise, custom, or LCP Ruby's built-in auth via `config.authentication = :built_in`).

## Step 6: Create the LCP Ruby Initializer

```ruby
# config/initializers/lcp_ruby.rb
LcpRuby.configure do |config|
  config.breadcrumb_home_path = "/app"
  config.menu_mode = :strict  # only show menu items defined in menu.yml
end

Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
```

## Step 7: Create Metadata Directory Structure

```
config/lcp_ruby/
├── models/          # Model definitions (.rb DSL or .yml)
├── presenters/      # Presenter definitions (.rb DSL or .yml)
├── permissions/     # Permission definitions (.yml)
├── views/           # View group definitions (.yml)
└── menu.yml         # Navigation menu
```

```bash
mkdir -p config/lcp_ruby/{models,presenters,permissions,views}
```

## Step 8: Define Your First Model

Models can be defined as Ruby DSL (`.rb`) or YAML (`.yml`) files.

**DSL format** (`config/lcp_ruby/models/task.rb`):

```ruby
define_model :task do
  label "Task"
  label_plural "Tasks"

  field :title, :string, label: "Title", limit: 200, null: false do
    validates :presence
  end

  field :description, :text, label: "Description"
  field :completed, :boolean, label: "Completed", default: false

  timestamps true
  label_method :title
end
```

### Key Gotchas

**Tree models** require `parent_id` as an explicit integer field:

```ruby
define_model :category do
  field :name, :string, null: false do
    validates :presence
  end
  field :parent_id, :integer  # MUST declare this explicitly

  tree true  # creates belongs_to :parent, has_many :children automatically

  timestamps true
  label_method :name
end
```

**Self-referential associations** (e.g., manager hierarchy) use the `model:` option pointing back to the same model:

```ruby
belongs_to :manager, model: :employee, required: false
has_many :direct_reports, model: :employee, foreign_key: :manager_id
```

**Computed fields** use `{field_name}` template syntax:

```ruby
field :full_name, :string, computed: "{first_name} {last_name}"
```

**Available transforms:** `strip`, `downcase`, `normalize_url`, `normalize_phone`. There is no `titlecase` transform.

**Built-in types** (auto-configure transforms and validations): `email`, `phone`, `url`, `color`.

## Step 9: Define Permissions

At minimum, define `config/lcp_ruby/permissions/default.yml`:

```yaml
permissions:
  model: _default

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

  default_role: admin  # change to viewer for production
```

You can override per model by creating additional files (e.g., `task.yml`) with `model: task`.

## Step 10: Define a Presenter

```ruby
# config/lcp_ruby/presenters/tasks.rb
define_presenter :tasks do
  model :task
  label "Tasks"
  slug "tasks"
  icon "check-square"

  index do
    column :title, link_to: :show
    column :completed, renderer: :boolean_icon
  end

  show do
    section "Details", columns: 2 do
      field :title, renderer: :heading
      field :description
      field :completed, renderer: :boolean_icon
    end
  end

  form do
    section "Details", columns: 2 do
      field :title, placeholder: "Task title...", autofocus: true
      field :completed
    end
    section "Description" do
      field :description, input_type: :textarea
    end
  end

  search do
    searchable_fields :title
    placeholder "Search tasks..."
  end

  action :create, type: :built_in, on: :collection, label: "New Task"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
```

### Presenter Tips

**Tree view** (for tree models):

```ruby
index do
  tree_view true
  default_expanded 2      # levels to expand (or "all")
  reparentable true       # drag-and-drop reparenting

  column :name, link_to: :show
end
```

**Association selects** (for belongs_to FK fields):

```ruby
form do
  section "Details" do
    field :category_id, input_type: :association_select,
      input_options: { sort: { name: :asc }, label_method: :name, include_blank: "Select..." }
  end
end
```

**Tree select** (for hierarchical parent selection):

```ruby
field :parent_id, input_type: :tree_select,
  input_options: { parent_field: :parent_id, label_method: :name, max_depth: 5 }
```

**Association lists** (on show page):

```ruby
show do
  association_list "Items", association: :items, link: true,
    empty_message: "No items."
  includes :items  # eager load
end
```

**Dot-path columns** (display associated model fields):

```ruby
column "company.name", label: "Company"
```

## Step 11: Define View Groups

Each model needs a view group in `config/lcp_ruby/views/`:

```yaml
# config/lcp_ruby/views/tasks.yml
view_group:
  model: task
  primary: tasks
  views:
    - presenter: tasks
      label: "Tasks"
      icon: check-square
```

For tree models, add breadcrumb relation:

```yaml
view_group:
  model: category
  primary: categories
  breadcrumb:
    relation: parent
  views:
    - presenter: categories
      label: "Categories"
      icon: folder
```

## Step 12: Define the Menu

```yaml
# config/lcp_ruby/menu.yml
menu:
  sidebar_menu:
    - label: "My App"
      icon: home
      children:
        - view_group: tasks
        - separator: true
        - view_group: categories
```

## Step 13: Run the App

```bash
bundle exec rails db:prepare  # creates DB + schema + seeds
bundle exec rails s
```

Visit `http://localhost:3000/app/tasks` (or wherever you mounted the engine).

## Groups (Authorization)

To enable DB-backed group authorization:

1. Add group models (use the generator or define manually):

```ruby
# config/lcp_ruby/models/group.rb
define_model :group do
  field :name, :string, limit: 50, null: false, transforms: [:strip] do
    validates :presence
    validates :uniqueness
    validates :format, with: /\A[a-z][a-z0-9_]*\z/
  end
  field :label, :string, limit: 100
  field :description, :text
  field :external_id, :string, limit: 255
  field :source, :enum, values: %w[manual ldap api], default: "manual"
  field :active, :boolean, default: true

  has_many :group_memberships, model: :group_membership, dependent: :destroy
  has_many :group_role_mappings, model: :group_role_mapping, dependent: :destroy

  timestamps true
  label_method :label
end
```

```ruby
# config/lcp_ruby/models/group_membership.rb
define_model :group_membership do
  field :user_id, :integer, null: false do
    validates :presence
    validates :uniqueness, fields: [:group_id, :user_id]
  end
  field :source, :enum, values: %w[manual ldap api], default: "manual"

  belongs_to :group, model: :group, required: true

  timestamps true
  label_method :user_id
end
```

```ruby
# config/lcp_ruby/models/group_role_mapping.rb
define_model :group_role_mapping do
  field :role_name, :string, limit: 50, null: false do
    validates :presence
    validates :uniqueness, fields: [:group_id, :role_name]
  end

  belongs_to :group, model: :group, required: true

  timestamps true
  label_method :role_name
end
```

2. Configure the initializer:

```ruby
config.group_source = :model
config.group_role_mapping_model = "group_role_mapping"
config.role_resolution_strategy = :merged  # :direct_only, :groups_only, or :merged
```

## Seeds

Always call `LcpRuby::Engine.load_metadata!` at the top of `db/seeds.rb`, then access models via the registry:

```ruby
LcpRuby::Engine.load_metadata!

Task = LcpRuby.registry.model_for("task")
Task.create!(title: "First task", completed: false)
```

## Common Patterns

### Enum fields

```ruby
field :status, :enum, values: {
  draft: "Draft",
  active: "Active",
  archived: "Archived"
}, default: "draft"
```

### Scopes

```ruby
scope :active, where: { active: true }
scope :recent, order: { created_at: :desc }, limit: 10
```

### Soft delete

```ruby
define_model :item do
  # ... fields ...
  soft_delete
end
```

### Auditing

```ruby
define_model :item do
  # ... fields ...
  auditing true  # requires an audit model to be defined
end
```
