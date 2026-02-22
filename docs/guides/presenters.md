# Presenters Guide

Presenters define the UI layer of your LCP Ruby application: how records are listed, displayed, edited, searched, and what actions are available. A single model can have multiple presenters -- for example, one for full administration and another for a read-only pipeline view.

This guide walks through building presenters step-by-step, from a minimal setup to advanced features. Every example is shown in both YAML and Ruby DSL.

For the full attribute reference, see the [Presenters Reference](../reference/presenters.md) and the [Presenter DSL Reference](../reference/presenter-dsl.md).

## File Locations

Presenter files live in `config/lcp_ruby/presenters/`:

```
config/lcp_ruby/presenters/
  todo_list.yml        # YAML format
  deal.rb              # Ruby DSL format
  contact.yml
```

Both formats produce the same internal representation. A project can mix `.yml` and `.rb` files, but each presenter name must be unique across all files.

---

## Your First Presenter

A minimal presenter needs a `name`, a `model`, a `slug` (for URL routing), and at least an index configuration to list records.

**YAML:**

```yaml
# config/lcp_ruby/presenters/todo_list.yml
presenter:
  name: todo_list
  model: todo_list
  label: "Todo Lists"
  slug: todo-lists
  icon: check-square

  index:
    table_columns:
      - { field: name, link_to: show, sortable: true }
      - { field: created_at, renderer: relative_date }

  show:
    layout:
      - section: "Details"
        fields:
          - { field: name, renderer: heading }
          - { field: created_at, renderer: datetime }

  form:
    sections:
      - title: "Todo List"
        fields:
          - { field: name, placeholder: "List name...", autofocus: true }

  actions:
    collection:
      - { name: create, type: built_in, label: "New List", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

**Ruby DSL:**

```ruby
# config/lcp_ruby/presenters/todo_list.rb
define_presenter :todo_list do
  model :todo_list
  label "Todo Lists"
  slug "todo-lists"
  icon "check-square"

  index do
    column :name, link_to: :show, sortable: true
    column :created_at, renderer: :relative_date
  end

  show do
    section "Details" do
      field :name, renderer: :heading
      field :created_at, renderer: :datetime
    end
  end

  form do
    section "Todo List" do
      field :name, placeholder: "List name...", autofocus: true
    end
  end

  action :create, type: :built_in, on: :collection, label: "New List", icon: "plus"
  action :show,   type: :built_in, on: :single, icon: "eye"
  action :edit,   type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
```

With this in place, navigating to `/todo-lists` renders a paginated table. Each record has show, edit, and destroy buttons.

---

## Index Configuration

The index controls the record list view: which columns appear, how they sort, pagination, and visual formatting.

### Columns, Sorting, and Pagination

**YAML:**

```yaml
index:
  default_sort: { field: created_at, direction: desc }
  per_page: 20
  row_click: show
  table_columns:
    - field: name
      width: "30%"
      link_to: show
      sortable: true
    - field: email
      width: "25%"
      renderer: email_link
      sortable: true
    - field: status
      width: "15%"
      renderer: badge
      options:
        color_map:
          active: green
          inactive: gray
      sortable: true
    - field: revenue
      width: "15%"
      renderer: currency
      options:
        currency: "$"
        precision: 2
      sortable: true
      summary: sum
    - { field: updated_at, renderer: relative_date }
```

**Ruby DSL:**

```ruby
index do
  default_sort :created_at, :desc
  per_page 20
  row_click :show

  column :name, width: "30%", link_to: :show, sortable: true
  column :email, width: "25%", renderer: :email_link, sortable: true
  column :status, width: "15%", renderer: :badge, sortable: true,
    options: { color_map: { active: "green", inactive: "gray" } }
  column :revenue, width: "15%", renderer: :currency, sortable: true, summary: :sum,
    options: { currency: "$", precision: 2 }
  column :updated_at, renderer: :relative_date
