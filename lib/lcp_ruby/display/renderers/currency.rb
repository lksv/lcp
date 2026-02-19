module LcpRuby
  module Display
    module Renderers
      class Currency < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          opts = {}
          opts[:unit] = options["currency"] if options["currency"]
          opts[:precision] = options["precision"].to_i if options["precision"]
          view_context.number_to_currency(value, **opts)
        end
      end
    end
  end
end
