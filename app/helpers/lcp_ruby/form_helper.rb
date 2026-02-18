module LcpRuby
  module FormHelper
    include LcpRuby::AssociationOptionsBuilder

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
      when "multi_select"
        render_multi_select(form, field_name, field_config, field_def)
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
      return form.text_field(field_name, placeholder: field_config["placeholder"]) unless field_def&.enum?

      input_options = field_config["input_options"] || {}
      values = field_def.enum_value_names
      values = apply_role_value_filters(values, input_options)
      options = values.map { |v| [v.humanize, v] }
      include_blank = input_options.fetch("include_blank", true)

      form.select(field_name, options, include_blank: include_blank)
    end

    def render_association_select(form, field_name, field_config)
      assoc = field_config["association"]
      return form.number_field(field_name, placeholder: "ID") unless assoc&.lcp_model?

      input_options = field_config["input_options"] || {}
      options = build_association_options(assoc, input_options, record: form.object)
      include_blank = input_options.fetch("include_blank", "-- Select --")

      html_attrs = {}

      if input_options["depends_on"]
        depends = input_options["depends_on"]
        html_attrs["data-lcp-depends-on"] = depends["field"]
        html_attrs["data-lcp-depends-fk"] = depends["foreign_key"]
        html_attrs["data-lcp-depends-reset"] = depends.fetch("reset_strategy", "clear")
      end

      if input_options["group_by"]
        form.select(field_name, grouped_options_for_select(options, form.object&.send(field_name)),
                    { include_blank: include_blank }, html_attrs)
      else
        form.select(field_name, options, { include_blank: include_blank }, html_attrs)
      end
    end

    def render_multi_select(form, field_name, field_config, field_def)
      input_options = field_config["input_options"] || {}
      assoc = field_config["multi_select_association"]
      return form.text_field(field_name) unless assoc&.lcp_model?

      options = build_association_options(assoc, input_options, record: form.object)
      html_attrs = { multiple: true }
      html_attrs[:"data-min"] = input_options["min"] if input_options["min"]
      html_attrs[:"data-max"] = input_options["max"] if input_options["max"]

      form.select(field_name, options, { include_blank: false }, html_attrs)
    end

    def build_association_options(assoc, input_options, record: nil)
      target_class = LcpRuby.registry.model_for(assoc.target_model)
      query = apply_role_scope(target_class, input_options)
      query = query.where(input_options["filter"]) if input_options["filter"]

      # Filter dependent options by parent FK when record already has a value
      if input_options["depends_on"] && record
        depends = input_options["depends_on"]
        fk = depends["foreign_key"]
        parent_field = depends["field"]
        if fk && record.respond_to?(parent_field)
          parent_value = record.send(parent_field)
          query = query.where(fk => parent_value) if parent_value.present?
        end
      end

      query = query.order(input_options["sort"]) if input_options["sort"]

      label_method = (input_options["label_method"] || resolve_default_label_method(assoc)).to_sym

      # Only load :id + label column (+ group/sort columns) when all are real DB columns
      select_cols = optimize_select_columns(
        target_class, label_method, input_options["group_by"], sort: input_options["sort"]
      )
      query = query.select(*select_cols) if select_cols

      if input_options["group_by"]
        group_attr = input_options["group_by"]
        query.group_by { |r| r.respond_to?(group_attr) ? r.send(group_attr) : "Other" }
          .sort_by { |group_name, _| group_name.to_s }
          .to_h
          .transform_values do |records|
            records.map { |r| [resolve_label(r, label_method), r.id] }
          end
      else
        query.map { |r| [resolve_label(r, label_method), r.id] }
      end
    end

    def apply_role_value_filters(values, input_options)
      role = current_user_role

      if input_options["include_values"]&.key?(role)
        allowed = Array(input_options.dig("include_values", role))
        values = values.select { |v| allowed.include?(v) }
      end

      if input_options["exclude_values"]&.key?(role)
        denied = Array(input_options.dig("exclude_values", role))
        values = values.reject { |v| denied.include?(v) }
      end

      values
    end

    def apply_role_scope(target_class, input_options)
      if input_options["scope_by_role"]
        role = current_user_role
        role_scope = input_options.dig("scope_by_role", role)
        if role_scope && role_scope != "all" && target_class.respond_to?(role_scope)
          return target_class.send(role_scope)
        else
          return target_class.all
        end
      end

      if input_options["scope"] && target_class.respond_to?(input_options["scope"])
        target_class.send(input_options["scope"])
      else
        target_class.all
      end
    end

    def current_user_role
      LcpRuby::Current.user&.send(LcpRuby.configuration.role_method).to_s
    rescue
      ""
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