end
```

Key options:

| Option | Description |
|--------|-------------|
| `default_sort` | Default column and direction for ordering |
| `per_page` | Records per page (Kaminari pagination) |
| `row_click: show` | Makes the entire table row clickable |
| `link_to: show` | Makes a specific column's cell a link to the show page |
| `sortable` | Enables column-header sort toggle |
| `renderer` | Visual renderer for the cell value (see [Renderers Guide](display-types.md)) |
| `summary` | Adds a footer row with `sum`, `avg`, or `count` |

### Empty State and Actions Position

**YAML:**

```yaml
index:
  empty_message: "No contacts found. Create your first contact to get started."
  actions_position: dropdown
```

**Ruby DSL:**

```ruby
index do
  empty_message "No contacts found. Create your first contact to get started."
  actions_position :dropdown
end
```

`actions_position: dropdown` groups all single-record actions into a dropdown menu instead of rendering them as inline buttons. This is useful when you have many actions per row.

### Responsive Columns and Pinning

Hide columns on small screens and pin important columns to stay visible during horizontal scroll.

**YAML:**

```yaml
table_columns:
  - field: name
    pinned: left
    sortable: true
  - field: email
    hidden_on: [mobile, tablet]
  - field: phone
    hidden_on: mobile
  - field: status
    renderer: badge
```

**Ruby DSL:**

```ruby
index do
  column :name, pinned: :left, sortable: true
  column :email, hidden_on: [:mobile, :tablet]
  column :phone, hidden_on: :mobile
  column :status, renderer: :badge
end
```

### Reorderable Index (Record Positioning)

For models with [`positioning`](../reference/models.md#positioning), you can enable drag-and-drop reordering:

**YAML:**

```yaml
index:
  reorderable: true
  table_columns:
    - { field: name, link_to: show }
    - { field: position, sortable: true }
```

**DSL:**

```ruby
index do
  reorderable true
  column :name, link_to: :show
  column :position, sortable: true
end
```

When `reorderable: true`:
- Drag handles appear as the first column
- Records are sorted by position by default (no need for explicit `default_sort`)
- The frontend sends `PATCH /:slug/:id/reorder` requests with relative positioning (`{ after: id }` or `{ before: id }`)
- Handles are automatically disabled when a search query is active or when sorting by a non-position column
- Reordering requires `update` CRUD permission and the position field in writable fields

The position column is optional in `table_columns` — drag-and-drop works regardless. Include it when users want to see the numeric order.

See [Record Positioning](../design/record_positioning.md) for the full design, including scoped positioning, concurrent edit detection, and permission patterns.

---

## Show Configuration

The show view displays a single record's details organized into sections.

### Sections and Fields

**YAML:**

```yaml
show:
  layout:
    - section: "Contact Details"
      columns: 2
      fields:
        - { field: name, renderer: heading, col_span: 2 }
        - { field: email, renderer: email_link }
        - { field: phone, renderer: phone_link }
        - field: status
          renderer: badge
          options:
            color_map:
              active: green
              inactive: gray
    - section: "Notes"
      fields:
        - { field: notes, renderer: rich_text }
```

**Ruby DSL:**

```ruby
show do
  section "Contact Details", columns: 2 do
    field :name, renderer: :heading, col_span: 2
    field :email, renderer: :email_link
    field :phone, renderer: :phone_link
    field :status, renderer: :badge,
      options: { color_map: { active: "green", inactive: "gray" } }
  end

  section "Notes" do
    field :notes, renderer: :rich_text
  end
end
```

Use `columns` to control the grid layout and `col_span` to make a field stretch across multiple columns.

### Responsive Sections

Override the column count at different breakpoints so the layout adapts to smaller screens.

**YAML:**

```yaml
show:
  layout:
    - section: "Deal Overview"
      columns: 3
      responsive:
        tablet:
          columns: 2
        mobile:
          columns: 1
      fields:
        - { field: title, renderer: heading, col_span: 3 }
        - { field: stage, renderer: badge }
        - { field: value, renderer: currency }
        - { field: close_date, renderer: date }
```

**Ruby DSL:**

```ruby
show do
  section "Deal Overview", columns: 3, responsive: { tablet: 2, mobile: 1 } do
    field :title, renderer: :heading, col_span: 3
    field :stage, renderer: :badge
    field :value, renderer: :currency
    field :close_date, renderer: :date
  end
