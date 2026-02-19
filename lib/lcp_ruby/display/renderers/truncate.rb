module LcpRuby
  module Display
    module Renderers
      class Truncate < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          max = (options["max"] || 50).to_i
          text = value.to_s
          if text.length > max
            view_context.content_tag(:span, view_context.truncate(text, length: max), title: text)
          else
            text
          end
        end
      end
    end
  end
end
