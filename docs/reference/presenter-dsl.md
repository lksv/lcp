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
# config/lcp_ruby/presenters/deal.rb
define_presenter :deal do
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

URL slug for routing. When set, the presenter is routable at `/<slug>`.

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

#### `row_click(value)`

Sets the behavior when a user clicks a table row.

```ruby
row_click :show   # clicking a row navigates to the show page
```

#### `empty_message(value)`

Message displayed when the index table has no records.

```ruby
empty_message "No deals found. Create your first deal to get started."
```

#### `actions_position(value)`

Controls how row-level actions are displayed.

| Value | Description |
|-------|-------------|
| `:inline` | Actions are rendered as inline buttons (default) |
| `:dropdown` | Actions appear in a dropdown menu |

```ruby
actions_position :dropdown
```

#### `includes(*associations)`

Manually specify associations to preload for display. See [Eager Loading](eager-loading.md).

```ruby
index do
  includes :company, :contact
end
```

#### `eager_load(*associations)`

Manually specify associations to eager load via LEFT JOIN. See [Eager Loading](eager-loading.md).

```ruby
index do
  eager_load :company
end
```

#### `column(field_name, **options)`

Adds a table column.

| Option | Type | Description |
|--------|------|-------------|
| `width:` | string | Column width (e.g., `"30%"`) |
| `label:` | string | Custom column header label (e.g., `"Company"` for a `"company.name"` dot-path field) |
| `link_to:` | symbol | Link target action (e.g., `:show`) |
| `sortable:` | boolean | Whether column is sortable |
| `display:` | symbol | Display format (`:badge`, `:currency`, `:relative_date`, etc.) |
| `display_options:` | hash | Additional display configuration (e.g., `{ color_map: { ... } }`) |
| `hidden_on:` | symbol or array | Responsive breakpoints to hide the column on (e.g., `:mobile`, `[:mobile, :tablet]`) |
| `pinned:` | symbol | Pin the column to `:left` or `:right` side of the table |
| `summary:` | symbol | Summary function for the column footer (e.g., `:sum`, `:avg`, `:count`) |

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

#### `includes(*associations)` / `eager_load(*associations)`

Same as index. Manually specify associations to preload for the show page. Auto-detection handles `association_list` sections automatically. See [Eager Loading](eager-loading.md).

#### `section(title, columns: 1, responsive: nil, &block)`

Creates a section with fields. The `columns:` option controls the layout grid. The `responsive:` option controls how the section adapts to different screen sizes.

```ruby
show do
  section "Deal Information", columns: 2, responsive: { mobile: 1 } do
    field :title, display: :heading
    field :stage, display: :badge
  end
end
```

#### `association_list(title, association:, display: nil, link: nil, sort: nil, limit: nil, empty_message: nil, scope: nil)`

Renders a list of associated records with optional display templates, links, sorting, and limits. The `association:` must match a `has_many` association on the model.

| Option | Type | Description |
|--------|------|-------------|
| `association:` | symbol | The `has_many` association name (required) |
| `display:` | symbol or string | Name of the display template defined on the target model (e.g., `:default`) |
| `link:` | boolean | Wrap each record in a link to its show page |
| `sort:` | hash | Sort associated records by field and direction (e.g., `{ last_name: :asc }`) |
| `limit:` | integer | Maximum number of records to display |
| `empty_message:` | string | Message shown when there are no associated records |
| `scope:` | symbol | Named scope to apply on the association before rendering |

```ruby
# Basic
association_list "Deals", association: :deals

# With all options
association_list "Contacts", association: :contacts,
  display: :default, link: true,
  sort: { last_name: :asc }, limit: 10,
  empty_message: "No contacts yet.",
  scope: :active
```