end
```

### Association Lists

Display related records as a list within the show page using `type: association_list`. Records can render with rich display templates (title, subtitle, icon, badge), links, sorting, and limits.

**YAML:**

```yaml
show:
  layout:
    - section: "Company Info"
      fields:
        - { field: name, renderer: heading }
    - section: "Contacts"
      type: association_list
      association: contacts
      display_template: default    # Uses display template from contact model
      link: true                   # Wrap each record in a link to its show page
      sort: { last_name: asc }
      limit: 10
      empty_message: "No contacts yet."
    - section: "Deals"
      type: association_list
      association: deals
```

**Ruby DSL:**

```ruby
show do
  section "Company Info" do
    field :name, renderer: :heading
  end

  association_list "Contacts", association: :contacts,
    display_template: :default, link: true,
    sort: { last_name: :asc }, limit: 10,
    empty_message: "No contacts yet."
  association_list "Deals", association: :deals
end
```

The association must be defined as `has_many` in the model.

**Display templates** are defined on the target model (see [Models Reference](../reference/models.md#display-templates)). For example, the contact model might define:

**YAML:**

```yaml
display_templates:
  default:
    template: "{first_name} {last_name}"
    subtitle: "{position} at {company.name}"
    icon: user
```

**Ruby DSL:**

```ruby
define_model :contact do
  # ... fields, associations ...

  display_template :default,
    template: "{first_name} {last_name}",
    subtitle: "{position} at {company.name}",
    icon: "user"
end
```

This renders each contact with a structured layout showing the name, position, and company. Without a display template, records fall back to plain `to_label` text.

Options reference: `display`, `link`, `sort`, `limit`, `empty_message`, `scope` — see [Presenters Reference](../reference/presenters.md#association-list-sections).

---

## Form Configuration

Forms control how records are created and edited. You define one or more sections, each containing fields.

### Basic Form

**YAML:**

```yaml
form:
  sections:
    - title: "Contact Information"
      columns: 2
      fields:
        - { field: first_name, placeholder: "First name...", autofocus: true }
        - { field: last_name, placeholder: "Last name..." }
        - { field: email, placeholder: "email@example.com" }
        - { field: phone }
```

**Ruby DSL:**

```ruby
form do
  section "Contact Information", columns: 2 do
    field :first_name, placeholder: "First name...", autofocus: true
    field :last_name, placeholder: "Last name..."
    field :email, placeholder: "email@example.com"
    field :phone
  end
end
```

### Flat vs Tabs Layout

By default, sections render as stacked cards (`flat` layout). Set `layout: tabs` to render each section as a tab.

**YAML:**

```yaml
form:
  layout: tabs
  sections:
    - title: "General"
      fields:
        - { field: title }
        - { field: description, input_type: textarea }
    - title: "Pricing"
      fields:
        - { field: price, input_type: number, prefix: "$" }
        - { field: currency, input_type: select }
    - title: "Advanced"
      fields:
        - { field: notes, input_type: rich_text_editor }
```

**Ruby DSL:**

```ruby
form do
  layout :tabs

  section "General" do
    field :title
    field :description, input_type: :textarea
  end

  section "Pricing" do
    field :price, input_type: :number, prefix: "$"
    field :currency, input_type: :select
  end

  section "Advanced" do
    field :notes, input_type: :rich_text_editor
  end
end
```

### Input Types

LCP Ruby picks a default input type based on the field's model type, but you can override it.

| Input Type | Renders | Default For |
|------------|---------|-------------|
| `text` | Single-line text input | `string` fields |
| `textarea` | Multi-line text area | `text` fields |
| `select` | Dropdown (from `enum_values`) | `enum` fields |
| `number` | Numeric input | `integer`, `float`, `decimal` |
| `date` / `date_picker` | Date picker | `date` fields |
| `datetime` | Datetime picker | `datetime` fields |
| `boolean` | Checkbox | `boolean` fields |
| `association_select` | Dropdown from associated model | FK fields |
| `rich_text_editor` | Rich text editor | `rich_text` fields |
| `slider` | Range slider | - |
| `toggle` | Toggle switch | - |
| `rating` | Star rating input | - |

### Field Options

Fields support prefix, suffix, hints, placeholders, and input-specific options.

**YAML:**

```yaml
fields:
  - field: title
    placeholder: "Enter title..."
    autofocus: true
    col_span: 2
    hint: "A short, descriptive name"
  - field: price
    input_type: number
    prefix: "$"
    suffix: "USD"
    input_options:
      min: 0
      step: 0.01
  - field: description
    input_type: textarea
    input_options:
      rows: 6
      max_length: 500
      show_counter: true
  - field: priority
    input_type: slider
    input_options:
      min: 1
      max: 10
      step: 1
      show_value: true
  - field: internal_code
    readonly: true
    hint: "Auto-generated, cannot be changed"
