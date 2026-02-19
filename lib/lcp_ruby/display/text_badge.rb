module LcpRuby
  module Display
    class TextBadge < BaseRenderer
      def render(value, options = {}, record: nil, view_context: nil)
        text = value.is_a?(Hash) ? value["text"] : value.to_s
        color = value.is_a?(Hash) ? value["color"] : options["color"]
        return nil if text.blank?

        opts = { class: "lcp-menu-badge lcp-menu-badge-text" }
        opts[:style] = "background:#{color}" if color
        view_context.content_tag(:span, text, opts)
      end
    end
  end
end
