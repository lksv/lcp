module LcpRuby
  module Display
    module Renderers
      class Percentage < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          precision = (options["precision"] || 1).to_i
          view_context.number_to_percentage(value, precision: precision)
        end
      end
    end
  end
end
