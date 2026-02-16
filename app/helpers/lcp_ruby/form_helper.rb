module LcpRuby
  module FormHelper
    def render_form_input(form, field_name, input_type, field_config, field_def)
      input_options = field_config["input_options"] || {}

      case input_type.to_s
      when "text", "rich_text_editor"
        opts = { placeholder: field_config["placeholder"] }
        opts[:rows] = input_options["rows"] if input_options["rows"]
        opts[:maxlength] = input_options["max_length"] if input_options["max_length"]
        result = form.text_area(field_name, **opts.compact)
        if input_options["show_counter"] && input_options["max_length"]
          result += content_tag(:span, "", class: "lcp-char-counter",
            data: { target: field_name, max: input_options["max_length"] })
        end
        result
      when "select"
        render_select_input(form, field_name, field_config, field_def)
      when "number"
        opts = { step: input_options["step"] || "any", placeholder: field_config["placeholder"] }
        opts[:min] = input_options["min"] if input_options["min"]
        opts[:max] = input_options["max"] if input_options["max"]
        form.number_field(field_name, **opts.compact)
      when "date_picker", "date"
        form.date_field(field_name)
      when "datetime"
        form.datetime_local_field(field_name)
      when "boolean"
        form.check_box(field_name)
      when "association_select"
        render_association_select(form, field_name, field_config)
      when "email"
        form.email_field(field_name,
          placeholder: field_config["placeholder"],
          autofocus: field_config["autofocus"])
      when "tel"
        form.telephone_field(field_name,
          placeholder: field_config["placeholder"],
          autofocus: field_config["autofocus"])
      when "url"
        form.url_field(field_name,
          placeholder: field_config["placeholder"],
          autofocus: field_config["autofocus"])
      when "color"
        form.color_field(field_name)
      when "slider"
        render_slider_input(form, field_name, input_options)
      when "toggle"
        render_toggle_input(form, field_name)
      when "rating"
        render_rating_input(form, field_name, input_options)
      else
        form.text_field(field_name,
          placeholder: field_config["placeholder"],
          autofocus: field_config["autofocus"])
      end
    end

    private

    def render_select_input(form, field_name, field_config, field_def)
      if field_def&.enum?
        form.select(field_name,
          field_def.enum_value_names.map { |v| [ v.humanize, v ] },
          include_blank: true)
      else
        form.text_field(field_name, placeholder: field_config["placeholder"])
      end
    end

    def render_association_select(form, field_name, field_config)
      assoc = field_config["association"]
      if assoc&.lcp_model?
        target_class = LcpRuby.registry.model_for(assoc.target_model)
        options = target_class.all.map { |r| [ r.respond_to?(:to_label) ? r.to_label : r.to_s, r.id ] }
        form.select(field_name, options, include_blank: "-- Select --")
      else
        form.number_field(field_name, placeholder: "ID")
      end
    end

    def render_slider_input(form, field_name, input_options)
      min = input_options["min"] || 0
      max = input_options["max"] || 100
      step = input_options["step"] || 1
      show_value = input_options["show_value"]

      result = content_tag(:div, class: "lcp-slider-wrapper") do
        slider = form.range_field(field_name, min: min, max: max, step: step,
          class: "lcp-slider", data: { show_value: show_value })
        if show_value
          slider += content_tag(:span, "", class: "lcp-slider-value", data: { slider_target: field_name })
        end
        slider
      end
      result
    end

    def render_toggle_input(form, field_name)
      content_tag(:label, class: "lcp-toggle") do
        form.check_box(field_name, class: "lcp-toggle-input") +
          content_tag(:span, "", class: "lcp-toggle-slider")
      end
    end

    def render_rating_input(form, field_name, input_options)
      max = (input_options["max"] || 5).to_i
      form.select(field_name, (0..max).map { |i| [ i.to_s, i ] }, include_blank: false)
    end
  end
end
