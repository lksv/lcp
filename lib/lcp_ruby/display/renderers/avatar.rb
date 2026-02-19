module LcpRuby
  module Display
    module Renderers
      class Avatar < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          return nil if value.blank?

          avatar_size = options["size"] || "32"
          view_context.tag.img(src: value, class: "lcp-avatar", style: "width: #{avatar_size}px; height: #{avatar_size}px;", alt: "")
        end
      end
    end
  end
end
