# Presenter DSL Reference

File: `config/lcp_ruby/presenters/<name>.rb`

The Presenter DSL is a Ruby alternative to [YAML presenter definitions](presenters.md). It produces the same internal representation (`PresenterDefinition`) and feeds through the same pipeline — the DSL builder outputs a hash identical to parsed YAML, which is then processed by `PresenterDefinition.from_hash`.

DSL files live alongside YAML files in `config/lcp_ruby/presenters/`. A project can mix both formats, but each presenter name must be unique across all files (defining the same presenter in both `.yml` and `.rb` raises `MetadataError`).

## Entry Point

```ruby
LcpRuby.define_presenter :presenter_name do
  # DSL calls here
end
```

In DSL files loaded by the engine, use `define_presenter` without the `LcpRuby.` prefix:

```ruby
# config/lcp_ruby/presenters/deal_admin.rb
define_presenter :deal_admin do
  model :deal
  label "Deals"
  slug "deals"
  # ...
end
```

## Presenter Metadata

### `model`

| | |
|---|---|
| **Required** | yes |
| **Type** | symbol or string |

The model this presenter displays. Must match a defined model name.

```ruby
model :deal
```

### `label`

| | |
|---|---|
| **Required** | no |
| **Default** | `name.humanize` |
| **Type** | string |

Human-readable name displayed in page headings and navigation.

```ruby
label "Deals"
```

### `slug`

| | |
|---|---|
| **Required** | no |
| **Type** | string |

URL slug for routing. When set, the presenter is routable at `/admin/<slug>`.

```ruby
slug "deals"
```

### `icon`

| | |
|---|---|
| **Required** | no |
| **Type** | string |

Icon identifier for navigation and UI elements.

```ruby
icon "dollar-sign"
```

### `read_only`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |

Marks the presenter as read-only (no create/edit/destroy actions).

```ruby
read_only true
```

### `embeddable`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |

Whether the presenter can be embedded inside another presenter's view.

```ruby
embeddable true
```

## Index Configuration

The `index` block configures the list/table view.

```ruby
index do
  default_view :table
  views_available :table, :tiles
  default_sort :created_at, :desc
  per_page 25
  column :title, width: "30%", link_to: :show, sortable: true
  column :stage, width: "20%", display: :badge, sortable: true
end
```

### Index Methods

#### `default_view(value)`

Default view mode. Common values: `:table`, `:tiles`.

#### `views_available(*values)`

Available view modes the user can switch between.

```ruby
views_available :table, :tiles
```

#### `default_sort(field, direction)`

Default sort column and direction (`:asc` or `:desc`).

```ruby
default_sort :created_at, :desc
```

#### `per_page(value)`

Number of records per page. Default: 25.

#### `column(field_name, **options)`

Adds a table column.

| Option | Type | Description |
|--------|------|-------------|
| `width:` | string | Column width (e.g., `"30%"`) |
| `link_to:` | symbol | Link target action (e.g., `:show`) |
| `sortable:` | boolean | Whether column is sortable |
| `display:` | symbol | Display format (`:badge`, `:currency`, `:relative_date`, etc.) |

## Show Configuration

The `show` block configures the detail view.

```ruby
show do
  section "Deal Information", columns: 2 do
    field :title, display: :heading
    field :stage, display: :badge
    field :value, display: :currency
  end

  association_list "Contacts", association: :contacts
end
```

### Show Methods

#### `section(title, columns: 1, &block)`

Creates a section with fields. The `columns:` option controls the layout grid.

#### `association_list(title, association:)`

Renders a list of associated records. The `association:` must match a `has_many` association on the model.

```ruby
association_list "Contacts", association: :contacts
association_list "Deals", association: :deals
```

### Section Fields

Inside a `section` block, use `field` to add display fields:

```ruby
field :name, display: :heading
field :status, display: :badge
field :description, display: :rich_text
field :budget, display: :currency
```

| Option | Type | Description |
|--------|------|-------------|
| `display:` | symbol | Display format for the field value |

## Form Configuration

The `form` block configures create and edit forms.

