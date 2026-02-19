module LcpRuby
  module Display
    module Renderers
      class Link < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          value.respond_to?(:to_label) ? value.to_label : value
        end
      end
    end
  end
end
