# Display Types Guide

Display types control how field values are rendered in index tables and show pages. Each display type transforms raw data into a visual representation -- a badge, a progress bar, a formatted currency value, etc.

Display types are set on presenter fields via the `display` attribute (YAML) or `display:` option (DSL). They only affect read-only views (index columns and show fields), not form inputs.

For the full presenter attribute reference, see [Presenters Reference](../reference/presenters.md).

## Text Display Types

### `heading`

Renders the value as bold, prominent text. Use this for the primary identifier of a record (title, name).

**YAML:**

```yaml
# In show layout
show:
  layout:
    - section: "Project Details"
      fields:
        - { field: title, display: heading }
```

**Ruby DSL:**

```ruby
show do
  section "Project Details" do
    field :title, display: :heading
  end
end
```

**Display options:** none

**Appearance:** The value is rendered in a larger, bold font weight, visually distinguishing it from regular fields.

---

### `truncate`

Truncates long text to a maximum length and shows the full value in a tooltip on hover. Useful for description or notes columns in index tables.

**YAML:**

```yaml
index:
  table_columns:
    - field: description
      display: truncate
      display_options: { max: 80 }
```

**Ruby DSL:**

```ruby
index do
  column :description, display: :truncate, display_options: { max: 80 }
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max` | integer | 50 | Maximum number of characters before truncation |

**Appearance:** Text is cut at the specified length with an ellipsis (`...`). Hovering shows the full text in a browser tooltip.

---

### `code`

Renders the value in a monospace font inside a code block. Useful for identifiers, API keys, or technical values.

**YAML:**

```yaml
show:
  layout:
    - section: "Technical Details"
      fields:
        - { field: api_key, display: code }
        - { field: tracking_id, display: code }
```

**Ruby DSL:**

```ruby
show do
  section "Technical Details" do
    field :api_key, display: :code
    field :tracking_id, display: :code
  end
end
```

**Display options:** none

**Appearance:** Value is displayed in a monospace font with a subtle background, similar to inline `<code>` styling.

---

### `rich_text`

Renders the value as HTML content. Use this for fields stored as HTML or Markdown-rendered text (e.g., `rich_text` or `text` model fields).

**YAML:**

```yaml
show:
  layout:
    - section: "Content"
      fields:
        - { field: body, display: rich_text }
```

**Ruby DSL:**

```ruby
show do
  section "Content" do
    field :body, display: :rich_text
  end
end
```

**Display options:** none

**Appearance:** HTML is rendered directly, supporting headings, lists, bold/italic, links, and other standard HTML elements. Content is sanitized before display.

---

## Status & Boolean

### `badge`

Renders the value as a colored pill/badge. Ideal for enum or status fields where each value maps to a distinct color.

**YAML:**

```yaml
index:
  table_columns:
    - field: status
      display: badge
      display_options:
        color_map:
          draft: gray
          active: green
          paused: yellow
          archived: red

show:
  layout:
    - section: "Details"
      fields:
        - field: priority
          display: badge
          display_options:
            color_map:
              low: blue
              medium: yellow
              high: orange
              critical: red
```

**Ruby DSL:**

```ruby
index do
  column :status, display: :badge, display_options: {
    color_map: { draft: :gray, active: :green, paused: :yellow, archived: :red }
  }
end

show do
  section "Details" do
    field :priority, display: :badge, display_options: {
      color_map: { low: :blue, medium: :yellow, high: :orange, critical: :red }
    }
  end
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `color_map` | hash | `{}` | Maps field values to named colors |

**Available colors:** `gray`, `red`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`

**Appearance:** A rounded pill with a colored background and white or dark text. Values not present in `color_map` fall back to a neutral gray badge.

---

### `boolean_icon`

Renders a boolean value as a colored icon instead of "true"/"false". Provides a clear visual indicator for yes/no fields.

**YAML:**

```yaml
index:
  table_columns:
    - field: active
      display: boolean_icon

    - field: verified
      display: boolean_icon
      display_options:
        true_icon: check-circle
        false_icon: x-circle
```

**Ruby DSL:**

```ruby
index do
  column :active, display: :boolean_icon
  column :verified, display: :boolean_icon, display_options: {
    true_icon: "check-circle", false_icon: "x-circle"
  }
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `true_icon` | string | `"Yes"` | Text or icon label for `true` values |
| `false_icon` | string | `"No"` | Text or icon label for `false` values |

**Appearance:** `true` shows a green "Yes" label; `false` shows a red "No" label. Override the defaults with custom text via `display_options`.

---

## Numeric

### `currency`

Formats a numeric value as currency with symbol, thousands separator, and decimal places.

**YAML:**

```yaml
index:
  table_columns:
    - field: price
      display: currency
      display_options:
        currency: USD
        precision: 2

