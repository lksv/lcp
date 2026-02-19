module LcpRuby
  module Display
    module Renderers
      class RichText < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          view_context.content_tag(:div, view_context.sanitize(value&.to_s), class: "rich-text")
        end
      end
    end
  end
end
