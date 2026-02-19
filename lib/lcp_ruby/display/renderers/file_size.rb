module LcpRuby
  module Display
    module Renderers
      class FileSize < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          view_context.number_to_human_size(value.to_i)
        end
      end
    end
  end
end
