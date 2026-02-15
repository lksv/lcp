# Presenters Reference

File: `config/lcp_ruby/presenters/<name>.yml`

Presenter YAML defines the UI layer: how records are listed, displayed, edited, searched, and what actions are available. Multiple presenters can reference the same model to provide different views (e.g., an admin view and a read-only pipeline view).

## Top-Level Attributes

```yaml
presenter:
  name: <presenter_name>
  model: <model_name>
  label: "Display Label"
  slug: <url_slug>
  icon: <icon_name>
  read_only: false
  embeddable: false
  index: {}
  show: {}
  form: {}
  search: {}
  actions: {}
  navigation: {}
```

### `name`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Unique identifier for the presenter. Referenced from [permissions](permissions.md) (`presenters` attribute) and used internally for resolution.

### `model`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |

Name of the [model](models.md) this presenter displays. Must match a model's `name` attribute.

### `label`

| | |
|---|---|
| **Required** | no |
| **Default** | `name.humanize` |
| **Type** | string |

Display label for the presenter, shown in navigation menus and page titles.

### `slug`

| | |
|---|---|
| **Required** | no |
| **Type** | string |

URL path segment. When set, the presenter is routable at `/admin/<slug>`. If omitted, the presenter is not directly accessible via URL (useful for embedded or programmatic-only presenters).

### `icon`

| | |
|---|---|
| **Required** | no |
| **Type** | string |

Icon name displayed in navigation menus. The engine uses these as CSS class hints (e.g., `dollar-sign`, `check-square`, `users`).

### `read_only`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |

When `true`, disables create, edit, and destroy operations for this presenter. The model data is still writable through other presenters or direct code. Use this for dashboard or reporting views.

### `embeddable`

| | |
|---|---|
| **Required** | no |
| **Default** | `false` |
| **Type** | boolean |