```

**Ruby DSL:**

```ruby
form do
  section "Details", columns: 2 do
    field :title, placeholder: "Enter title...", autofocus: true,
      col_span: 2, hint: "A short, descriptive name"
    field :price, input_type: :number, prefix: "$", suffix: "USD",
      input_options: { min: 0, step: 0.01 }
    field :description, input_type: :textarea,
      input_options: { rows: 6, max_length: 500, show_counter: true }
    field :priority, input_type: :slider,
      input_options: { min: 1, max: 10, step: 1, show_value: true }
    field :internal_code, readonly: true, hint: "Auto-generated, cannot be changed"
  end
end
```

### Dynamic Defaults

Set default values that are resolved at form render time.

**YAML:**

```yaml
fields:
  - { field: start_date, input_type: date, default: current_date }
  - { field: assigned_to_id, input_type: association_select, default: current_user_id }
```

**Ruby DSL:**

```ruby
field :start_date, input_type: :date, default: "current_date"
field :assigned_to_id, input_type: :association_select, default: "current_user_id"
```

| Value | Description |
|-------|-------------|
| `current_date` | Today's date |
| `current_user_id` | The current user's ID |

### Dividers

Use dividers to visually separate groups of fields within a section.

**YAML:**

```yaml
fields:
  - { field: first_name }
  - { field: last_name }
  - { type: divider, label: "Contact Information" }
  - { field: email }
  - { field: phone }
  - { type: divider }
  - { field: notes, input_type: textarea }
```

**Ruby DSL:**

```ruby
section "Contact Details", columns: 2 do
  field :first_name
  field :last_name
  divider label: "Contact Information"
  field :email
  field :phone
  divider
  field :notes, input_type: :textarea
end
```

A divider with a `label` renders a labeled horizontal rule. Without a label, it renders a plain separator line.

### Association Selects

Foreign key fields can render as dropdowns populated from the associated model's records.

**YAML:**

```yaml
fields:
  - { field: company_id, input_type: association_select }
  - { field: contact_id, input_type: association_select }
```

**Ruby DSL:**

```ruby
field :company_id, input_type: :association_select
field :contact_id, input_type: :association_select
```

The dropdown display text uses `to_label` (if defined on the target model) or `to_s`. The target model must be registered in the LCP registry.

### Collapsible Sections

Sections can be collapsible, optionally starting collapsed. This is useful for "Advanced" or rarely-edited fields.

**YAML:**

```yaml
form:
  sections:
    - title: "Basic Information"
      columns: 2
      fields:
        - { field: name }
        - { field: email }
    - title: "Advanced Options"
      collapsible: true
      collapsed: true
      fields:
        - { field: api_key }
        - { field: webhook_url }
```

**Ruby DSL:**

```ruby
form do
  section "Basic Information", columns: 2 do
    field :name
    field :email
  end

  section "Advanced Options", collapsible: true, collapsed: true do
    field :api_key
    field :webhook_url
  end
end
```

### Responsive Form Sections

Override the column count at different breakpoints.

**YAML:**

```yaml
form:
  sections:
    - title: "Contact Details"
      columns: 3
      responsive:
        tablet:
          columns: 2
        mobile:
          columns: 1
      fields:
        - { field: first_name }
        - { field: last_name }
        - { field: email }
```

**Ruby DSL:**

```ruby
form do
  section "Contact Details", columns: 3, responsive: { tablet: 2, mobile: 1 } do
    field :first_name
    field :last_name
    field :email
  end
