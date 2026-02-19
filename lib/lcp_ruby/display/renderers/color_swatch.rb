module LcpRuby
  module Display
    module Renderers
      class ColorSwatch < BaseRenderer
        SAFE_COLOR_PATTERN = %r{\A(
          \#[0-9a-fA-F]{3,8}                    | # hex colors
          [a-zA-Z]+                              | # named colors
          rgba?\(\s*[\d.,\s%]+\s*\)              | # rgb/rgba
          hsla?\(\s*[\d.,\s%]+\s*\)                # hsl/hsla
        )\z}x

        def render(value, options = {}, record: nil, view_context: nil)
          return nil if value.blank?

          safe_color = value.to_s.match?(SAFE_COLOR_PATTERN) ? value.to_s : "#ccc"

          view_context.content_tag(:span, class: "lcp-color-swatch") do
            view_context.content_tag(:span, "", style: "display:inline-block;width:1em;height:1em;background:#{safe_color};border:1px solid #ccc;border-radius:2px;vertical-align:middle;margin-right:0.25em;") +
              value.to_s
          end
        end
      end
    end
  end
end