show:
  layout:
    - section: "Financial"
      fields:
        - field: total_revenue
          display: currency
          display_options:
            currency: EUR
```

**Ruby DSL:**

```ruby
index do
  column :price, display: :currency, display_options: { currency: "USD", precision: 2 }
end

show do
  section "Financial" do
    field :total_revenue, display: :currency, display_options: { currency: "EUR" }
  end
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `currency` | string | `"USD"` | Currency code (e.g., `"USD"`, `"EUR"`, `"GBP"`) |
| `precision` | integer | `2` | Number of decimal places |

**Appearance:** `1234.5` with USD renders as `$1,234.50`. The currency symbol is determined by the currency code.

---

### `percentage`

Formats a numeric value as a percentage.

**YAML:**

```yaml
show:
  layout:
    - section: "Performance"
      fields:
        - field: completion_rate
          display: percentage
          display_options:
            precision: 1
```

**Ruby DSL:**

```ruby
show do
  section "Performance" do
    field :completion_rate, display: :percentage, display_options: { precision: 1 }
  end
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `precision` | integer | `1` | Number of decimal places |

**Appearance:** `75.5` renders as `75.5%` (with precision 1) or `76%` (with precision 0).

---

### `number`

Formats a numeric value with delimiter and decimal precision. Useful for large numbers that benefit from thousands separators.

**YAML:**

```yaml
index:
  table_columns:
    - field: population
      display: number
      display_options:
        delimiter: ","
        precision: 0
```

**Ruby DSL:**

```ruby
index do
  column :population, display: :number, display_options: { delimiter: ",", precision: 0 }
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `delimiter` | string | `","` | Thousands separator character |
| `precision` | integer | `0` | Number of decimal places |

**Appearance:** `1234567` renders as `1,234,567`.

---

### `file_size`

Converts a byte count into a human-readable file size string.

**YAML:**

```yaml
index:
  table_columns:
    - field: attachment_size
      display: file_size
```

**Ruby DSL:**

```ruby
index do
  column :attachment_size, display: :file_size
end
```

**Display options:** none

**Appearance:** `1048576` renders as `1.0 MB`. `2048` renders as `2.0 KB`. Automatically selects the appropriate unit (Bytes, KB, MB, GB).

---

### `progress_bar`

Renders a numeric value as a visual progress bar. The value should represent a percentage (0-100) or a fraction of the `max` option.

**YAML:**

```yaml
index:
  table_columns:
    - field: completion
      display: progress_bar
      display_options:
        max: 100
```

**Ruby DSL:**

```ruby
index do
  column :completion, display: :progress_bar, display_options: { max: 100 }
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max` | integer | `100` | Maximum value (the bar is full at this value) |

**Appearance:** A horizontal bar filled proportionally to the value. A value of `75` with max `100` fills 75% of the bar. The numeric value may be displayed alongside the bar.

---

### `rating`

Renders a numeric value as a row of stars. Useful for review scores or priority levels.

**YAML:**

```yaml
index:
  table_columns:
    - field: score
      display: rating
      display_options:
        max: 5

show:
  layout:
    - section: "Review"
      fields:
        - field: score
          display: rating
          display_options:
            max: 10
```

**Ruby DSL:**

```ruby
index do
  column :score, display: :rating, display_options: { max: 5 }
end

show do
  section "Review" do
    field :score, display: :rating, display_options: { max: 10 }
  end
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max` | integer | `5` | Total number of stars |

**Appearance:** A row of star icons. Filled stars represent the value, empty stars represent the remaining capacity. A value of `3` with max `5` shows 3 filled stars and 2 empty stars.

---

## Date & Time

### `date`

Formats a date value according to a format string.

**YAML:**

```yaml
index:
  table_columns:
    - field: due_date
      display: date
      display_options:
        format: "%B %d, %Y"
```

**Ruby DSL:**

```ruby
index do
  column :due_date, display: :date, display_options: { format: "%B %d, %Y" }
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format` | string | `"%Y-%m-%d"` | Ruby `strftime` format string |

**Common formats:**

| Format | Example Output |
|--------|---------------|
| `"%Y-%m-%d"` | `2026-02-16` |
| `"%B %d, %Y"` | `February 16, 2026` |
| `"%d/%m/%Y"` | `16/02/2026` |
| `"%b %d"` | `Feb 16` |

