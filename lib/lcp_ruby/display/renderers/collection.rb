module LcpRuby
  module Display
    module Renderers
      class Collection < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          items = Array(value)
          separator = options["separator"] || ", "
          limit = options["limit"]&.to_i
          overflow = options["overflow"] || "..."
          item_renderer_key = options["item_renderer"]
          item_options = options["item_options"] || {}

          truncated = limit && items.size > limit
          items = items.first(limit) if limit

          rendered = items.map do |item|
            if item_renderer_key.present?
              renderer = RendererRegistry.renderer_for(item_renderer_key)
              renderer ? renderer.render(item, item_options, record: record, view_context: view_context) : item.to_s
            else
              item.to_s
            end
          end

          parts = rendered.map { |r| r.respond_to?(:html_safe?) && r.html_safe? ? r : ERB::Util.html_escape(r) }
          parts << ERB::Util.html_escape(overflow) if truncated

          view_context.safe_join(parts, separator)
        end
      end
    end
  end
end
