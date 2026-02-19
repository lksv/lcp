module LcpRuby
  module Display
    module Renderers
      class BooleanIcon < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          true_icon = options["true_icon"] || "Yes"
          false_icon = options["false_icon"] || "No"
          css_class = value ? "lcp-bool-true" : "lcp-bool-false"
          view_context.content_tag(:span, value ? true_icon : false_icon, class: css_class)
        end
      end
    end
  end
end