**Appearance:** The date is displayed as formatted text.

---

### `datetime`

Formats a datetime value with both date and time components.

**YAML:**

```yaml
show:
  layout:
    - section: "Audit"
      fields:
        - field: created_at
          display: datetime
          display_options:
            format: "%B %d, %Y at %H:%M"
```

**Ruby DSL:**

```ruby
show do
  section "Audit" do
    field :created_at, display: :datetime, display_options: { format: "%B %d, %Y at %H:%M" }
  end
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format` | string | `"%Y-%m-%d %H:%M"` | Ruby `strftime` format string |

**Appearance:** The datetime is displayed as formatted text, e.g., `February 16, 2026 at 14:30`.

---

### `relative_date`

Displays a date or datetime as a human-readable relative time string.

**YAML:**

```yaml
index:
  table_columns:
    - field: updated_at
      display: relative_date
```

**Ruby DSL:**

```ruby
index do
  column :updated_at, display: :relative_date
end
```

**Display options:** none

**Appearance:** Renders as natural language relative to the current time: `"3 days ago"`, `"2 hours ago"`, `"just now"`, `"in 5 minutes"`. The exact date may be available in a tooltip on hover.

---

## Links

### `email_link`

Renders an email address as a clickable `mailto:` link.

**YAML:**

```yaml
index:
  table_columns:
    - field: email
      display: email_link

show:
  layout:
    - section: "Contact Info"
      fields:
        - { field: email, display: email_link }
```

**Ruby DSL:**

```ruby
index do
  column :email, display: :email_link
end

show do
  section "Contact Info" do
    field :email, display: :email_link
  end
end
```

**Display options:** none

**Appearance:** The email address is displayed as a clickable link. Clicking opens the user's default email client with the address pre-filled.

---

### `phone_link`

Renders a phone number as a clickable `tel:` link.

**YAML:**

```yaml
show:
  layout:
    - section: "Contact Info"
      fields:
        - { field: phone, display: phone_link }
```

**Ruby DSL:**

```ruby
show do
  section "Contact Info" do
    field :phone, display: :phone_link
  end
end
```

**Display options:** none

**Appearance:** The phone number is displayed as a clickable link. Clicking initiates a phone call on supported devices or opens a dialer application.

---

### `url_link`

Renders a URL as a clickable external link that opens in a new tab.

**YAML:**

```yaml
index:
  table_columns:
    - field: website
      display: url_link

show:
  layout:
    - section: "Company Info"
      fields:
        - { field: website, display: url_link }
```

**Ruby DSL:**

```ruby
index do
  column :website, display: :url_link
end

show do
  section "Company Info" do
    field :website, display: :url_link
  end
end
```

**Display options:** none

**Appearance:** The URL is displayed as a clickable link with `target="_blank"` and `rel="noopener noreferrer"`. An external link icon may be shown alongside the text.

---

## Visual

### `image`

Renders a URL or file path as an inline image.

**YAML:**

```yaml
show:
  layout:
    - section: "Media"
      fields:
        - field: photo_url
          display: image
          display_options:
            size: medium
```

**Ruby DSL:**

```ruby
show do
  section "Media" do
    field :photo_url, display: :image, display_options: { size: :medium }
  end
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `size` | string | `"medium"` | Image size: `"small"`, `"medium"`, or `"large"` |

**Size dimensions:**

| Size | Max Width |
|------|-----------|
| `small` | 48 px |
| `medium` | 120 px |
| `large` | 240 px |

**Appearance:** The image is rendered inline with the specified size constraint, maintaining aspect ratio.

---

### `avatar`

Renders an image URL as a circular avatar. Useful for profile photos or user thumbnails.

**YAML:**

```yaml
index:
  table_columns:
    - field: profile_image
      display: avatar
      display_options:
        size: 32

show:
  layout:
    - section: "Profile"
      fields:
        - field: profile_image
          display: avatar
          display_options:
            size: 64
```

**Ruby DSL:**

```ruby
index do
  column :profile_image, display: :avatar, display_options: { size: 32 }
end

show do
  section "Profile" do
    field :profile_image, display: :avatar, display_options: { size: 64 }
  end
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `size` | integer | `32` | Avatar diameter in pixels |

**Appearance:** A circular image cropped from the center with the specified diameter.

---

### `color_swatch`

Renders a hex color value as a small colored square alongside the hex code text.

**YAML:**

