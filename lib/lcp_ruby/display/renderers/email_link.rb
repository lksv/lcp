module LcpRuby
  module Display
    module Renderers
      class EmailLink < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          view_context.mail_to(value)
        end
      end
    end
  end
end