When `display:` references a display template defined on the target model (see [Models Reference — Display Templates](models.md#display-templates)), each record is rendered with the template's structured layout (title, subtitle, icon, badge). Without `display:`, records fall back to plain `to_label` text.

### Section Fields (Show)

Inside a show `section` block, use `field` to add display fields:

```ruby
field :name, display: :heading
field :status, display: :badge
field :description, display: :rich_text
field :budget, display: :currency
```

| Option | Type | Description |
|--------|------|-------------|
| `display:` | symbol | Display format for the field value |
| `label:` | string | Custom field label (e.g., `"Company"` for a `"company.name"` dot-path field) |
| `col_span:` | integer | Number of grid columns this field spans |
| `hidden_on:` | symbol or array | Responsive breakpoints to hide the field on |
| `display_options:` | hash | Additional display configuration |

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

#### `includes(*associations)` / `eager_load(*associations)`

Same as index. Manually specify associations to preload for the form. Auto-detection handles `nested_fields` sections automatically. See [Eager Loading](eager-loading.md).

#### `layout(value)`

Sets the overall form layout mode.

| Value | Description |
|-------|-------------|
| `:flat` | All sections rendered sequentially (default) |
| `:tabs` | Each section rendered as a tab |

```ruby
form do
  layout :tabs

  section "Basic Info" do
    field :title
  end

  section "Details" do
    field :description
  end
end
```

#### `section(title, columns: 1, collapsible: false, collapsed: false, responsive: nil, visible_when: nil, disable_when: nil, &block)`

Creates a form section. Multiple sections create visual groupings.

| Option | Type | Description |
|--------|------|-------------|
| `columns:` | integer | Number of layout columns (default: 1) |
| `collapsible:` | boolean | Whether the section can be collapsed/expanded by the user |
| `collapsed:` | boolean | Whether the section starts in collapsed state (requires `collapsible: true`) |
| `responsive:` | hash | Responsive column overrides (e.g., `{ mobile: 1 }`) |
| `visible_when:` | hash | Condition hash for section visibility |
| `disable_when:` | hash | Condition hash for section disabling |

```ruby
form do
  section "Primary", columns: 2, responsive: { mobile: 1 } do
    field :title
    field :stage, input_type: :select
  end

  section "Notes", collapsible: true, collapsed: true do
    field :description, input_type: :textarea
  end
end
```

#### `nested_fields(title, association:, **options, &block)`

Adds a nested form section for creating and editing associated records inline within the parent form. The target association must have `nested_attributes` configured in the model definition.

| Option | Type | Description |
|--------|------|-------------|
| `association:` | symbol | The `has_many` or `has_one` association name (required) |
| `allow_add:` | boolean | Show an "Add" button for creating new nested records (default: `true`) |
| `allow_remove:` | boolean | Show a "Remove" button on each nested record (default: `true`) |
| `min:` | integer | Minimum number of nested records |
| `max:` | integer | Maximum number of nested records |
| `add_label:` | string | Custom label for the "Add" button |
| `empty_message:` | string | Message shown when there are no nested records |
| `columns:` | integer | Number of layout columns for each nested record row |
| `sortable:` | boolean or string | Enable drag-and-drop reordering. `true` uses `position` field, or pass a string for a custom field name |
| `visible_when:` | hash | Condition hash for nested section visibility |
| `disable_when:` | hash | Condition hash for nested section disabling |

Inside the `nested_fields` block, use `field` calls to define which fields of the associated model to display.

```ruby
form do
  section "List Details" do
    field :name
  end

  nested_fields "Items", association: :todo_items,
    allow_add: true, allow_remove: true,
    max: 50, add_label: "Add Item",
    empty_message: "No items yet.", columns: 2 do
      field :title, placeholder: "Item title..."
      field :completed, input_type: :checkbox
      field :due_date, input_type: :date_picker
  end
end
```

**With sortable (drag-and-drop reordering):**

```ruby
nested_fields "Items", association: :todo_items,
  sortable: true, add_label: "Add Item" do
    field :title
    field :completed, input_type: :checkbox
end
```

Set `sortable: true` to use the default `position` field, or `sortable: "sort_order"` for a custom field name. The position field is hidden from the visible form and auto-permitted in the controller.

### Form Fields (Section Builder)

Inside a form `section` or `nested_fields` block:

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
| `suffix:` | string | Input suffix (e.g., `"kg"`) |
| `col_span:` | integer | Number of grid columns this field spans (e.g., `2` for a full-width field in a 2-column section) |
| `hint:` | string | Help text displayed below the input |
| `readonly:` | boolean | Render the field as read-only |
| `visible_when:` | hash | Condition hash for conditional visibility. Field-value: `{ field: :status, operator: :eq, value: "active" }`. Service: `{ service: :persisted_check }`. See [Conditional Rendering](../guides/conditional-rendering.md). |
| `disable_when:` | hash | Condition hash for conditional disabling. Same syntax as `visible_when`. When condition is true, field is visually disabled but values are still submitted. |
| `default:` | any | Default value for the form input (overrides the model-level default for this form) |
| `input_options:` | hash | Additional options passed to the input widget (see below) |
| `display_options:` | hash | Display configuration (e.g., formatting) |
| `hidden_on:` | symbol or array | Responsive breakpoints to hide the field on |

#### `input_options` for Select Fields

**Enum select** — role-based value filtering:

```ruby
field :stage, input_type: :select,
  input_options: {
    include_blank: false,
    exclude_values: { viewer: ["lead"] },
    include_values: { intern: ["active", "inactive"] }
  }
```

**Association select** — scope, sort, label, grouping:

```ruby
field :company_id, input_type: :association_select,
  input_options: {
    scope: :active,
    sort: { name: :asc },
    label_method: :full_name,
    include_blank: "-- Choose company --",
    group_by: :industry
  }
```

**Dependent (cascading) select** — child select filtered by parent:

```ruby
field :company_id, input_type: :association_select,
  input_options: { sort: { name: :asc } }

field :contact_id, input_type: :association_select,
  input_options: {
    depends_on: { field: :company_id, foreign_key: :company_id },
    sort: { last_name: :asc },
    label_method: :full_name
  }
```

**Role-based scope** — different scopes per user role:

```ruby
field :company_id, input_type: :association_select,
  input_options: {
    scope_by_role: { admin: :all, editor: :active_companies, viewer: :my_companies }
  }
```

**Multi select** — for `has_many :through` associations:

```ruby
field :tag_ids, input_type: :multi_select,
  input_options: { association: :tags, sort: { name: :asc }, max: 5 }
```

For the complete list of `input_options` keys per input type, see [Presenters Reference — Input Options](presenters.md#input-options).

#### `divider(label: nil)`

Adds a horizontal divider pseudo-field inside a section. Useful for visually separating groups of related fields.

```ruby
form do
  section "Contact Details", columns: 2 do
    field :first_name
    field :last_name
    divider label: "Address"
    field :street, col_span: 2
    field :city
    field :zip_code
  end
end
```

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
| `disable_when:` | hash | Condition for disabling the action (see [Conditional Rendering](../guides/conditional-rendering.md)) |

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
define_presenter :deal_pipeline, inherits: :deal do
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

## Advanced Field Paths

### Dot-Notation (Association Traversal)

Use string field names with dot-notation to traverse associations:

```ruby
index do
  column "company.name", sortable: true            # belongs_to
  column "company.industry", display: :badge        # with display type
  column "contacts.full_name", display: :collection # has_many
end

show do
  section "Details" do
    field "company.name"
    field "company.industry", display: :badge
    field "contacts.full_name", display: :collection,
      display_options: { limit: 5, separator: " | " }
  end
end
```

### Template Syntax

Use `{field}` syntax in string field names:

```ruby
index do
  column "{first_name} {last_name}"
  column "{company.name}: {title}"
end
```

### Collection Display

The `collection` display type renders arrays from has_many dot-paths:

```ruby
index do
  column "contacts.full_name", display: :collection,
    display_options: { limit: 3, overflow: "...", separator: ", " }
end
```

### Custom Renderers

Reference custom renderers (from `app/renderers/`) by name:

```ruby
index do
  column :stage, display: :conditional_badge,
    display_options: { rules: [...] }
end
```

## DSL vs YAML Equivalence

| DSL | YAML Equivalent |
|-----|----------------|
| `model :deal` | `model: deal` |
| `label "Deals"` | `label: "Deals"` |
| `slug "deals"` | `slug: deals` |
| `read_only true` | `read_only: true` |
| `index do ... end` | `index: { ... }` |
| `includes :company` | `index: { includes: [company] }` |
| `eager_load :company` | `index: { eager_load: [company] }` |
| `column :title, sortable: true` | `table_columns: [{ field: title, sortable: true }]` |
| `row_click :show` | `index: { row_click: show }` |
| `empty_message "No records."` | `index: { empty_message: "No records." }` |
| `actions_position :inline` | `index: { actions_position: inline }` |
| `show do section "Info", responsive: {...} do ... end end` | `show: { layout: [{ section: "Info", responsive: {...}, ... }] }` |
| `association_list "X", association: :y` | `{ section: "X", type: association_list, association: y }` |
| `association_list "X", association: :y, display: :default, link: true, sort: { name: :asc }, limit: 5, empty_message: "None.", scope: :active` | `{ section: "X", type: association_list, association: y, display: default, link: true, sort: { name: asc }, limit: 5, empty_message: "None.", scope: active }` |
| `form do layout :tabs end` | `form: { layout: tabs }` |
| `form do section "Details", collapsible: true do ... end end` | `form: { sections: [{ title: "Details", collapsible: true, ... }] }` |
| `nested_fields "Items", association: :items do ... end` | `form: { sections: [{ type: nested_fields, title: "Items", association: items, ... }] }` |
| `divider label: "Address"` | `fields: [{ type: divider, label: "Address" }]` |
| `field :x, col_span: 2, hint: "Help"` | `fields: [{ field: x, col_span: 2, hint: "Help" }]` |
| `field :x, visible_when: { field: :status, operator: :eq, value: "active" }` | `fields: [{ field: x, visible_when: { field: status, operator: eq, value: active } }]` |
| `field :x, disable_when: { field: :status, operator: :blank }` | `fields: [{ field: x, disable_when: { field: status, operator: blank } }]` |
| `search do ... end` | `search: { ... }` |
| `search enabled: false` | `search: { enabled: false }` |
| `action :show, type: :built_in, on: :single` | `actions: { single: [{ name: show, type: built_in }] }` |
| `navigation menu: :main, position: 1` | `navigation: { menu: main, position: 1 }` |

For the full YAML attribute reference, see [Presenters Reference](presenters.md).

## Complete Example

A deal management presenter demonstrating all DSL features:

```ruby
# config/lcp_ruby/presenters/deal.rb
define_presenter :deal do
  model :deal
  label "Deals"
  slug "deals"
  icon "dollar-sign"

  index do
    default_view :table
    default_sort :created_at, :desc
    per_page 25
    row_click :show
    empty_message "No deals yet. Create your first deal to get started."
    actions_position :dropdown
    column :title, width: "30%", link_to: :show, sortable: true, pinned: :left
    column :stage, width: "20%", display: :badge, sortable: true,
      display_options: { color_map: { lead: "blue", closed_won: "green", closed_lost: "red" } }
    column :value, width: "20%", display: :currency, sortable: true,
      summary: :sum, hidden_on: :mobile
  end

  show do
    section "Deal Information", columns: 2, responsive: { mobile: 1 } do
      field :title, display: :heading, col_span: 2
      field :stage, display: :badge
      field :value, display: :currency
    end
  end

  form do
    layout :tabs

    section "Deal Details", columns: 2, responsive: { mobile: 1 } do
      field :title, placeholder: "Deal title...", autofocus: true,
        hint: "A short descriptive name for the deal"
      field :stage, input_type: :select
      field :value, input_type: :number, prefix: "$", col_span: 1
      field :company_id, input_type: :association_select
      field :contact_id, input_type: :association_select
    end

    section "Additional Info", collapsible: true, collapsed: true do
      field :description, input_type: :textarea, col_span: 2
      divider label: "Internal"
      field :notes, input_type: :textarea, readonly: true,
        visible_when: { field: :stage, operator: :not_eq, value: "lead" }
    end

    nested_fields "Line Items", association: :line_items,
      allow_add: true, allow_remove: true,
      max: 20, add_label: "Add Line Item",
      empty_message: "No line items.", columns: 3 do
        field :product_name, placeholder: "Product..."
        field :quantity, input_type: :number, default: 1
        field :unit_price, input_type: :number, prefix: "$"
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
