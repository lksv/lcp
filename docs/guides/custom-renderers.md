# Custom Renderers

Custom renderers allow host applications to define their own display types beyond the built-in types. Renderers are auto-discovered from `app/renderers/` and can be used in presenter YAML/DSL configurations.

## Creating a Custom Renderer

1. Create a file in `app/renderers/` (e.g., `app/renderers/my_renderer.rb`)
2. Define a class under the `LcpRuby::HostRenderers` namespace
3. Extend `LcpRuby::Display::BaseRenderer`
4. Implement the `render` method

### Basic Example

```ruby
# app/renderers/markdown_display.rb
module LcpRuby::HostRenderers
  class MarkdownDisplay < LcpRuby::Display::BaseRenderer
    def render(value, options = {}, record: nil, view_context: nil)
      html = Kramdown::Document.new(value.to_s).to_html
      view_context&.sanitize(html)&.html_safe || html
    end
  end
end
```

### Usage in YAML

```yaml
table_columns:
  - { field: notes, display: markdown_display }

show:
  layout:
    - section: "Details"
      fields:
        - { field: notes, display: markdown_display }
```

### Usage in DSL

```ruby
index do
  column :notes, display: :markdown_display
end

show do
  section "Details" do
    field :notes, display: :markdown_display
  end
end
```

## The `render` Method

```ruby
def render(value, options = {}, record: nil, view_context: nil)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | Object | The resolved field value |
| `options` | Hash | `display_options` from presenter config |
| `record` | ActiveRecord::Base or nil | Full record for context-aware rendering |
| `view_context` | ActionView::Base or nil | Rails view context for HTML helpers |

The method should return an HTML-safe string. Use `view_context` to access Rails helpers like `content_tag`, `link_to`, `sanitize`, etc.

## Auto-Discovery

Renderers are automatically discovered from `app/renderers/**/*.rb` during engine initialization. The file path determines the registry key:

| File | Registry Key | Class Name |
|------|-------------|------------|
| `app/renderers/markdown.rb` | `markdown` | `LcpRuby::HostRenderers::Markdown` |
| `app/renderers/charts/sparkline.rb` | `charts/sparkline` | `LcpRuby::HostRenderers::Charts::Sparkline` |

## Full Example: Conditional Badge

A renderer that applies different badge styles based on field value:

```ruby
# app/renderers/conditional_badge.rb
module LcpRuby::HostRenderers
  class ConditionalBadge < LcpRuby::Display::BaseRenderer
    def render(value, options = {}, record: nil, view_context: nil)
      rules = options["rules"] || []
      rules.each do |rule|
        if rule.key?("default")
          sub_opts = rule.dig("default", "display_options") || {}
          display = rule.dig("default", "display") || "badge"
          return view_context.render_display_value(value, display, sub_opts) if view_context
          return value.to_s
        elsif matches?(value, rule["match"])
          sub_opts = rule["display_options"] || {}
          display = rule["display"] || "badge"
          return view_context.render_display_value(value, display, sub_opts) if view_context
          return value.to_s
        end
      end
      value.to_s
    end

    private

    def matches?(value, match)
      return false unless match.is_a?(Hash)

      if match.key?("eq") then value.to_s == match["eq"].to_s
      elsif match.key?("in") then Array(match["in"]).map(&:to_s).include?(value.to_s)
      elsif match.key?("not_eq") then value.to_s != match["not_eq"].to_s
      elsif match.key?("not_in") then !Array(match["not_in"]).map(&:to_s).include?(value.to_s)
      else false
      end
    end
  end
end
```

Usage in YAML:

```yaml
table_columns:
  - field: stage
    display: conditional_badge
    display_options:
      rules:
        - match: { in: [closed_won] }
          display: badge
          display_options: { color_map: { closed_won: green } }
        - match: { in: [closed_lost] }
          display: badge
          display_options: { color_map: { closed_lost: red } }
        - default:
            display: badge
```

## Usage in Display Templates

Custom renderers can also be referenced from model [display templates](../reference/models.md#display-templates) using the `renderer` form. This allows records to be rendered with a custom renderer in `association_list` sections:

**YAML:**

```yaml
model:
  name: contact
  display_templates:
    card:
      renderer: contact_card
```

**Ruby DSL:**

```ruby
define_model :contact do
  display_template :card, renderer: "contact_card"
end
```

The renderer class must be registered in `app/renderers/` as described above. When an `association_list` references `display: card`, the renderer receives the full record and renders it as HTML.

---

## What's Next

- [Display Types Guide](display-types.md) -- Built-in display types and advanced features
- [Display Templates](../reference/models.md#display-templates) -- Rich record representations using structured templates or custom renderers
- [Presenters Reference](../reference/presenters.md) -- Full presenter configuration reference
- [Extensibility Guide](extensibility.md) -- All extension mechanisms