end
```

---

## Nested Fields

Use nested fields to manage `has_many` associations inline within the parent form. Users can add, remove, and reorder child records without leaving the page.

**YAML:**

```yaml
form:
  sections:
    - title: "Order Details"
      fields:
        - { field: customer_id, input_type: association_select }
        - { field: order_date, input_type: date }
    - title: "Line Items"
      type: nested_fields
      association: line_items
      allow_add: true
      allow_remove: true
      add_label: "Add Line Item"
      min: 1
      max: 20
      empty_message: "No line items yet. Click 'Add Line Item' to begin."
      fields:
        - { field: product_id, input_type: association_select }
        - { field: quantity, input_type: number }
        - { field: unit_price, input_type: number, prefix: "$" }
```

**Ruby DSL:**

```ruby
form do
  section "Order Details" do
    field :customer_id, input_type: :association_select
    field :order_date, input_type: :date
  end

  nested_fields "Line Items", association: :line_items,
    allow_add: true, allow_remove: true,
    add_label: "Add Line Item", min: 1, max: 20,
    empty_message: "No line items yet. Click 'Add Line Item' to begin." do
      field :product_id, input_type: :association_select
      field :quantity, input_type: :number
      field :unit_price, input_type: :number, prefix: "$"
  end
end
```

| Option | Default | Description |
|--------|---------|-------------|
| `allow_add` | `true` | Show a button to add new child records |
| `allow_remove` | `true` | Show a remove button on each row |
| `add_label` | `"Add"` | Label for the add button |
| `min` | - | Minimum number of child records |
| `max` | - | Maximum number of child records |
| `empty_message` | - | Message when there are no child records |
| `sortable` | `false` | Enable drag-and-drop reordering |

### Sortable Nested Forms

Enable drag-and-drop reordering by setting `sortable: true`. The position field is automatically hidden from the visible form and managed via hidden inputs.

**YAML:**

```yaml
- title: "Checklist Items"
  type: nested_fields
  association: checklist_items
  sortable: true
  add_label: "Add Item"
  fields:
    - { field: title }
    - { field: completed, input_type: boolean }
```

**Ruby DSL:**

```ruby
nested_fields "Checklist Items", association: :checklist_items,
  sortable: true, add_label: "Add Item" do
    field :title
    field :completed, input_type: :boolean
end
```

The child model should have an integer `position` field, and the parent association should specify `order: { position: asc }`. For a custom position field name, pass a string instead of `true`: `sortable: "sort_order"`.

---

## Search and Filters

The search configuration adds a search bar and optional predefined filter buttons to the index page.

**YAML:**

```yaml
search:
  enabled: true
  searchable_fields: [title, description, email]
  placeholder: "Search contacts..."
  predefined_filters:
    - { name: all, label: "All", default: true }
    - { name: active, label: "Active", scope: active }
    - { name: vip, label: "VIP Clients", scope: vip_clients }
    - { name: recent, label: "Recent", scope: recent }
```

**Ruby DSL:**

```ruby
search do
  searchable_fields :title, :description, :email
  placeholder "Search contacts..."
  filter :all, label: "All", default: true
  filter :active, label: "Active", scope: :active
  filter :vip, label: "VIP Clients", scope: :vip_clients
  filter :recent, label: "Recent", scope: :recent
end
```

Each filter (except the default "all") maps to a named scope defined in the model YAML. The `all` filter shows unfiltered results.

To disable search entirely:

**YAML:**

```yaml
search:
  enabled: false
```

**Ruby DSL:**

```ruby
search enabled: false
```

---

## Actions

Actions define the buttons available for creating, viewing, editing, deleting, and performing custom operations on records.

### Built-In CRUD Actions

**YAML:**

```yaml
actions:
  collection:
    - { name: create, type: built_in, label: "New Contact", icon: plus }
  single:
    - { name: show, type: built_in, icon: eye }
    - { name: edit, type: built_in, icon: pencil }
    - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

**Ruby DSL:**

```ruby
action :create, type: :built_in, on: :collection, label: "New Contact", icon: "plus"
action :show,   type: :built_in, on: :single, icon: "eye"
action :edit,   type: :built_in, on: :single, icon: "pencil"
action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
```

Actions are grouped into three categories:

| Category | Description |
|----------|-------------|
| `collection` / `on: :collection` | Actions above the table (e.g., "New") |
| `single` / `on: :single` | Actions per row (e.g., show, edit, destroy) |
| `batch` / `on: :batch` | Actions on multiple selected records |

