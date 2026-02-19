module LcpRuby
  module Display
    module Renderers
      class PhoneLink < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          view_context.link_to(value, "tel:#{value}")
        end
      end
    end
  end
end
