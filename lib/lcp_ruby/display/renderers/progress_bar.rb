module LcpRuby
  module Display
    module Renderers
      class ProgressBar < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          max = (options["max"] || 100).to_f
          pct = max > 0 ? ((value.to_f / max) * 100).clamp(0, 100) : 0
          view_context.content_tag(:div, class: "lcp-progress-bar") do
            view_context.content_tag(:div, "#{pct.round}%", class: "lcp-progress-fill", style: "width: #{pct}%;")
          end
        end
      end
    end
  end
end
