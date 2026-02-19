module LcpRuby
  module DisplayTemplateHelper
    # Render a display template for a record.
    #
    # @param record [ActiveRecord::Base] the record to render
    # @param model_definition [Metadata::ModelDefinition] the model definition (for template lookup)
    # @param template_name [String] the display template name (default: "default")
    # @param permission_evaluator [Authorization::PermissionEvaluator] for field-level access
    # @param link_to_record [Boolean] whether to wrap in a link
    # @param presenter_slug [String, nil] slug for building link (auto-resolved if nil)
    # @return [ActiveSupport::SafeBuffer] rendered HTML
    def render_display_template(record, model_definition, template_name: "default",
                                permission_evaluator: nil, link_to_record: false,
                                presenter_slug: nil)
      return "".html_safe if record.nil?

      template_def = model_definition.display_template(template_name)

      if template_def.nil?
        # Fallback: escaped to_label, optionally linked
        label = ERB::Util.html_escape(record.respond_to?(:to_label) ? record.to_label : record.to_s)
        return wrap_in_link(label, record, presenter_slug, model_definition) if link_to_record
        return label
      end

      case template_def.form
      when :structured
        render_structured_template(record, model_definition, template_def, permission_evaluator,
                                   link_to_record, presenter_slug)
      when :renderer
        render_renderer_template(record, template_def)
      when :partial
        render partial: template_def.partial, locals: { record: record }
      end
    end

    private

    def render_structured_template(record, model_definition, template_def, permission_evaluator,
                                   link_to_record, presenter_slug)
      resolver = build_template_field_resolver(model_definition, permission_evaluator)

      title_text = resolver ? resolver.resolve(record, template_def.template) : template_def.template
      title_html = ERB::Util.html_escape(title_text.to_s)
      title_html = wrap_in_link(title_html, record, presenter_slug, model_definition) if link_to_record

      parts = []

      if template_def.icon.present?
        parts << content_tag(:span, template_def.icon, class: "lcp-display-template__icon")
      end

      parts << content_tag(:span, title_html, class: "lcp-display-template__title")

      if template_def.subtitle.present?
        subtitle_text = resolver ? resolver.resolve(record, template_def.subtitle) : template_def.subtitle
        parts << content_tag(:span, ERB::Util.html_escape(subtitle_text.to_s),
                             class: "lcp-display-template__subtitle")
      end

      if template_def.badge.present?
        badge_text = resolver ? resolver.resolve(record, template_def.badge) : template_def.badge
        parts << content_tag(:span, ERB::Util.html_escape(badge_text.to_s),
                             class: "lcp-display-template__badge")
      end

      content_tag(:div, safe_join(parts), class: "lcp-display-template")
    end

    def render_renderer_template(record, template_def)
      renderer = LcpRuby::Display::RendererRegistry.renderer_for(template_def.renderer)
      if renderer
        # Note: passes the whole record as `value` (not a single field value)
        renderer.render(record, template_def.options, record: record, view_context: self)
      else
        ERB::Util.html_escape(record.respond_to?(:to_label) ? record.to_label : record.to_s)
      end
    end

    def build_template_field_resolver(model_definition, permission_evaluator)
      return nil unless permission_evaluator
      Presenter::FieldValueResolver.new(model_definition, permission_evaluator)
    end

    def wrap_in_link(content, record, presenter_slug, model_definition)
      slug = presenter_slug || resolve_presenter_slug_for(model_definition.name)
      if slug
        link_to(content, lcp_ruby.resource_path(lcp_slug: slug, id: record.id))
      else
        content
      end
    end

    def resolve_presenter_slug_for(model_name)
      presenters = Presenter::Resolver.presenters_for_model(model_name)
      presenters.first&.slug
    end
  end
end
