module LcpRuby
  module Display
    module Renderers
      class UrlLink < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          view_context.link_to(value, value, target: "_blank", rel: "noopener")
        end
      end
    end
  end
end
