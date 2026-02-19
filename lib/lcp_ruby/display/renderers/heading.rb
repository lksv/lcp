module LcpRuby
  module Display
    module Renderers
      class Heading < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          view_context.content_tag(:strong, value)
        end
      end
    end
  end
end
