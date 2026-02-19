module LcpRuby
  module Display
    module Renderers
      class Code < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          view_context.content_tag(:code, value, class: "lcp-code")
        end
      end
    end
  end
end
