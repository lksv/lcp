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

URL path segment. When set, the presenter is routable at `/<slug>`. If omitted, the presenter is not directly accessible via URL (useful for embedded or programmatic-only presenters).

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
  description: "Browse and manage all records."
  default_view: table
  views_available: [table, tiles]
  default_sort: { field: created_at, direction: desc }
  per_page: 25
  row_click: show
  empty_message: "No records found."
  actions_position: dropdown
  table_columns: []
```

### `description`

| | |
|---|---|
| **Required** | no |
| **Type** | string |

Descriptive text displayed below the page heading. Available on `index`, `show`, and `form` views.

```yaml
index:
  description: "Browse all deals in your pipeline."
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

### `row_click`

| | |
|---|---|
| **Required** | no |
| **Default** | not set |
| **Type** | string |

When set to `"show"`, clicking any table row navigates to the record's show page. This makes the entire row clickable, not just link columns. When omitted, rows are not clickable (users navigate via link columns or action buttons).

```yaml
index:
  row_click: show
```

### `empty_message`

| | |
|---|---|
| **Required** | no |
| **Default** | not set |
| **Type** | string |

Custom message displayed when no records match the current search or filter. If omitted, a generic empty state is shown.

```yaml
index:
  empty_message: "No deals match your criteria. Try adjusting your filters."
```

### `actions_position`

| | |
|---|---|
| **Required** | no |
| **Default** | inline |
| **Type** | string |

Controls how single-record actions are rendered in each table row. When set to `"dropdown"`, all single actions are grouped into a dropdown menu (useful when there are many actions). The default behavior renders each action as an inline button.

```yaml
index:
  actions_position: dropdown
```

### `includes`

| | |
|---|---|
| **Required** | no |
| **Default** | `[]` |
| **Type** | array of strings or nested hashes |

Manually specify associations to preload for display purposes. Auto-detection handles most cases, but this allows explicit overrides. See [Eager Loading](eager-loading.md).

```yaml
index:
  includes: [company, contact]
```

### `eager_load`

| | |
|---|---|
| **Required** | no |
| **Default** | `[]` |
| **Type** | array of strings or nested hashes |

Manually specify associations to eager load via LEFT JOIN. Use when associations are needed for sorting or filtering. See [Eager Loading](eager-loading.md).

```yaml
index:
  eager_load: [company]
```

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
    renderer: null
```

#### Column Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Model field name to display. Supports dot-notation (e.g., `"company.name"`) and template syntax (e.g., `"{first_name} {last_name}"`) |
| `label` | string | Custom column header label. Defaults to humanized last segment of the field name. Useful for dot-path fields (e.g., `"company.name"` → label `"Company"`) |
| `width` | string | CSS width (e.g., `"30%"`, `"200px"`) |
| `link_to` | string | Makes the cell a link. Value `show` links to the record's show page |
| `sortable` | boolean | Enables column header sorting |
| `renderer` | string | Renderer for the field value (see [Renderers](#renderers)). Alternatively, use `partial: "path/to/partial"` to render with a custom view partial |
| `options` | hash | Options passed to the renderer (see [Renderers](#renderers) for per-renderer options) |
| `hidden_on` | array/string | Hide column at specific breakpoints. Values: `"mobile"`, `"tablet"`. Accepts a single string or an array |
| `pinned` | string | Pin column to one side on horizontal scroll. Value: `"left"` |
| `summary` | string | Adds a summary row at the bottom of the table for this column. Values: `"sum"`, `"avg"`, `"count"` |

**Example with new column attributes:**

```yaml
table_columns:
  - field: name
    width: "25%"
    link_to: show
    sortable: true
    pinned: left
  - field: email
    hidden_on: [mobile, tablet]
  - field: status
    renderer: badge
    options:
      color_map:
        active: green
        inactive: gray
        pending: yellow
  - field: revenue
    renderer: currency
    options:
      currency: "$"
      precision: 2
    sortable: true
    summary: sum
  - field: deals_count
    summary: count
    hidden_on: mobile
```

## Field Path Syntax

The `field` attribute in `table_columns` and show `fields` supports three syntaxes beyond simple field names:

### Dot-Notation (Association Traversal)

Use dot-notation to display fields from associated records:

```yaml
table_columns:
  - { field: "company.name", sortable: true }        # belongs_to traversal
  - { field: "company.industry", renderer: badge }     # with renderer
  - { field: "contacts.full_name", renderer: collection }  # has_many traversal
