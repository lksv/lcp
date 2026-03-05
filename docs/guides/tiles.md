# Tiles View Guide

The tiles view displays index records as a responsive card grid instead of the default table layout. Each card shows an image, title, subtitle, description, and configurable fields.

## Quick Setup

```yaml
# config/lcp_ruby/presenters/products.yml
presenter:
  name: products
  model: product
  slug: products
  index:
    layout: tiles
    tile:
      title_field: name
      card_link: show
```

This renders a 3-column grid of cards where each card shows the `name` field as a linked title.

## Full Configuration

```yaml
presenter:
  name: products
  model: product
  slug: products
  index:
    layout: tiles
    per_page: 12
    per_page_options: [6, 12, 24, 48]
    tile:
      title_field: name
      subtitle_field: status
      subtitle_renderer: badge
      subtitle_options:
        color_map:
          active: green
          draft: gray
      description_field: description
      description_max_lines: 3
      image_field: cover_image
      columns: 4
      card_link: show
      actions: dropdown
      fields:
        - field: price
          label: Price
          renderer: currency
          options:
            currency: USD
        - field: category
          label: Category
        - field: created_at
          renderer: datetime
    sort_fields:
      - field: name
        label: Name
      - field: price
        label: Price
      - field: created_at
        label: Newest
    summary:
      enabled: true
      fields:
        - field: price
          function: sum
          label: Total Value
        - field: price
          function: avg
          label: Average Price
        - field: price
          function: count
          label: Total Products
```

## Tile Configuration Reference

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `title_field` | string | *required* | Field displayed as the card title |
| `subtitle_field` | string | — | Field displayed below the title |
| `subtitle_renderer` | string | — | Renderer for the subtitle (e.g., `badge`) |
| `subtitle_options` | hash | — | Options passed to the subtitle renderer |
| `description_field` | string | — | Field for card description (line-clamped) |
| `description_max_lines` | integer | 3 | Max lines before truncation |
| `image_field` | string | — | Field containing image URL or attachment |
| `columns` | integer | 3 | Number of grid columns (responsive breakpoints override) |
| `card_link` | string | — | `show` or `edit` — wraps the title in a link |
| `actions` | string | `dropdown` | `dropdown`, `inline`, or `none` |
| `fields` | array | — | Additional label-value fields in the card body |

### Tile Fields

Each entry in `fields` supports:

```yaml
fields:
  - field: price          # Field name (required)
    label: Price          # Display label (defaults to humanized field name)
    renderer: currency    # Optional renderer
    options:              # Renderer options
      currency: EUR
```

## Sort Dropdown

The sort dropdown appears in the filter bar when `sort_fields` is configured or when using tiles layout:

```yaml
sort_fields:
  - field: name
    label: Name
  - field: price
    label: Price
  - field: created_at
    label: Date Added
```

Users can select a field and toggle ascending/descending direction.

## Per-Page Selector

Shows a dropdown near pagination to change page size:

```yaml
per_page: 12
per_page_options: [6, 12, 24, 48]
```

The selector only appears when `per_page_options` is set. Values outside the allowed list are ignored.

## Summary Bar

Displays aggregate values computed on the filtered dataset (before pagination):

```yaml
summary:
  enabled: true
  fields:
    - field: price
      function: sum
      label: Total Revenue
    - field: price
      function: avg
      label: Average Deal Size
    - field: quantity
      function: min
      label: Minimum Quantity
```

Supported functions: `sum`, `avg`, `count`, `min`, `max`.

Each field can optionally specify a `renderer` and `options` for formatting.

## DSL Equivalent

```ruby
LcpRuby.define_presenter(:products) do
  model :product
  slug "products"

  index do
    layout :tiles
    per_page 12
    per_page_options 6, 12, 24, 48

    tile do
      title_field :name
      subtitle_field :status, renderer: :badge
      description_field :description, max_lines: 3
      image_field :cover_image
      columns 4
      card_link :show
      actions :dropdown
      field :price, label: "Price", renderer: "currency"
      field :category, label: "Category"
    end

    sort_field :name, label: "Name"
    sort_field :price, label: "Price"
    sort_field :created_at, label: "Newest"

    summary do
      enabled true
      field :price, function: :sum, label: "Total Value"
      field :price, function: :avg, label: "Average Price"
    end
  end
end
```

