module LcpRuby
  module Display
    module Renderers
      class Datetime < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          return value unless value.respond_to?(:strftime)

          format = options["format"] || "%Y-%m-%d %H:%M"
          value.strftime(format)
        end
      end
    end
  end
end