```ruby
form do
  section "Deal Details", columns: 2 do
    field :title, placeholder: "Deal title...", autofocus: true
    field :stage, input_type: :select
    field :value, input_type: :number
    field :company_id, input_type: :association_select
  end
end
```

### Form Methods

#### `section(title, columns: 1, &block)`

Creates a form section. Multiple sections create visual groupings.

### Form Fields

Inside a form `section` block:

```ruby
field :title, placeholder: "Enter title...", autofocus: true
field :stage, input_type: :select
field :budget, input_type: :number, prefix: "$"
field :start_date, input_type: :date_picker
field :company_id, input_type: :association_select
```

| Option | Type | Description |
|--------|------|-------------|
| `input_type:` | symbol | Input widget (`:select`, `:number`, `:text`, `:date_picker`, `:association_select`) |
| `placeholder:` | string | Placeholder text |
| `autofocus:` | boolean | Auto-focus on page load |
| `prefix:` | string | Input prefix (e.g., `"$"`) |

## Search Configuration

The `search` block configures search and filtering.

```ruby
search do
  searchable_fields :title, :description
  placeholder "Search projects..."
  filter :all, label: "All", default: true
  filter :active, label: "Active", scope: :active
  filter :recent, label: "Recent", scope: :recent
end
```

To disable search entirely, use the keyword argument form:

```ruby
search enabled: false
```

### Search Methods

#### `enabled(value)`

Whether search is enabled. Default: `true`.

#### `searchable_fields(*fields)`

Fields to search against when the user types a query.

```ruby
searchable_fields :title, :description, :email
```

#### `placeholder(value)`

Placeholder text for the search input.

#### `filter(name, label:, default: false, scope: nil)`

Adds a predefined filter tab.

| Argument | Type | Description |
|----------|------|-------------|
| `name` | symbol | Filter identifier |
| `label:` | string | Display text |
| `default:` | boolean | Whether this filter is selected by default |
| `scope:` | symbol | Model scope to apply (must be defined in the model) |

## Actions

Actions are defined at the top level of the presenter (not inside a block).

```ruby
action :create, type: :built_in, on: :collection, label: "New Deal", icon: "plus"
action :show,   type: :built_in, on: :single, icon: "eye"
action :edit,   type: :built_in, on: :single, icon: "pencil"
action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
```

### Action Arguments

| Argument | Required | Type | Description |
|----------|----------|------|-------------|
| `name` | yes | symbol | Action identifier |
| `type:` | yes | symbol | `:built_in` or `:custom` |
| `on:` | yes | symbol | `:collection`, `:single`, or `:batch` |

### Action Options

| Option | Type | Description |
|--------|------|-------------|
| `label:` | string | Button/link text |
| `icon:` | string | Icon identifier |
| `confirm:` | boolean | Show confirmation dialog |
| `confirm_message:` | string | Custom confirmation message |
| `style:` | symbol | Visual style (e.g., `:danger`) |
| `visible_when:` | hash | Condition for visibility (see below) |

### `visible_when` Conditions

Custom actions can be conditionally visible based on record field values:

```ruby
action :close_won, type: :custom, on: :single,
  label: "Close as Won", icon: "check-circle",
  confirm: true, confirm_message: "Mark this deal as won?",
  visible_when: { field: :stage, operator: :not_in, value: [:closed_won, :closed_lost] }
```

See [Condition Operators](condition-operators.md) for available operators.

## Navigation

```ruby
navigation menu: :main, position: 3
```

| Option | Type | Description |
|--------|------|-------------|
| `menu:` | symbol | Menu group (e.g., `:main`, `:public`) |
| `position:` | integer | Sort order within the menu (optional) |

## Inheritance

Presenters can inherit from other presenters using the `inherits:` option. This copies the parent's configuration and lets the child override specific sections.

```ruby
# config/lcp_ruby/presenters/deal_pipeline.rb
define_presenter :deal_pipeline, inherits: :deal_admin do
  label "Deal Pipeline"
  slug "pipeline"
  icon "bar-chart"
  read_only true

  index do
    default_view :table
    per_page 50
    column :title, link_to: :show, sortable: true
    column :stage, display: :badge, sortable: true
  end

  search enabled: false

  action :show, type: :built_in, on: :single, icon: "eye"

  navigation menu: :main, position: 4
end
```