```

For `belongs_to`/`has_one`, the resolved value is a scalar. For `has_many`, the resolved value is an array (use the `collection` renderer).

Dot-paths can be nested: `company.industry.name` traverses `company` → `industry` → `name`.

**Permissions:** Each segment in the dot-path is checked against `readable_fields` on the target model. If any segment is not readable, the column is hidden.

**Eager loading:** Dot-path fields are automatically detected by the `IncludesResolver` and the required associations are preloaded to prevent N+1 queries.

### Template Syntax (Multi-Field Interpolation)

Use `{field}` syntax to combine multiple fields into a single display value:

```yaml
table_columns:
  - { field: "{first_name} {last_name}" }
  - { field: "{company.name}: {title}" }     # dot-paths inside templates
```

Template fields extract all `{ref}` references and resolve each one individually. Dot-paths inside templates work the same as standalone dot-paths.

**Permissions:** All referenced fields must be readable for the template column to be visible.

### Collection Renderer

The `collection` renderer renders arrays (typically from `has_many` dot-paths) as formatted lists:

```yaml
table_columns:
  - field: "contacts.full_name"
    renderer: collection
    options:
      separator: ", "          # default: ", "
      limit: 3                 # max items to show
      overflow: "..."          # text appended when truncated (default: "...")
      item_renderer: badge     # apply a renderer to each item
      item_options:            # options for the per-item renderer
        color_map: { ... }
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `separator` | string | `", "` | Separator between items |
| `limit` | integer | all | Maximum number of items to display |
| `overflow` | string | `"..."` | Text appended when items are truncated |
| `item_renderer` | string | none | Renderer to apply to each item before joining |
| `item_options` | hash | `{}` | Options for the per-item renderer |

### Custom Renderers

Custom renderers defined in `app/renderers/` can be referenced by name in the `renderer` attribute:

```yaml
table_columns:
  - field: stage
    renderer: conditional_badge
    options:
      rules:
        - match: { in: [closed_won] }
          renderer: badge
          options: { color_map: { closed_won: green } }
        - default:
            renderer: badge
```

You can also use `partial:` to render a field with a custom view partial instead of a renderer class:

```yaml
table_columns:
  - field: stage
    partial: "shared/stage_indicator"
```

See [Custom Renderers Guide](../guides/custom-renderers.md) for creating custom renderers.

## Renderers

Renderers control how field values are rendered in index tables and show pages. Each renderer can accept `options` to customize its behavior. You can also use `partial: "path/to/partial"` instead of a renderer to render a field with a custom view partial.

### `heading`

Renders the value as `<strong>` text. Useful for primary identifiers.

```yaml
{ field: title, renderer: heading }
```

### `badge`

Renders the value as a colored badge. Useful for enum and status fields.

| Option | Type | Description |
|--------|------|-------------|
| `color_map` | hash | Maps field values to badge colors |

Available colors: `green`, `red`, `blue`, `yellow`, `orange`, `purple`, `gray`, `teal`, `cyan`, `pink`.

```yaml
- field: status
  renderer: badge
  options:
    color_map:
      active: green
      inactive: gray
      pending: yellow
      suspended: red
```

### `truncate`

Truncates long text with an ellipsis.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max` | integer | `50` | Maximum number of characters before truncation |

```yaml
- field: description
  renderer: truncate
  options:
    max: 100
```

### `boolean_icon`

Shows a Yes/No indicator with color instead of raw true/false.

| Option | Type | Description |
|--------|------|-------------|
| `true_icon` | string | Icon name for true values |
| `false_icon` | string | Icon name for false values |

```yaml
- field: verified
  renderer: boolean_icon
  options:
    true_icon: check-circle
    false_icon: x-circle
```

### `progress_bar`

Renders a horizontal progress bar.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max` | integer | `100` | Maximum value (100% mark) |

```yaml
- field: completion
  renderer: progress_bar
  options:
    max: 100
```

### `image`

Renders the field value as an image URL.

| Option | Type | Description |
|--------|------|-------------|
| `size` | string | Image size: `"small"`, `"medium"`, `"large"` |

```yaml
- field: photo_url
  renderer: image
  options:
    size: medium
```

### `avatar`

Renders a circular avatar image.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `size` | integer | `32` | Avatar diameter in pixels |

```yaml
- field: profile_image
  renderer: avatar
  options:
    size: 48
```

### `currency`

Formats a numeric value as currency.

| Option | Type | Description |
|--------|------|-------------|
| `currency` | string | Currency unit string (e.g., `"$"`, `"EUR"`) |
| `precision` | integer | Number of decimal places |

```yaml
- field: amount
  renderer: currency
  options:
    currency: "$"
    precision: 2
```

### `percentage`

Formats a numeric value as a percentage.

| Option | Type | Description |
|--------|------|-------------|
| `precision` | integer | Number of decimal places |

```yaml
- field: margin
  renderer: percentage
  options:
    precision: 1
```

### `number`

Formats a numeric value with delimiters and precision.

| Option | Type | Description |
|--------|------|-------------|
| `delimiter` | string | Thousands separator (e.g., `","`) |
| `precision` | integer | Number of decimal places |

