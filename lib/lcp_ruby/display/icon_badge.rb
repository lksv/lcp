module LcpRuby
  module Display
    class IconBadge < BaseRenderer
      def render(value, options = {}, record: nil, view_context: nil)
        icon = value.is_a?(Hash) ? value["icon"] : value.to_s
        color = value.is_a?(Hash) ? value["color"] : options["color"]
        return nil if icon.blank?

        style = color ? "color:#{color}" : nil
        opts = { class: "lcp-menu-badge lcp-menu-badge-icon", style: style }
        view_context.content_tag(:span, opts) do
          view_context.content_tag(:i, "", class: "lcp-icon lcp-icon-#{icon}")
        end
      end
    end
  end
end
