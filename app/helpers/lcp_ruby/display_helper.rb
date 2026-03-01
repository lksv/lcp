module LcpRuby
  module DisplayHelper
    def render_display_value(value, renderer_key, options = {}, field_def = nil, record: nil)
      return value if renderer_key.blank?

      renderer = LcpRuby::Display::RendererRegistry.renderer_for(renderer_key.to_s)
      renderer ? renderer.render(value, options || {}, record: record, view_context: self) : value
    end

    def empty_value_placeholder(value, presenter = nil)
      return value if value == false || value == 0

      if value.nil? || (value.respond_to?(:empty?) && value.empty?) || (value.is_a?(String) && value.strip.empty?)
        text = presenter&.options&.dig("empty_value") ||
               LcpRuby.configuration.empty_value ||
               I18n.t("lcp_ruby.empty_value", default: "\u2014")
        content_tag(:span, text, class: "lcp-empty-value")
      else
        value
      end
    end
  end
end