## Inheritance

When adding a tiles view alongside an existing table presenter, use `inherits:` to reuse the parent's show, form, search, and actions configuration. Only the `index` block needs to be defined:

```ruby
define_presenter :deal_tiles, inherits: :deal do
  label "Deals (Tiles)"
  slug "deals-tiles"

  index do
    layout :tiles
    default_sort :created_at, :desc
    per_page 12

    tile do
      title_field :title
      subtitle_field :stage, renderer: :badge, options: {
        color_map: { lead: "blue", qualified: "cyan", proposal: "orange",
                     negotiation: "purple", closed_won: "green", closed_lost: "red" }
      }
      columns 3
      card_link :show
      actions :dropdown
      field :value, label: "Value", renderer: :currency, options: { currency: "EUR" }
      field "company.name", label: "Company"
      field :progress, label: "Progress", renderer: :progress_bar
    end

    sort_field :title, label: "Title"
    sort_field :value, label: "Value"
    sort_field :created_at, label: "Created"

    per_page_options 12, 24, 48

    summary do
      field :value, function: :sum, label: "Total Value", renderer: :currency, options: { currency: "EUR" }
      field :value, function: :avg, label: "Avg Value", renderer: :currency, options: { currency: "EUR" }
      field :title, function: :count, label: "Deal Count"
    end
  end
end
```

Then add it to the view group YAML to enable the view switcher:

```yaml
# config/lcp_ruby/views/deals.yml
view_group:
  model: deal
  primary: deal
  views:
    - presenter: deal
      label: "Detailed"
      icon: maximize
    - presenter: deal_short
      label: "Short"
      icon: list
    - presenter: deal_tiles
      label: "Tiles"
      icon: grid
```

See [Presenter DSL Inheritance](../reference/presenter-dsl.md#inheritance) and [View Groups Guide](view-groups.md) for more details.

## Dot-Path Fields

Tile fields support dot-path notation to display fields from associated records:

```ruby
tile do
  title_field :full_name
  subtitle_field "company.name"   # traverses belongs_to :company
  field "company.name", label: "Company"
  field "contact.full_name", label: "Contact"
end
```

The engine automatically resolves associations and applies eager loading to prevent N+1 queries.

## CRM Example

The CRM example app (`examples/crm/`) demonstrates tiles for all four main entities:

| Presenter | Columns | Key Features |
|-----------|---------|--------------|
| `company_tiles` | 3 | Industry badges, phone/website links, aggregate counts (contacts, deals, deal value) |
| `contact_tiles` | 4 | Dot-path company name, email/phone links, boolean icon for active status |
| `deal_tiles` | 3 | Stage badges with color map, currency values, progress bars, summary bar (total/avg/count) |
| `activity_tiles` | 3 | Activity type badges, description with line clamping, dot-path company/contact names |

All tiles presenters inherit from their base presenter and are registered in view groups with a Detailed/Short/Tiles switcher.

## Responsive Behavior

The grid automatically adjusts:
- **> 1200px**: Uses the configured `columns` count
- **768px–1200px**: 2 columns
- **< 768px**: 1 column (stacked)

These breakpoints are applied via CSS media queries and require no configuration.

## Permissions

Tile fields respect the same permission system as table columns:
- Fields not in the role's `readable` list are hidden
- The `title_field`, `subtitle_field`, `description_field`, and `image_field` are also filtered

## Combining with Other Features

Tiles work with all existing index features:
- **Search**: Quick search and advanced filter builder
- **Saved Filters**: Preset and user-saved filters
- **Pagination**: Standard Kaminari pagination
- **View Groups**: Can be one view in a multi-view presenter group
- **View Slots**: All slot components (filter bar, toolbar, below_content) render normally

## Source

- `lib/lcp_ruby/metadata/presenter_definition.rb` — `index_layout`, `tiles?`, `tile_config`
- `app/views/lcp_ruby/resources/_tiles_index.html.erb` — tile grid template
- `app/views/lcp_ruby/slots/index/_sort_dropdown.html.erb` — sort dropdown
- `app/views/lcp_ruby/slots/index/_per_page_selector.html.erb` — per-page selector
- `app/views/lcp_ruby/slots/index/_summary_bar.html.erb` — summary bar