```yaml
- field: population
  renderer: number
  options:
    delimiter: ","
    precision: 0
```

### `date`

Formats a date value.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format` | string | `"%Y-%m-%d"` | strftime format string |

```yaml
- field: birth_date
  renderer: date
  options:
    format: "%B %d, %Y"
```

### `datetime`

Formats a datetime value.

| Option | Type | Description |
|--------|------|-------------|
| `format` | string | strftime format string |

```yaml
- field: created_at
  renderer: datetime
  options:
    format: "%Y-%m-%d %H:%M"
```

### `relative_date`

Shows a human-readable relative time (e.g., "3 days ago", "in 2 hours").

```yaml
{ field: updated_at, renderer: relative_date }
```

### `email_link`

Renders the value as a `mailto:` link.

```yaml
{ field: email, renderer: email_link }
```

### `phone_link`

Renders the value as a `tel:` link.

```yaml
{ field: phone, renderer: phone_link }
```

### `url_link`

Renders the value as an external link that opens in a new tab.

```yaml
{ field: website, renderer: url_link }
```

### `color_swatch`

Renders a color preview swatch alongside the color value.

```yaml
{ field: brand_color, renderer: color_swatch }
```

### `rating`

Displays a numeric value as filled stars.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max` | integer | `5` | Maximum number of stars |

```yaml
- field: score
  renderer: rating
  options:
    max: 5
```

### `code`

Renders the value in monospace code formatting.

```yaml
{ field: api_key, renderer: code }
```

### `file_size`

Renders a numeric byte value as human-readable file size (e.g., "2.4 MB").

```yaml
{ field: attachment_size, renderer: file_size }
```

### `rich_text`

Renders HTML content safely.

```yaml
{ field: body, renderer: rich_text }
```

### `link`

Renders the value as a clickable link. Uses `to_label` (if defined on the model) or `to_s` for the display text.

```yaml
{ field: reference, renderer: link }
```

### `attachment_preview`

Renders an image preview for attachment fields. For image files, displays the image (optionally using a named variant). For non-image files, falls back to a download link.

| Option | Type | Description |
|--------|------|-------------|
| `variant` | string | Named variant to use for the image (e.g., `"thumbnail"`, `"medium"`) |

```yaml
- field: photo
  renderer: attachment_preview
  options:
    variant: medium
```

### `attachment_list`

Renders a list of download links with filenames and file sizes. Designed for multiple attachment fields.

```yaml
- field: files
  renderer: attachment_list
```

### `attachment_link`

Renders a single download link with the filename. Designed for single non-image attachment fields.

```yaml
- field: contract
  renderer: attachment_link
```

## Show Configuration

Controls the record detail view.

```yaml
show:
  description: "View record details and related items."
  includes: [contacts, deals]
  layout:
    - section: "Section Title"
      description: "Key information about this record."
      columns: 2
      fields:
        - { field: title, renderer: heading }
        - { field: stage, renderer: badge }
        - { type: info, text: "This explains the fields above." }
    - section: "Related Items"
      type: association_list
      association: contacts
```

### `includes` / `eager_load`

Same as index configuration. Manually specify associations to preload for the show page. Auto-detection handles `association_list` sections automatically. See [Eager Loading](eager-loading.md).

### `layout`

Array of section objects. Each section is rendered as a card or panel.

