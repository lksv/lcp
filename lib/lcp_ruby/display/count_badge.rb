module LcpRuby
  module Display
    class CountBadge < BaseRenderer
      def render(value, options = {}, record: nil, view_context: nil)
        return nil unless value.is_a?(Integer) && value > 0

        view_context.content_tag(:span, value.to_s, class: "lcp-menu-badge")
      end
    end
  end
end
