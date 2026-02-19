module LcpRuby
  module Display
    module Renderers
      class RelativeDate < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          if value.respond_to?(:strftime)
            "#{view_context.time_ago_in_words(value)} ago"
          else
            value
          end
        end
      end
    end
  end
end
