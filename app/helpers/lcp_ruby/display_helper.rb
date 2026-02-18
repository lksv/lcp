module LcpRuby
  module DisplayHelper
    def render_display_value(value, display_type, options = {}, field_def = nil, record: nil)
      return value if display_type.blank?

      options ||= {}
      case display_type.to_s
      when "heading"      then content_tag(:strong, value)
      when "badge"        then render_badge(value, options)
      when "collection"   then render_collection(value, options)
      when "truncate"     then render_truncate(value, options)
      when "boolean_icon" then render_boolean_icon(value, options)
      when "progress_bar" then render_progress_bar(value, options)
      when "image"        then render_image(value, options)
      when "avatar"       then render_avatar(value, options)
      when "currency"     then render_currency(value, options)
      when "percentage"   then render_percentage(value, options)
      when "number"       then render_formatted_number(value, options)
      when "date"         then render_date(value, options)
      when "datetime"     then render_datetime(value, options)
      when "relative_date" then render_relative_date(value)
      when "email_link"   then mail_to(value)
      when "phone_link"   then link_to(value, "tel:#{value}")
      when "url_link"     then link_to(value, value, target: "_blank", rel: "noopener")
      when "color_swatch" then render_color_swatch(value)
      when "rating"       then render_rating_display(value, options)
      when "code"         then content_tag(:code, value, class: "lcp-code")
      when "file_size"    then number_to_human_size(value.to_i)
      when "rich_text"    then content_tag(:div, sanitize(value&.to_s), class: "rich-text")
      when "link"         then value.respond_to?(:to_label) ? value.to_label : value
      else
        renderer = LcpRuby::Display::RendererRegistry.renderer_for(display_type.to_s)
        renderer ? renderer.render(value, options, record: record, view_context: self) : value
      end
    end

    private

    def render_collection(value, options)
      items = Array(value)
      separator = options["separator"] || ", "
      limit = options["limit"]&.to_i
      overflow = options["overflow"] || "..."
      item_display = options["item_display"]
      item_display_options = options["item_display_options"] || {}

      truncated = limit && items.size > limit
      items = items.first(limit) if limit

      rendered = items.map do |item|
        if item_display.present?
          render_display_value(item, item_display, item_display_options)
        else
          item.to_s
        end
      end

      parts = rendered.map { |r| r.respond_to?(:html_safe?) && r.html_safe? ? r : ERB::Util.html_escape(r) }
      parts << ERB::Util.html_escape(overflow) if truncated

      safe_join(parts, separator)
    end

    def render_badge(value, options)
      color_map = options["color_map"] || {}
      color = color_map[value.to_s]
      style = badge_style(color)
      content_tag(:span, value, class: "badge", style: style)
    end

    def badge_style(color)
      return nil unless color.present?

      color_map = {
        "green" => "#28a745", "red" => "#dc3545", "blue" => "#007bff",
        "yellow" => "#ffc107", "orange" => "#fd7e14", "purple" => "#6f42c1",
        "gray" => "#6c757d", "teal" => "#20c997", "cyan" => "#17a2b8",
        "pink" => "#e83e8c"
      }
      bg = color_map[color.to_s] || color.to_s
      text_color = %w[yellow].include?(color.to_s) ? "#333" : "#fff"
      "background: #{bg}; color: #{text_color};"
    end

    def render_truncate(value, options)
      max = (options["max"] || 50).to_i
      text = value.to_s
      if text.length > max
        content_tag(:span, truncate(text, length: max), title: text)
      else
        text
      end
    end

    def render_boolean_icon(value, options)
      true_icon = options["true_icon"] || "Yes"
      false_icon = options["false_icon"] || "No"
      css_class = value ? "lcp-bool-true" : "lcp-bool-false"
      content_tag(:span, value ? true_icon : false_icon, class: css_class)
    end

    def render_progress_bar(value, options)
      max = (options["max"] || 100).to_f
      pct = max > 0 ? ((value.to_f / max) * 100).clamp(0, 100) : 0
      content_tag(:div, class: "lcp-progress-bar") do
        content_tag(:div, "#{pct.round}%", class: "lcp-progress-fill", style: "width: #{pct}%;")
      end
    end

    def render_image(value, options)
      return nil if value.blank?

      size = options["size"] || "medium"
      sizes = { "small" => "48px", "medium" => "120px", "large" => "240px" }
      max_width = sizes[size.to_s] || sizes["medium"]
      tag.img(src: value, style: "max-width: #{max_width}; height: auto;", alt: "")
    end

    def render_avatar(value, options)
      return nil if value.blank?

      avatar_size = options["size"] || "32"
      tag.img(src: value, class: "lcp-avatar", style: "width: #{avatar_size}px; height: #{avatar_size}px;", alt: "")
    end

    def render_currency(value, options)
      opts = {}
      opts[:unit] = options["currency"] if options["currency"]
      opts[:precision] = options["precision"].to_i if options["precision"]
      number_to_currency(value, **opts)
    end

    def render_percentage(value, options)
      precision = (options["precision"] || 1).to_i
      number_to_percentage(value, precision: precision)
    end

    def render_formatted_number(value, options)
      opts = {}
      opts[:delimiter] = options["delimiter"] if options["delimiter"]
      opts[:precision] = options["precision"].to_i if options["precision"]
      number_with_delimiter(value, **opts)
    end

    def render_date(value, options)
      return value unless value.respond_to?(:strftime)

      format = options["format"] || "%Y-%m-%d"
      value.strftime(format)
    end

    def render_datetime(value, options)
      return value unless value.respond_to?(:strftime)

      format = options["format"] || "%Y-%m-%d %H:%M"
      value.strftime(format)
    end

    def render_relative_date(value)
      if value.respond_to?(:strftime)
        "#{time_ago_in_words(value)} ago"
      else
        value
      end
    end

    SAFE_COLOR_PATTERN = %r{\A(
      \#[0-9a-fA-F]{3,8}                    | # hex colors
      [a-zA-Z]+                              | # named colors
      rgba?\(\s*[\d.,\s%]+\s*\)              | # rgb/rgba
      hsla?\(\s*[\d.,\s%]+\s*\)                # hsl/hsla
    )\z}x

    def render_color_swatch(value)
      return nil if value.blank?

      safe_color = value.to_s.match?(SAFE_COLOR_PATTERN) ? value.to_s : "#ccc"

      content_tag(:span, class: "lcp-color-swatch") do
        content_tag(:span, "", style: "display:inline-block;width:1em;height:1em;background:#{safe_color};border:1px solid #ccc;border-radius:2px;vertical-align:middle;margin-right:0.25em;") +
          value.to_s
      end
    end

    def render_rating_display(value, options)
      max = (options["max"] || 5).to_i
      val = value.to_i.clamp(0, max)
      filled = "&#9733;" * val
      empty = "&#9734;" * (max - val)
      content_tag(:span, (filled + empty).html_safe, class: "lcp-rating-display")
    end
  end
end