Marks this presenter as embeddable within other views (e.g., as an inline table within a parent record's show page). This is a metadata flag for the UI layer to decide rendering behavior.

## Index Configuration

Controls the record list view.

```yaml
index:
  default_view: table
  views_available: [table, tiles]
  default_sort: { field: created_at, direction: desc }
  per_page: 25
  table_columns: []
```

### `default_view`

| | |
|---|---|
| **Default** | `"table"` |
| **Type** | string |

The default display mode for the index page.

### `views_available`

| | |
|---|---|
| **Required** | no |
| **Default** | not set |
| **Type** | array of strings |

List of available view modes the user can switch between (e.g., `[table, tiles]`). This is a metadata attribute for future UI support of multiple view modes.

### `default_sort`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Default sorting for the index page.

```yaml
default_sort: { field: created_at, direction: desc }
```

- `field` — column name to sort by
- `direction` — `asc` or `desc`

### `per_page`

| | |
|---|---|
| **Default** | `25` |
| **Type** | integer |

Number of records per page. Used by Kaminari pagination.

### `table_columns`

| | |
|---|---|
| **Default** | `[]` |
| **Type** | array of column objects |

Defines which columns appear in the index table and how they render.

```yaml
table_columns:
  - field: title
    width: "30%"
    link_to: show
    sortable: true
    display: null
```

#### Column Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Model field name to display |
| `width` | string | CSS width (e.g., `"30%"`, `"200px"`) |
| `link_to` | string | Makes the cell a link. Value `show` links to the record's show page |
| `sortable` | boolean | Enables column header sorting |
| `display` | string | Display type (see below) |

#### Display Types (Index)

| Type | Description |
|------|-------------|
| `badge` | Renders the value as a colored badge (useful for enum/status fields) |
| `currency` | Formats the value as currency |
| `relative_date` | Shows relative time (e.g., "3 days ago") |

## Show Configuration

Controls the record detail view.

```yaml
show:
  layout:
    - section: "Section Title"
      columns: 2
      fields:
        - { field: title, display: heading }
        - { field: stage, display: badge }
    - section: "Related Items"
      type: association_list
      association: contacts
```

### `layout`

Array of section objects. Each section is rendered as a card or panel.

#### Section Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `section` | string | Section heading text |
| `columns` | integer | Number of columns in the field grid (default: 1) |
| `fields` | array | Fields to display (see below) |
| `type` | string | Set to `association_list` for related record sections |
| `association` | string | Association name (required when `type: association_list`) |

#### Association List Sections

Use `type: association_list` to render a table of associated records within the show page:

```yaml
- section: "Contacts"
  type: association_list
  association: contacts
```

This renders a list of records from the `contacts` has_many association.

#### Show Field Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Model field name |
| `display` | string | Display type (see below) |

#### Display Types (Show)

| Type | Description |
|------|-------------|
| `heading` | Renders as a prominent heading |
| `badge` | Colored badge |
| `link` | Renders as a clickable link |
| `rich_text` | Renders HTML content |
| `currency` | Currency formatting |
| `relative_date` | Relative time display |

## Form Configuration

Controls the create and edit forms.

```yaml
form:
  sections:
    - title: "Section Title"
      columns: 2
      fields:
        - { field: title, placeholder: "Enter title...", autofocus: true }
        - { field: stage, input_type: select }
        - { field: value, input_type: number, prefix: "$" }
        - { field: company_id, input_type: association_select }
```

### `sections`

Array of form section objects.

#### Form Section Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `title` | string | Section heading text |
| `columns` | integer | Number of columns in the field grid (default: 1) |
| `fields` | array | Form fields (see below) |

#### Form Field Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Model field name or FK column name |
| `input_type` | string | Override the default input type (see below) |
| `placeholder` | string | Placeholder text for the input |
| `autofocus` | boolean | Auto-focus this field when the form loads |
| `prefix` | string | Text prefix displayed before the input (e.g., `"$"` for currency) |

#### Input Types

| Input Type | Description | Default For |
|------------|-------------|-------------|
| `text` | Single-line text input | `string` fields |
| `textarea` | Multi-line text area | `text` fields |
| `select` | Dropdown (populated from `enum_values`) | `enum` fields |
| `number` | Numeric input | `integer`, `float`, `decimal` fields |
| `date` / `date_picker` | Date picker | `date` fields |
| `datetime` | Datetime picker | `datetime` fields |
| `boolean` | Checkbox | `boolean` fields |
| `association_select` | Dropdown populated from associated model's records | FK fields (e.g., `company_id`) |
| `rich_text_editor` | Rich text editor | `rich_text` fields |

#### How Association Selects Work

When a form field has `input_type: association_select` on a foreign key column (e.g., `company_id`):

1. The `LayoutBuilder` matches the FK field name against `association.foreign_key` in model metadata
2. Creates a synthetic `FieldDefinition` (type: integer) with the `AssociationDefinition` attached
3. The form renders a `<select>` populated from the target model's records
4. Display text uses `to_label` (if defined) or `to_s`
5. Falls back to a number input if the target model is not registered in LCP
6. FK fields bypass the `field_writable?` permission check — they are permitted separately in the controller

## Search Configuration

Controls the search bar and predefined filters on the index page.

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

### Search Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `enabled` | boolean | Enable/disable the search bar |
| `searchable_fields` | array | Field names to search with LIKE queries |
| `placeholder` | string | Search input placeholder text |
| `predefined_filters` | array | Filter buttons (see below) |

### Predefined Filter Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | Filter identifier |
| `label` | string | Button text |
| `default` | boolean | Whether this filter is active by default |
| `scope` | string | Named [scope](models.md#scopes) to apply. Omit for the "all" filter |

Predefined filters render as buttons above the table. Each filter (except the default "all") maps to a named scope defined in the model YAML.

## Actions Configuration

Controls CRUD buttons and custom actions.

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

### Action Categories

| Category | Description |
|----------|-------------|
| `collection` | Actions on the collection (no specific record). Displayed above the table. |
| `single` | Actions on a single record. Displayed in each table row. |
| `batch` | Actions on multiple selected records. |

### Action Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | Action identifier. For built-in: `show`, `edit`, `destroy`, `create` |
| `type` | string | `built_in` or `custom` |
| `label` | string | Display text |
| `icon` | string | Icon name |
| `confirm` | boolean | Show a confirmation dialog before executing |
| `confirm_message` | string | Custom text for the confirmation dialog |
| `style` | string | CSS style hint (e.g., `danger` for destructive actions) |
| `visible_when` | object | Condition controlling visibility (see below) |

### Action Types

- **`built_in`** — standard CRUD actions (`show`, `edit`, `destroy`, `create`). Authorization checked via `PermissionEvaluator.can?`.
- **`custom`** — user-defined actions. Authorization checked via `can_execute_action?`. Dispatched to registered action classes. See [Custom Actions](../guides/custom-actions.md).

### Action Visibility

The `visible_when` attribute uses a [condition object](condition-operators.md) to conditionally show/hide the action based on record field values:

```yaml
visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
```

The condition is evaluated per-record via `ConditionEvaluator`. When omitted, the action is always visible (subject to permission checks).

## Navigation

Controls menu placement.

```yaml
navigation:
  menu: main
  position: 3
```

### Navigation Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `menu` | string | Menu group name (e.g., `main`) |
| `position` | integer | Sort order within the menu (lower numbers appear first) |

## Complete Example

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

Source: `lib/lcp_ruby/metadata/presenter_definition.rb`, `lib/lcp_ruby/presenter/layout_builder.rb`, `lib/lcp_ruby/presenter/column_set.rb`, `lib/lcp_ruby/presenter/action_set.rb`
