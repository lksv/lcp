module LcpRuby
  module Display
    module Renderers
      class Rating < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          max = (options["max"] || 5).to_i
          val = value.to_i.clamp(0, max)
          filled = "&#9733;" * val
          empty = "&#9734;" * (max - val)
          view_context.content_tag(:span, (filled + empty).html_safe, class: "lcp-rating-display")
        end
      end
    end
  end
end
