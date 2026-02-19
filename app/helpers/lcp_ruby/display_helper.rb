module LcpRuby
  module DisplayHelper
    def render_display_value(value, renderer_key, options = {}, field_def = nil, record: nil)
      return value if renderer_key.blank?

      renderer = LcpRuby::Display::RendererRegistry.renderer_for(renderer_key.to_s)
      renderer ? renderer.render(value, options || {}, record: record, view_context: self) : value
    end
  end
end