```yaml
index:
  table_columns:
    - field: brand_color
      display: color_swatch

show:
  layout:
    - section: "Branding"
      fields:
        - { field: primary_color, display: color_swatch }
        - { field: secondary_color, display: color_swatch }
```

**Ruby DSL:**

```ruby
index do
  column :brand_color, display: :color_swatch
end

show do
  section "Branding" do
    field :primary_color, display: :color_swatch
    field :secondary_color, display: :color_swatch
  end
end
```

**Display options:** none

**Appearance:** A small filled square showing the actual color, followed by the hex value text (e.g., `[##] #3B82F6`). Works with any valid CSS color string stored in the field.

---

### `link`

Renders the value as display text using the record's `to_label` method (if defined) or falls back to `to_s`. This is primarily used internally when rendering association references on show pages.

**YAML:**

```yaml
show:
  layout:
    - section: "Reference"
      fields:
        - { field: reference, display: link }
```

**Ruby DSL:**

```ruby
show do
  section "Reference" do
    field :reference, display: :link
  end
end
```

**Display options:** none

**Appearance:** Plain text output. If the value responds to `to_label`, that method is called; otherwise `to_s` is used.

---

## Complete Example

A product catalog presenter using a variety of display types:

**YAML:**

```yaml
presenter:
  name: product_catalog
  model: product
  label: "Products"
  slug: products
  icon: box

  index:
    default_sort: { field: name, direction: asc }
    per_page: 20
    table_columns:
      - { field: thumbnail, display: avatar, display_options: { size: 32 } }
      - { field: name, width: "25%", link_to: show, sortable: true }
      - { field: status, display: badge, display_options: { color_map: { draft: gray, active: green, discontinued: red } } }
      - { field: price, display: currency, display_options: { currency: USD, precision: 2 }, sortable: true }
      - { field: stock_count, display: number, display_options: { delimiter: "," } }
      - { field: rating, display: rating, display_options: { max: 5 } }
      - { field: updated_at, display: relative_date, sortable: true }

  show:
    layout:
      - section: "Product Information"
        columns: 2
        fields:
          - { field: name, display: heading }
          - { field: status, display: badge, display_options: { color_map: { draft: gray, active: green, discontinued: red } } }
          - { field: sku, display: code }
          - { field: price, display: currency, display_options: { currency: USD } }
          - { field: discount_percent, display: percentage, display_options: { precision: 1 } }
          - { field: rating, display: rating, display_options: { max: 5 } }
          - { field: in_stock, display: boolean_icon }
          - { field: brand_color, display: color_swatch }
      - section: "Media"
        fields:
          - { field: hero_image, display: image, display_options: { size: large } }
      - section: "Description"
        fields:
          - { field: description, display: rich_text }
      - section: "Links"
        columns: 2
        fields:
          - { field: website, display: url_link }
          - { field: support_email, display: email_link }
          - { field: support_phone, display: phone_link }

  navigation:
    menu: main
    position: 2
```

**Ruby DSL:**

```ruby
define_presenter :product_catalog do
  model :product
  label "Products"
  slug "products"
  icon "box"

  index do
    default_sort :name, :asc
    per_page 20
    column :thumbnail, display: :avatar, display_options: { size: 32 }
    column :name, width: "25%", link_to: :show, sortable: true
    column :status, display: :badge, display_options: {
      color_map: { draft: :gray, active: :green, discontinued: :red }
    }
    column :price, display: :currency, display_options: { currency: "USD", precision: 2 }, sortable: true
    column :stock_count, display: :number, display_options: { delimiter: "," }
    column :rating, display: :rating, display_options: { max: 5 }
    column :updated_at, display: :relative_date, sortable: true
  end

  show do
    section "Product Information", columns: 2 do
      field :name, display: :heading
      field :status, display: :badge, display_options: {
        color_map: { draft: :gray, active: :green, discontinued: :red }
      }
      field :sku, display: :code
      field :price, display: :currency, display_options: { currency: "USD" }
      field :discount_percent, display: :percentage, display_options: { precision: 1 }
      field :rating, display: :rating, display_options: { max: 5 }
      field :in_stock, display: :boolean_icon
      field :brand_color, display: :color_swatch
    end

    section "Media" do
      field :hero_image, display: :image, display_options: { size: :large }
    end

    section "Description" do
      field :description, display: :rich_text
    end

    section "Links", columns: 2 do
      field :website, display: :url_link
      field :support_email, display: :email_link
      field :support_phone, display: :phone_link
    end
  end

  navigation menu: :main, position: 2
end
```

## Quick Reference Table

