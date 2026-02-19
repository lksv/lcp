module LcpRuby
  module Display
    module Renderers
      class Badge < BaseRenderer
        NAMED_COLORS = {
          "green" => "#28a745", "red" => "#dc3545", "blue" => "#007bff",
          "yellow" => "#ffc107", "orange" => "#fd7e14", "purple" => "#6f42c1",
          "gray" => "#6c757d", "teal" => "#20c997", "cyan" => "#17a2b8",
          "pink" => "#e83e8c"
        }.freeze

        def render(value, options = {}, record: nil, view_context: nil)
          color_map = options["color_map"] || {}
          color = color_map[value.to_s]
          style = badge_style(color)
          view_context.content_tag(:span, value, class: "badge", style: style)
        end

        private

        def badge_style(color)
          return nil unless color.present?

          bg = NAMED_COLORS[color.to_s] || color.to_s
          text_color = %w[yellow].include?(color.to_s) ? "#333" : "#fff"
          "background: #{bg}; color: #{text_color};"
        end
      end
    end
  end
end
