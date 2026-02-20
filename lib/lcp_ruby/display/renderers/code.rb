module LcpRuby
  module Display
    module Renderers
      class Code < BaseRenderer
        def render(value, options = {}, record: nil, view_context: nil)
          formatted = format_value(value, options)
          if formatted.include?("\n")
            view_context.content_tag(:pre, class: "lcp-code lcp-code-block") do
              view_context.content_tag(:code, formatted)
            end
          else
            view_context.content_tag(:code, formatted, class: "lcp-code")
          end
        end

        private

        def format_value(value, options)
          return value.to_s if value.blank?

          language = options["language"]&.to_s
          if language == "json" || (value.is_a?(String) && value.start_with?("{", "["))
            pretty_print_json(value)
          else
            value.to_s
          end
        end

        def pretty_print_json(value)
          raw = value.is_a?(String) ? value : value.to_json
          parsed = JSON.parse(raw)
          JSON.pretty_generate(parsed)
        rescue JSON::ParserError
          value.to_s
        end
      end
    end
  end
end
