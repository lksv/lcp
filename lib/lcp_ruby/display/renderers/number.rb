module LcpRuby
  module Display
    module Renderers
      class Number < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          opts = {}
          opts[:delimiter] = options["delimiter"] if options["delimiter"]
          opts[:precision] = options["precision"].to_i if options["precision"]
          view_context.number_with_delimiter(value, **opts)
        end
      end
    end
  end
end