| Display Type | Category | Has Options | Best For |
|-------------|----------|-------------|----------|
| `heading` | Text | No | Primary record identifier |
| `truncate` | Text | Yes (`max`) | Long text in table columns |
| `code` | Text | No | Identifiers, API keys |
| `rich_text` | Text | No | HTML content fields |
| `badge` | Status | Yes (`color_map`) | Enum/status fields |
| `boolean_icon` | Status | Yes (`true_icon`, `false_icon`) | Yes/no fields |
| `currency` | Numeric | Yes (`currency`, `precision`) | Money values |
| `percentage` | Numeric | Yes (`precision`) | Rates, completion |
| `number` | Numeric | Yes (`delimiter`, `precision`) | Large numbers |
| `file_size` | Numeric | No | Byte counts |
| `progress_bar` | Numeric | Yes (`max`) | Completion percentage |
| `rating` | Numeric | Yes (`max`) | Scores, reviews |
| `date` | Date/Time | Yes (`format`) | Date fields |
| `datetime` | Date/Time | Yes (`format`) | Datetime fields |
| `relative_date` | Date/Time | No | Timestamps |
| `email_link` | Links | No | Email addresses |
| `phone_link` | Links | No | Phone numbers |
| `url_link` | Links | No | External URLs |
| `image` | Visual | Yes (`size`) | Photos, uploads |
| `avatar` | Visual | Yes (`size`) | Profile pictures |
| `color_swatch` | Visual | No | Color hex values |
| `link` | Text | No | Association references |

## Advanced Display Features

### Dot-Notation Fields

Access fields on associated records using dot-notation. Works with `belongs_to`, `has_one`, and `has_many` associations.

**YAML:**

```yaml
index:
  table_columns:
    - { field: "company.name", sortable: true }
    - { field: "company.industry", display: badge }
```

**Ruby DSL:**

```ruby
index do
  column "company.name", sortable: true
  column "company.industry", display: :badge
end
```

Dot-path fields automatically trigger eager loading for the referenced associations, preventing N+1 queries. Permission checks are applied at each level of the path -- if the user cannot read the target field on the associated model, the value is hidden.

---

### Collection Display

Renders an array of values (typically from a `has_many` association via dot-notation) as a joined list.

**YAML:**

```yaml
index:
  table_columns:
    - field: "contacts.first_name"
      display: collection
      display_options:
        limit: 3
        separator: ", "
        overflow: "..."
```

**Ruby DSL:**

```ruby
index do
  column "contacts.first_name", display: :collection, display_options: {
    limit: 3, separator: ", ", overflow: "..."
  }
end
```

**Display options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `separator` | string | `", "` | String between items |
| `limit` | integer | none | Maximum number of items to display |
| `overflow` | string | `"..."` | Text appended when items exceed the limit |
| `item_display` | string | none | Display type to apply to each item before joining |
| `item_display_options` | hash | `{}` | Options passed to the item display type |

**Appearance:** Items are rendered as a comma-separated list (or with the specified separator). When the number of items exceeds the limit, the list is truncated and the overflow indicator is appended.

---

### Template Display

Interpolate multiple field values into a single display string using `{field_name}` syntax. Supports dot-notation references inside braces.

**YAML:**

```yaml
index:
  table_columns:
    - { field: "{first_name} {last_name}" }
    - { field: "{company.name}: {title}" }
```

**Ruby DSL:**

```ruby
index do
  column "{first_name} {last_name}"
  column "{company.name}: {title}"
end
```

Template fields check readability of every referenced field. If any reference is not readable by the current user, the entire column is hidden.

---

### Custom Renderers

Host applications can define custom display types by creating renderer classes in `app/renderers/`. See the [Custom Renderers Guide](custom-renderers.md) for details.

```ruby
# app/renderers/sparkline.rb
module LcpRuby::HostRenderers
  class Sparkline < LcpRuby::Display::BaseRenderer
    def render(value, options = {}, record: nil, view_context: nil)
      # Custom rendering logic
    end
  end
end
```

```yaml
table_columns:
  - { field: weekly_sales, display: sparkline }
```

---

## What's Next

- [Presenters Reference](../reference/presenters.md) -- Full attribute reference for presenter YAML
- [Presenter DSL Reference](../reference/presenter-dsl.md) -- Ruby DSL alternative for presenters
- [Custom Renderers](custom-renderers.md) -- Creating host app custom display renderers
- [Custom Types](custom-types.md) -- Types can set a default `display_type` (e.g., `color` type uses `color_swatch`)