#### Section Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `section` | string | Section heading text |
| `description` | string | Explanatory text displayed below the section heading |
| `columns` | integer | Number of columns in the field grid (default: 1) |
| `fields` | array | Fields to display (see below) |
| `type` | string | Set to `association_list` for related record sections |
| `association` | string | Association name (required when `type: association_list`) |
| `responsive` | hash | Responsive overrides per breakpoint (see below) |
| `visible_when` | hash | Condition object. When false, the section is not rendered. Same syntax as [field conditions](#conditional-visibility) |
| `disable_when` | hash | Condition object. When true, the section has a disabled appearance. Same syntax as [field conditions](#conditional-disabling) |

Show page conditions are evaluated **server-side only** — hidden sections are not rendered in the DOM (no client-side JavaScript toggling).

```yaml
- section: "Metrics"
  visible_when: { field: stage, operator: not_eq, value: lead }
  fields:
    - { field: priority }
    - { field: progress }
```

#### Association List Sections

Use `type: association_list` to render a list of associated records within the show page:

```yaml
- section: "Contacts"
  type: association_list
  association: contacts
  display_template: default
  link: true
  sort: { last_name: asc }
  limit: 5
  empty_message: "No contacts yet."
  scope: active
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `association` | string | — | **Required.** Association name from the model |
| `display_template` | string | `"default"` | Name of the display template defined on the target model |
| `link` | boolean | `false` | Wrap each record in a link to its show page |
| `sort` | hash | — | Sort field and direction (e.g., `{ last_name: asc }`) |
| `limit` | integer | — | Maximum number of records to display |
| `empty_message` | string | `"No records."` | Message when no associated records exist |
| `scope` | string | — | Named scope to apply on the association |
| `visible_when` | hash | — | Condition object. When false, the section is not rendered |
| `disable_when` | hash | — | Condition object. When true, the section has a disabled appearance |

When `display_template` references a display template defined on the target model (see [Models Reference — Display Templates](models.md#display-templates)), records render with rich HTML including title, subtitle, icon, and badge. Without a display template, records fall back to `to_label`.

When `link: true`, each record is wrapped in a link to the target model's show page (the first presenter for that model is used for routing).

Sort and limit operate in-memory on preloaded records (unless `scope` is specified, which triggers a SQL query).

#### Responsive Sections

Use `responsive` to override the number of columns at different breakpoints:

```yaml
- section: "Deal Information"
  columns: 3
  responsive:
    tablet:
      columns: 2
    mobile:
      columns: 1
  fields:
    - { field: title, renderer: heading }
    - { field: stage, renderer: badge }
    - { field: value, renderer: currency }
```

#### Show Field Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Model field name. Supports dot-notation and template syntax |
| `label` | string | Custom field label. Defaults to humanized last segment of the field name. Useful for dot-path fields (e.g., `"company.name"` → label `"Company"`) |
| `renderer` | string | Renderer for the field value (see [Renderers](#renderers)). Alternatively, use `partial: "path/to/partial"` to render with a custom view partial |
| `options` | hash | Options passed to the renderer (see [Renderers](#renderers) for per-renderer options) |
| `col_span` | integer | Number of grid columns this field spans (defaults to 1) |
| `hidden_on` | array/string | Hide field at specific breakpoints. Values: `"mobile"`, `"tablet"` |

**Example with new show field attributes:**

```yaml
show:
  layout:
    - section: "Overview"
      columns: 3
      responsive:
        mobile:
          columns: 1
      fields:
        - { field: title, renderer: heading, col_span: 3 }
        - field: status
          renderer: badge
          options:
            color_map:
              active: green
              inactive: red
        - { field: email, renderer: email_link }
        - { field: phone, renderer: phone_link, hidden_on: mobile }
        - field: revenue
          renderer: currency
          options:
            currency: "$"
            precision: 2
```

## Form Configuration

Controls the create and edit forms.

```yaml
form:
  description: "Fill in the record details below."
  layout: flat
  includes: [todo_items]
  sections:
    - title: "Section Title"
      description: "Basic information about the record."
      columns: 2
      fields:
        - { type: info, text: "Prices are in USD." }
        - { field: title, placeholder: "Enter title...", autofocus: true }
        - { field: stage, input_type: select }
        - { field: value, input_type: number, prefix: "$" }
        - { field: company_id, input_type: association_select }
```

### `includes` / `eager_load`

Same as index configuration. Manually specify associations to preload for the form. Auto-detection handles `nested_fields` sections automatically. See [Eager Loading](eager-loading.md).

### `layout`

| | |
|---|---|
| **Required** | no |
| **Default** | `"flat"` |
| **Type** | string |

Controls how form sections are rendered. When set to `"tabs"`, each section becomes a tab in a tabbed interface. The default `"flat"` layout renders sections as stacked cards.

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
        - { field: price, input_type: number }
        - { field: currency, input_type: select }
    - title: "Advanced"
      fields:
        - { field: notes, input_type: rich_text_editor }
```

### `sections`

Array of form section objects.

#### Form Section Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `title` | string | Section heading text |
| `description` | string | Explanatory text displayed below the section heading |
| `columns` | integer | Number of columns in the field grid (default: 1) |
| `fields` | array | Form fields (see below) |
| `collapsible` | boolean | When `true`, the section can be collapsed/expanded by clicking its header |
| `collapsed` | boolean | When `true` (and `collapsible` is `true`), the section starts in the collapsed state |
| `visible_when` | hash | Condition object. When the condition evaluates to false, the entire section (fieldset) is hidden. Same syntax as field conditions. See [Conditional Visibility](#conditional-visibility) |
| `disable_when` | hash | Condition object. When the condition evaluates to true, the entire section is visually disabled. Same syntax as field conditions. See [Conditional Disabling](#conditional-disabling) |
| `responsive` | hash | Responsive overrides per breakpoint (see below) |

**Example with conditional sections:**

```yaml
form:
  sections:
    - title: "Basic Information"
      columns: 2
      fields:
        - { field: name }
        - { field: stage, input_type: select }
    - title: "Revenue Details"
      columns: 2
      visible_when: { field: stage, operator: not_eq, value: lead }
      fields:
        - { field: expected_revenue, input_type: number, prefix: "$" }
        - { field: probability, input_type: slider }
    - title: "Closed Deal Info"
      disable_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
      fields:
        - { field: close_date, input_type: date }
        - { field: close_reason, input_type: textarea }
```

**Example with collapsible sections:**

```yaml
form:
  sections:
    - title: "Basic Information"
      columns: 2
      fields:
        - { field: name }
        - { field: email }
    - title: "Advanced Options"
      columns: 2
      collapsible: true
      collapsed: true
      fields:
        - { field: api_key }
        - { field: webhook_url }
```

**Example with responsive sections:**

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

#### Form Field Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | string | Model field name or FK column name |
| `input_type` | string | Override the default input type (see below) |
| `placeholder` | string | Placeholder text for the input |
| `autofocus` | boolean | Auto-focus this field when the form loads |
| `prefix` | string | Text prefix displayed before the input (e.g., `"$"` for currency) |
| `suffix` | string | Text suffix displayed after the input (e.g., `"kg"`, `"%"`) |
| `col_span` | integer | Number of grid columns this field spans (defaults to 1) |
| `hint` | string | Help text displayed below the input |
| `readonly` | boolean | Renders the field as read-only (visible but not editable) |
| `visible_when` | hash | Condition object. When the condition evaluates to false, the field is hidden (`display:none`). Supports field-value conditions and service conditions. See [Conditional Visibility](#conditional-visibility) |
| `disable_when` | hash | Condition object. When the condition evaluates to true, the field is visually disabled (opacity reduced, pointer-events disabled) but values are still submitted. Same syntax as `visible_when`. See [Conditional Disabling](#conditional-disabling) |
| `default` | string | Default value for new records. Supports dynamic defaults (see below) |
| `input_options` | hash | Type-specific input options (see below) |
| `options` | hash | Options passed to the renderer when field is shown in read-only mode |
| `hidden_on` | array/string | Hide field at specific breakpoints. Values: `"mobile"`, `"tablet"` |

**Example with new field attributes:**

```yaml
fields:
  - field: title
    placeholder: "Enter title..."
    autofocus: true
    col_span: 2
    hint: "A descriptive title for the deal"
  - field: value
    input_type: number
    prefix: "$"
    suffix: "USD"
    input_options:
      min: 0
      step: 0.01
    disable_when: { field: stage, operator: in, value: [closed_won, closed_lost] }
  - field: internal_code
    readonly: true
    hint: "Auto-generated, cannot be changed"
  - field: renewal_date
    visible_when: { field: stage, operator: not_in, value: [lead] }
  - field: created_at
    default: current_date
    hidden_on: mobile
```

#### Dynamic Defaults

The `default` attribute supports dynamic values that are resolved at form render time:

| Value | Description |
|-------|-------------|
| `"current_date"` | Sets the default to today's date |
| `"current_user_id"` | Sets the default to the current user's ID |

```yaml
- { field: start_date, default: current_date }
- { field: assigned_to_id, default: current_user_id }
```

#### Conditional Visibility

The `visible_when` attribute on **form fields** and **form sections** accepts a condition object that controls whether the element is shown. When the condition evaluates to false, the element is hidden with `display:none` — values are preserved in the DOM and still submitted with the form.

Two types of conditions are supported:

**Field-value conditions** reference another field on the same record and are evaluated client-side with JavaScript for instant reactivity:

```yaml
# Show only when stage is not "lead"
- field: expected_revenue
  visible_when: { field: stage, operator: not_in, value: [lead] }

# Show only when a boolean flag is true
- field: discount_reason
  visible_when: { field: discounted, operator: eq, value: true }
```

**Service conditions** are evaluated server-side (on initial render and via AJAX when field values change):

```yaml
# Show only when the record is persisted (has been saved)
- field: internal_code
  visible_when: { service: persisted_check }
```

See [Condition Operators](condition-operators.md) for the full list of supported operators.

#### Conditional Disabling

The `disable_when` attribute on **form fields** and **form sections** accepts a condition object with the same syntax as `visible_when`. When the condition evaluates to true, the element is visually disabled — rendered with reduced opacity (`opacity: 0.6`) and `pointer-events: none`. Unlike the HTML `disabled` attribute, this CSS-based approach means **values are still submitted** with the form.

```yaml
# Disable the value field when the deal is closed
- field: value
  input_type: number
  prefix: "$"
  disable_when: { field: stage, operator: in, value: [closed_won, closed_lost] }

# Disable notes when stage is blank
- field: notes
  input_type: textarea
  disable_when: { field: stage, operator: blank }
```

Field-value conditions use client-side JavaScript for instant reactivity. Service conditions are evaluated server-side.

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
| `slider` | Range slider input | - |
| `toggle` | Toggle switch (on/off) | - |
| `rating` | Star rating input | - |
| `file_upload` | File upload input with optional preview, drag-and-drop, and direct upload | `attachment` fields |

#### Input Options

Input options provide type-specific configuration for form inputs.

**Text / Textarea:**

| Option | Type | Description |
|--------|------|-------------|
| `rows` | integer | Number of visible rows (textarea only) |
| `max_length` | integer | Maximum character count |
| `show_counter` | boolean | Show a character counter below the input |

```yaml
- field: description
  input_type: textarea
  input_options:
    rows: 6
    max_length: 500
    show_counter: true
```

**Number:**

| Option | Type | Description |
|--------|------|-------------|
| `min` | number | Minimum allowed value |
| `max` | number | Maximum allowed value |
| `step` | number | Step increment for the input |

```yaml
- field: quantity
  input_type: number
  input_options:
    min: 1
    max: 1000
    step: 1
```

**Slider:**

| Option | Type | Description |
|--------|------|-------------|
| `min` | number | Minimum slider value |
| `max` | number | Maximum slider value |
| `step` | number | Step increment |
| `show_value` | boolean | Display the current value alongside the slider |

```yaml
- field: priority
  input_type: slider
  input_options:
    min: 1
    max: 10
    step: 1
    show_value: true
```

**Rating:**

| Option | Type | Description |
|--------|------|-------------|
| `max` | integer | Maximum number of stars |

```yaml
- field: satisfaction
  input_type: rating
  input_options:
    max: 5
```

**File Upload:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `preview` | boolean | `false` | Show a preview of the current file (image thumbnail or filename) |
| `drag_drop` | boolean | `false` | Enable drag-and-drop upload zone |
| `direct_upload` | boolean | `false` | Use Active Storage direct upload (uploads before form submission) |

```yaml
- field: photo
  input_type: file_upload
  input_options:
    preview: true
    drag_drop: true
    direct_upload: true
```

When `drag_drop` is enabled, the drop zone text adapts automatically: "Drop file here or click to browse" for single attachments, "Drop files here or click to browse" for multiple.

Attachment fields with existing files display a "Remove" checkbox on edit forms. When checked, the attachment is purged on save. For multiple attachments, each file has its own remove checkbox.

Attachment fields auto-resolve to `input_type: file_upload` — you only need to set `input_type` explicitly if you want to override the default.

**Select (enum):**

| Option | Type | Description |
|--------|------|-------------|
| `include_blank` | boolean/string | Show a blank option. `true` (default) adds an empty option, `false` removes it, a string uses custom text |
| `include_values` | hash | Role-based whitelist. Keys are role names, values are arrays of allowed enum values |
| `exclude_values` | hash | Role-based blacklist. Keys are role names, values are arrays of excluded enum values |

When both `include_values` and `exclude_values` are specified for the same role, `include_values` is applied first (whitelist), then `exclude_values` removes from the remaining set.

```yaml
# Viewers can only see active and archived statuses
- field: status
  input_type: select
  input_options:
    include_blank: false
    include_values:
      viewer: [active, archived]
    exclude_values:
      editor: [deleted]
```

**Association Select:**

| Option | Type | Description |
|--------|------|-------------|
| `include_blank` | boolean/string | Blank option text. Default: `"-- Select --"`. Set to `false` to remove |
| `scope` | string | Named scope to apply on the target model (e.g., `"active"`) |
| `filter` | hash | Hash of field-value pairs passed to `.where()` |
| `sort` | hash | Hash of field-direction pairs passed to `.order()` (e.g., `{ name: asc }`) |
| `label_method` | string | Method to call on each record for display text. Default: `to_label` |
| `group_by` | string | Group options by this field (renders `<optgroup>` tags) |
| `depends_on` | hash | Cascading select configuration (see below) |
| `scope_by_role` | hash | Role-based scope selection. Keys are role names, values are scope names or `"all"` |

```yaml
# Sorted, with custom label and blank text
- field: company_id
  input_type: association_select
  input_options:
    sort: { name: asc }
    label_method: full_name
    include_blank: "-- Choose company --"

# Grouped by industry
- field: company_id
  input_type: association_select
  input_options:
    sort: { name: asc }
    group_by: industry

# Scoped to active records
- field: contact_id
  input_type: association_select
  input_options:
    scope: active_contacts
    sort: { last_name: asc }
    label_method: full_name
```

**Dependent (cascading) selects:**

Use `depends_on` to create cascading select relationships. When the parent field changes, the dependent select options are refreshed via AJAX.

| Key | Type | Description |
|-----|------|-------------|
| `field` | string | Parent field name that this select depends on |
| `foreign_key` | string | FK column on the target model to filter by |
| `reset_strategy` | string | What happens to the current value when parent changes: `"clear"` (default) or `"keep_if_valid"` |

```yaml
- field: company_id
  input_type: association_select

- field: contact_id
  input_type: association_select
  input_options:
    depends_on:
      field: company_id
      foreign_key: company_id
    sort: { last_name: asc }
    label_method: full_name
```

**Role-based scope:**

Use `scope_by_role` to apply different scopes depending on the current user's role. The special value `"all"` means no scope is applied (returns all records).

```yaml
- field: company_id
  input_type: association_select
  input_options:
    scope_by_role:
      admin: all
      editor: active_companies
      viewer: my_companies
```

When `scope_by_role` is present, the `scope` option is ignored.

**Multi Select:**

For `has_many :through` associations, use `input_type: multi_select` to render a `<select multiple>`.

| Option | Type | Description |
|--------|------|-------------|
| `association` | string | Name of the `has_many :through` association |
| `scope` | string | Named scope on the target model |
| `sort` | hash | Ordering for the options |
| `label_method` | string | Method for display text |
| `min` | integer | Minimum required selections |
| `max` | integer | Maximum allowed selections |

```yaml
- field: tag_ids
  input_type: multi_select
  input_options:
    association: tags
    scope: active
    sort: { name: asc }
    min: 1
    max: 5
```

#### Divider Pseudo-Field

Use a divider to visually separate groups of fields within a section:

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

A divider with a `label` renders a labeled horizontal rule. A divider without a `label` renders a plain separator line.

#### Info Pseudo-Field

Use an info pseudo-field to add contextual help text within a section. The info text spans the full width of the grid and renders as a styled callout.

```yaml
fields:
  - { type: info, text: "Prices are in USD. Tax is calculated automatically." }
  - { field: price, input_type: number }
  - { field: tax_rate, input_type: number }
```

Info pseudo-fields work in both `form` and `show` sections.

#### Nested Fields

Use `type: nested_fields` to manage associated records inline within the parent form. This is useful for `has_many` relationships where you want to create, edit, and delete child records without leaving the form.

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
      columns:
        - { field: product_id, input_type: association_select }
        - { field: quantity, input_type: number }
        - { field: unit_price, input_type: number, prefix: "$" }
```

##### Nested Fields Section Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | string | - | Must be `"nested_fields"` |
| `association` | string | - | Name of the `has_many` association on the parent model |
| `allow_add` | boolean | `true` | Show a button to add new child records |
| `allow_remove` | boolean | `true` | Show a remove button on each child record row |
| `add_label` | string | `"Add"` | Label for the add button |
| `min` | integer | - | Minimum number of child records required |
| `max` | integer | - | Maximum number of child records allowed |
| `empty_message` | string | - | Message displayed when there are no child records |
| `columns` | array | - | Field definitions for each child record row (same format as form fields) |
| `sortable` | boolean or string | `false` | Enable drag-and-drop reordering. Set to `true` to use a `position` field, or a string to specify a custom position field name |

##### Sortable Nested Forms

When `sortable` is set, nested form rows get drag handles for reordering via HTML5 Drag and Drop. The position field is automatically hidden from the visible form fields and rendered as a hidden input that updates on drag. The position field is also auto-permitted in the controller.

```yaml
form:
  sections:
    - title: "Items"
      type: nested_fields
      association: line_items
      sortable: true
      fields:
        - { field: name }
        - { field: quantity, input_type: number }
```

The child model should have an integer position field, and the parent association should specify `order: { position: asc }` to load children in the correct order.

**Custom position field name:**

```yaml
sortable: "sort_order"
```

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
| `confirm` | boolean or hash | Show a confirmation dialog before executing (see [Confirm Per Role](#confirm-per-role)) |
| `confirm_message` | string | Custom text for the confirmation dialog |
| `style` | string | CSS style hint (e.g., `danger` for destructive actions) |
| `visible_when` | object | Condition controlling visibility (see below) |
| `disable_when` | object | Condition controlling disabled state. When true, the action button renders as a disabled span instead of a clickable link/button (see below) |

### Action Types

- **`built_in`** — standard CRUD actions (`show`, `edit`, `destroy`, `create`). Authorization checked via `PermissionEvaluator.can?`.
- **`custom`** — user-defined actions. Authorization checked via `can_execute_action?`. Dispatched to registered action classes. See [Custom Actions](../guides/custom-actions.md).

### Action Visibility

The `visible_when` attribute uses a [condition object](condition-operators.md) to conditionally show/hide the action based on record field values:

```yaml
visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
```

The condition is evaluated per-record via `ConditionEvaluator`. When omitted, the action is always visible (subject to permission checks).

### Action Disabling

The `disable_when` attribute uses the same [condition object](condition-operators.md) syntax as `visible_when`. When the condition evaluates to true, the action button is rendered as a disabled `<span>` instead of a clickable link or button:

```yaml
single:
  - name: send_invoice
    type: custom
    label: "Send Invoice"
    icon: mail
    disable_when: { field: value, operator: blank }
  - name: close_won
    type: custom
    label: "Close as Won"
    icon: check-circle
    visible_when: { field: stage, operator: not_in, value: [closed_won, closed_lost] }
    disable_when: { field: value, operator: lte, value: 0 }
```

An action can use both `visible_when` and `disable_when` together. The visibility condition is evaluated first — if the action is hidden, `disable_when` has no effect.

### Confirm Per Role

The `confirm` attribute supports role-based resolution. Instead of a simple boolean, you can use a hash with `except` or `only` keys to control which roles see the confirmation dialog:

```yaml
actions:
  single:
    # Confirm for everyone (existing behavior):
    - name: destroy
      type: built_in
      confirm: true

    # Confirm for all EXCEPT these roles (admin skips confirm):
    - name: archive
      type: custom
      confirm:
        except: [admin]

    # Confirm ONLY for these roles (others skip):
    - name: force_delete
      type: custom
      confirm:
        only: [viewer, sales_rep]
```

| Value | Behavior |
|-------|----------|
| `true` | Confirm for all roles (backward compatible) |
| `false` or omitted | No confirm for any role (backward compatible) |
| `{ except: [roles] }` | Confirm for all roles EXCEPT the listed ones |
| `{ only: [roles] }` | Confirm ONLY for the listed roles |

The resolved `confirm` value (true/false) is set on the action before rendering, so view templates work unchanged.

## Navigation

Navigation is configured through [view groups](view-groups.md), not directly on presenters. View groups control menu placement, ordering, and view switching between multiple presenters for the same model.

## Complete Example

```yaml
presenter:
  name: deal
  model: deal
  label: "Deals"
  slug: deals
  icon: dollar-sign

  index:
    default_view: table
    default_sort: { field: created_at, direction: desc }
    per_page: 25
    row_click: show
    empty_message: "No deals found. Create your first deal to get started."
    actions_position: dropdown
    table_columns:
      - field: title
        width: "30%"
        link_to: show
        sortable: true
        pinned: left
      - field: stage
        width: "15%"
        renderer: badge
        options:
          color_map:
            open: blue
            negotiation: yellow
            closed_won: green
            closed_lost: red
        sortable: true
      - field: value
        width: "15%"
        renderer: currency
        options:
          currency: "$"
          precision: 2
        sortable: true
        summary: sum
      - field: contact_name
        hidden_on: [mobile, tablet]
      - { field: updated_at, renderer: relative_date, hidden_on: mobile }

  show:
    layout:
      - section: "Deal Information"
        columns: 3
        responsive:
          tablet:
            columns: 2
          mobile:
            columns: 1
        fields:
          - { field: title, renderer: heading, col_span: 3 }
          - field: stage
            renderer: badge
            options:
              color_map:
                open: blue
                negotiation: yellow
                closed_won: green
                closed_lost: red
          - field: value
            renderer: currency
            options:
              currency: "$"
          - { field: email, renderer: email_link }
          - { field: website, renderer: url_link, hidden_on: mobile }
      - section: "Contacts"
        type: association_list
        association: contacts

  form:
    layout: tabs
    sections:
      - title: "Deal Details"
        columns: 2
        responsive:
          mobile:
            columns: 1
        fields:
          - field: title
            placeholder: "Deal title..."
            autofocus: true
            col_span: 2
            hint: "A short, descriptive name for the deal"
          - { field: stage, input_type: select }
          - field: value
            input_type: number
            prefix: "$"
            input_options:
              min: 0
              step: 0.01
            visible_when: { field: stage, operator: not_in, value: [lead] }
            disable_when: { field: stage, operator: in, value: [closed_won, closed_lost] }
          - { type: divider, label: "Relationships" }
          - { field: company_id, input_type: association_select }
          - { field: contact_id, input_type: association_select }
      - title: "Additional"
        collapsible: true
        visible_when: { field: stage, operator: not_eq, value: lead }
        fields:
          - field: probability
            input_type: slider
            input_options:
              min: 0
              max: 100
              step: 5
              show_value: true
            suffix: "%"
          - field: notes
            input_type: textarea
            input_options:
              rows: 4
              max_length: 2000
              show_counter: true
          - field: close_date
            input_type: date
            default: current_date
            visible_when: { service: persisted_check }

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
        disable_when: { field: value, operator: blank }
      - { name: destroy, type: built_in, icon: trash, confirm: true, style: danger }

  navigation:
    menu: main
    position: 3
```

Source: `lib/lcp_ruby/metadata/presenter_definition.rb`, `lib/lcp_ruby/presenter/layout_builder.rb`, `lib/lcp_ruby/presenter/column_set.rb`, `lib/lcp_ruby/presenter/action_set.rb`