### Custom Actions

Custom actions trigger domain-specific operations. Use `type: custom` and register an action class in `app/actions/`.

**YAML:**

```yaml
actions:
  single:
    - name: close_won
      type: custom
      label: "Close as Won"
      icon: check-circle
      confirm: true
      confirm_message: "Mark this deal as won?"
    - name: send_invoice
      type: custom
      label: "Send Invoice"
      icon: mail
```

**Ruby DSL:**

```ruby
action :close_won, type: :custom, on: :single,
  label: "Close as Won", icon: "check-circle",
  confirm: true, confirm_message: "Mark this deal as won?"

action :send_invoice, type: :custom, on: :single,
  label: "Send Invoice", icon: "mail"
```

See the [Custom Actions Guide](custom-actions.md) for how to implement action classes.

### Conditional Actions

Control when actions are visible or disabled using `visible_when` and `disable_when`.

**YAML:**

```yaml
single:
  - name: close_won
    type: custom
    label: "Close as Won"
    icon: check-circle
    visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
    disable_when: { field: value, operator: blank }
  - name: reopen
    type: custom
    label: "Reopen"
    icon: refresh-cw
    visible_when: { field: stage, operator: in, value: [closed_won, closed_lost] }
```

**Ruby DSL:**

```ruby
action :close_won, type: :custom, on: :single,
  label: "Close as Won", icon: "check-circle",
  visible_when: { field: :stage, operator: :not_in, value: [:closed_won, :closed_lost] },
  disable_when: { field: :value, operator: :blank }

action :reopen, type: :custom, on: :single,
  label: "Reopen", icon: "refresh-cw",
  visible_when: { field: :stage, operator: :in, value: [:closed_won, :closed_lost] }
```

An action can use both `visible_when` and `disable_when` together. Visibility is evaluated first -- if the action is hidden, `disable_when` has no effect.

---

## Conditional Rendering

Form fields and sections can be conditionally shown/hidden or enabled/disabled based on record values.

### Field-Value Conditions

Evaluated client-side with JavaScript for instant reactivity.

**YAML:**

```yaml
fields:
  - field: expected_revenue
    input_type: number
    prefix: "$"
    visible_when: { field: stage, operator: not_in, value: [lead] }
  - field: close_reason
    input_type: textarea
    disable_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
```

**Ruby DSL:**

```ruby
field :expected_revenue, input_type: :number, prefix: "$",
  visible_when: { field: :stage, operator: :not_in, value: ["lead"] }

field :close_reason, input_type: :textarea,
  disable_when: { field: :stage, operator: :not_in, value: ["closed_won", "closed_lost"] }
```

### Service Conditions

For server-side logic (database lookups, complex business rules), use service conditions.

**YAML:**

```yaml
fields:
  - field: internal_code
    visible_when: { service: persisted_check }
```

**Ruby DSL:**

```ruby
field :internal_code, visible_when: { service: :persisted_check }
```

### Section-Level Conditions

Apply conditions to entire form sections.

**YAML:**

```yaml
sections:
  - title: "Revenue Details"
    visible_when: { field: stage, operator: not_eq, value: lead }
    fields:
      - { field: expected_revenue, input_type: number }
      - { field: probability, input_type: slider }
```

**Ruby DSL:**

```ruby
section "Revenue Details",
  visible_when: { field: :stage, operator: :not_eq, value: "lead" } do
    field :expected_revenue, input_type: :number
    field :probability, input_type: :slider
end
```

For full details on condition operators and service conditions, see the [Conditional Rendering Guide](conditional-rendering.md) and [Condition Operators Reference](../reference/condition-operators.md).

---

## Read-Only and Embeddable Presenters

### Read-Only Presenters

Set `read_only: true` to disable create, edit, and destroy operations. The model data is still writable through other presenters or direct code. Use this for dashboards or reporting views.

**YAML:**

```yaml
presenter:
  name: deal_pipeline
  model: deal
  label: "Pipeline"
  slug: pipeline
  icon: bar-chart
  read_only: true

  index:
    table_columns:
      - { field: title, link_to: show, sortable: true }
      - field: stage
        renderer: badge
        options:
          color_map:
            open: blue
            closed_won: green
            closed_lost: red
      - { field: value, renderer: currency, summary: sum }
```

