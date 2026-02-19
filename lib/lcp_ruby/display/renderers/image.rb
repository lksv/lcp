module LcpRuby
  module Display
    module Renderers
      class Image < BaseRenderer
        SIZES = { "small" => "48px", "medium" => "120px", "large" => "240px" }.freeze

        def render(value, options = {}, record: nil, view_context: nil)
          return nil if value.blank?

          size = options["size"] || "medium"
          max_width = SIZES[size.to_s] || SIZES["medium"]
          view_context.tag.img(src: value, style: "max-width: #{max_width}; height: auto;", alt: "")
        end
      end
    end
  end
end