### Inheritance Semantics

- **Section-level replace**: If a child defines `index`, `show`, `form`, `search`, `actions`, or `navigation`, the child's version completely replaces the parent's. There is no deep merge.
- **Unset sections are inherited**: If the child does not define a section, the parent's version is used as-is.
- **Top-level attributes**: `name`, `label`, `slug`, `icon`, `read_only`, `embeddable` are always taken from the child when defined. The `model` is inherited from the parent unless the child overrides it.
- **Parent must exist**: The parent presenter must be defined in a DSL file in the same directory. Referencing a nonexistent parent raises `MetadataError`.
- **No circular inheritance**: Circular chains (A inherits B, B inherits A) are detected and raise `MetadataError`.

Inheritance is purely a DSL convenience — the result is always a flat hash identical to what you could write in YAML with full duplication.

## DSL vs YAML Equivalence

| DSL | YAML Equivalent |
|-----|----------------|
| `model :deal` | `model: deal` |
| `label "Deals"` | `label: "Deals"` |
| `slug "deals"` | `slug: deals` |
| `read_only true` | `read_only: true` |
| `index do ... end` | `index: { ... }` |
| `column :title, sortable: true` | `table_columns: [{ field: title, sortable: true }]` |
| `show do section "Info" do ... end end` | `show: { layout: [{ section: "Info", ... }] }` |
| `association_list "X", association: :y` | `{ section: "X", type: association_list, association: y }` |
| `form do section "Details" do ... end end` | `form: { sections: [{ title: "Details", ... }] }` |
| `search do ... end` | `search: { ... }` |
| `search enabled: false` | `search: { enabled: false }` |
| `action :show, type: :built_in, on: :single` | `actions: { single: [{ name: show, type: built_in }] }` |
| `navigation menu: :main, position: 1` | `navigation: { menu: main, position: 1 }` |

For the full YAML attribute reference, see [Presenters Reference](presenters.md).

## Complete Example

A deal management presenter demonstrating all DSL features:

```ruby
# config/lcp_ruby/presenters/deal_admin.rb
define_presenter :deal_admin do
  model :deal
  label "Deals"
  slug "deals"
  icon "dollar-sign"

  index do
    default_view :table
    default_sort :created_at, :desc
    per_page 25
    column :title, width: "30%", link_to: :show, sortable: true
    column :stage, width: "20%", display: :badge, sortable: true
    column :value, width: "20%", display: :currency, sortable: true
  end

  show do
    section "Deal Information", columns: 2 do
      field :title, display: :heading
      field :stage, display: :badge
      field :value, display: :currency
    end
  end

  form do
    section "Deal Details", columns: 2 do
      field :title, placeholder: "Deal title...", autofocus: true
      field :stage, input_type: :select
      field :value, input_type: :number
      field :company_id, input_type: :association_select
      field :contact_id, input_type: :association_select
    end
  end

  search do
    searchable_fields :title
    placeholder "Search deals..."
    filter :all, label: "All", default: true
    filter :open, label: "Open", scope: :open_deals
    filter :won, label: "Won", scope: :won
    filter :lost, label: "Lost", scope: :lost
  end

  action :create, type: :built_in, on: :collection, label: "New Deal", icon: "plus"
  action :show,   type: :built_in, on: :single, icon: "eye"
  action :edit,   type: :built_in, on: :single, icon: "pencil"
  action :close_won, type: :custom, on: :single,
    label: "Close as Won", icon: "check-circle",
    confirm: true, confirm_message: "Mark this deal as won?",
    visible_when: { field: :stage, operator: :not_in, value: [:closed_won, :closed_lost] }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger

  navigation menu: :main, position: 3
end
```

Source: `lib/lcp_ruby/dsl/presenter_builder.rb`, `lib/lcp_ruby/dsl/dsl_loader.rb`