**Ruby DSL:**

```ruby
define_presenter :deal_pipeline do
  model :deal
  label "Pipeline"
  slug "pipeline"
  icon "bar-chart"
  read_only true

  index do
    column :title, link_to: :show, sortable: true
    column :stage, renderer: :badge,
      options: { color_map: { open: "blue", closed_won: "green", closed_lost: "red" } }
    column :value, renderer: :currency, summary: :sum
  end

  action :show, type: :built_in, on: :single, icon: "eye"
end
```

### Embeddable Presenters

Set `embeddable: true` to mark a presenter for embedding within other views (e.g., as an inline table within a parent record's show page). This is a metadata flag for the UI layer.

**YAML:**

```yaml
presenter:
  name: deal_embed
  model: deal
  label: "Deals"
  embeddable: true
  # no slug -- not directly routable
```

**Ruby DSL:**

```ruby
define_presenter :deal_embed do
  model :deal
  label "Deals"
  embeddable true
end
```

---

## DSL Inheritance

The Ruby DSL supports inheritance, where a child presenter copies the parent's configuration and overrides specific sections. This avoids duplication when you need multiple views of the same model.

**Ruby DSL:**

```ruby
# config/lcp_ruby/presenters/deal.rb
define_presenter :deal do
  model :deal
  label "Deals"
  slug "deals"
  icon "dollar-sign"

  index do
    default_sort :created_at, :desc
    per_page 25
    column :title, link_to: :show, sortable: true
    column :stage, renderer: :badge, sortable: true
    column :value, renderer: :currency, sortable: true
    column :updated_at, renderer: :relative_date
  end

  show do
    section "Deal Information", columns: 2 do
      field :title, renderer: :heading
      field :stage, renderer: :badge
      field :value, renderer: :currency
    end
  end

  form do
    section "Details", columns: 2 do
      field :title, placeholder: "Deal title..."
      field :stage, input_type: :select
      field :value, input_type: :number, prefix: "$"
    end
  end

  search do
    searchable_fields :title
    placeholder "Search deals..."
    filter :all, label: "All", default: true
    filter :open, label: "Open", scope: :open_deals
  end

  action :create, type: :built_in, on: :collection, label: "New Deal", icon: "plus"
  action :show,   type: :built_in, on: :single, icon: "eye"
  action :edit,   type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
```

```ruby
# config/lcp_ruby/presenters/deal_pipeline.rb
define_presenter :deal_pipeline, inherits: :deal do
  label "Deal Pipeline"
  slug "pipeline"
  icon "bar-chart"
  read_only true

  # Completely replaces the parent's index
  index do
    default_view :table
    per_page 50
    column :title, link_to: :show, sortable: true
    column :stage, renderer: :badge, sortable: true
    column :value, renderer: :currency, summary: :sum
  end

  # Disables search
  search enabled: false

  # Replaces parent's actions
  action :show, type: :built_in, on: :single, icon: "eye"
end
```

### Inheritance Rules

- **Section-level replace**: When a child defines `index`, `show`, `form`, `search`, or `actions`, it completely replaces the parent's version. There is no deep merge.
- **Unset sections are inherited**: If the child does not define a section, the parent's version is used as-is.
- **Top-level attributes**: `name`, `label`, `slug`, `icon`, `read_only`, `embeddable` are taken from the child when defined. The `model` is inherited from the parent unless overridden.
- **Parent must exist**: The parent must be defined in a DSL file in the same directory.
- **No circular inheritance**: Circular chains are detected and raise `MetadataError`.

Inheritance is a DSL-only convenience -- YAML files cannot inherit. The result is always a flat hash identical to what you could write in full YAML.

---

## Common Patterns

### CRM Contact List

A contact list with search, filters, responsive columns, and multiple renderers.

**YAML:**

```yaml
presenter:
  name: contact
  model: contact
  label: "Contacts"
  slug: contacts
  icon: users

  index:
    default_sort: { field: name, direction: asc }
    per_page: 25
    row_click: show
    table_columns:
      - { field: name, width: "25%", link_to: show, sortable: true, pinned: left }
      - { field: email, renderer: email_link, hidden_on: mobile }
      - { field: phone, renderer: phone_link, hidden_on: [mobile, tablet] }
      - field: company_name
        sortable: true
        hidden_on: mobile
      - field: status
        renderer: badge
        options:
          color_map:
            active: green
            inactive: gray

  show:
    layout:
      - section: "Contact Details"
        columns: 2
        responsive:
          mobile:
            columns: 1
        fields:
          - { field: name, renderer: heading, col_span: 2 }
          - { field: email, renderer: email_link }
          - { field: phone, renderer: phone_link }
          - { field: company_name }
          - field: status
            renderer: badge
      - section: "Deals"
        type: association_list
        association: deals

  form:
    sections:
      - title: "Contact Information"
        columns: 2
        responsive:
          mobile:
            columns: 1
        fields:
          - { field: first_name, autofocus: true }
          - { field: last_name }
          - { type: divider, label: "Communication" }
          - { field: email, placeholder: "email@example.com" }
          - { field: phone }
          - { field: company_id, input_type: association_select }
      - title: "Notes"
        collapsible: true
        fields:
          - { field: notes, input_type: textarea, input_options: { rows: 4 } }

  search:
    enabled: true
    searchable_fields: [first_name, last_name, email]
    placeholder: "Search contacts..."
    predefined_filters:
      - { name: all, label: "All", default: true }
      - { name: active, label: "Active", scope: active }
      - { name: inactive, label: "Inactive", scope: inactive }

  actions:
    collection:
      - { name: create, type: built_in, label: "New Contact", icon: plus }
    single:
      - { name: show, type: built_in, icon: eye }
      - { name: edit, type: built_in, icon: pencil }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }
```

### Order Form with Line Items

A form with nested fields for inline editing of child records.

**Ruby DSL:**

```ruby
define_presenter :order do
  model :order
  label "Orders"
  slug "orders"
  icon "shopping-cart"

  index do
    default_sort :created_at, :desc
    per_page 20
    column :order_number, link_to: :show, sortable: true
    column :customer_name, sortable: true
    column :total, renderer: :currency, sortable: true, summary: :sum,
      options: { currency: "$", precision: 2 }
    column :status, renderer: :badge,
      options: { color_map: { pending: "yellow", shipped: "blue", delivered: "green" } }
    column :created_at, renderer: :relative_date, hidden_on: :mobile
  end

  form do
    section "Order Details", columns: 2, responsive: { mobile: 1 } do
      field :customer_id, input_type: :association_select
      field :order_date, input_type: :date, default: "current_date"
      field :status, input_type: :select
      field :notes, input_type: :textarea, col_span: 2,
        input_options: { rows: 3 }
    end

    nested_fields "Line Items", association: :line_items,
      sortable: true, allow_add: true, allow_remove: true,
      add_label: "Add Line Item", min: 1, max: 50,
      empty_message: "Add at least one line item." do
        field :product_id, input_type: :association_select
        field :quantity, input_type: :number, input_options: { min: 1 }
        field :unit_price, input_type: :number, prefix: "$",
          input_options: { min: 0, step: 0.01 }
    end
  end

  search do
    searchable_fields :order_number, :customer_name
    placeholder "Search orders..."
    filter :all, label: "All", default: true
    filter :pending, label: "Pending", scope: :pending
    filter :shipped, label: "Shipped", scope: :shipped
  end

  action :create,  type: :built_in, on: :collection, label: "New Order", icon: "plus"
  action :show,    type: :built_in, on: :single, icon: "eye"
  action :edit,    type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
```

---

## What's Next

- [Presenters Reference](../reference/presenters.md) -- complete attribute reference for all presenter YAML options
- [Presenter DSL Reference](../reference/presenter-dsl.md) -- complete reference for the Ruby DSL with inheritance
- [Renderers Guide](display-types.md) -- visual guide to all built-in renderers
- [Conditional Rendering Guide](conditional-rendering.md) -- deep dive into `visible_when` and `disable_when`
- [Custom Actions Guide](custom-actions.md) -- writing domain-specific action classes
- [View Groups Guide](view-groups.md) -- navigation menu and view switching between presenters
- [Condition Operators Reference](../reference/condition-operators.md) -- full list of supported operators
