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
      when "radio"
        render_radio_input(form, field_name, field_config, field_def)
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
      when "tree_select"
        render_tree_select(form, field_name, field_config)
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

    def render_radio_input(form, field_name, field_config, field_def)
      return form.text_field(field_name, placeholder: field_config["placeholder"]) unless field_def&.enum?

      input_options = field_config["input_options"] || {}
      values = field_def.enum_value_names
      values = apply_role_value_filters(values, input_options)
      i18n_scope = input_options["label_i18n_scope"]

      content_tag(:div, class: "lcp-radio-group") do
        values.map do |v|
          label_text = if i18n_scope
            I18n.t("#{i18n_scope}.#{v}", default: v.humanize)
          else
            v.humanize
          end
          content_tag(:label, class: "lcp-radio-label") do
            form.radio_button(field_name, v) + " ".html_safe + label_text
          end
        end.join.html_safe
      end
    end

    def render_select_input(form, field_name, field_config, field_def)
      return form.text_field(field_name, placeholder: field_config["placeholder"]) unless field_def&.enum?

      input_options = field_config["input_options"] || {}
      values = field_def.enum_value_names
      values = apply_role_value_filters(values, input_options)
      i18n_scope = input_options["label_i18n_scope"]
      options = values.map do |v|
        label = if i18n_scope
          I18n.t("#{i18n_scope}.#{v}", default: v.humanize)
        else
          v.humanize
        end
        [ label, v ]
      end
      include_blank = input_options.fetch("include_blank", true)

      form.select(field_name, options, include_blank: include_blank)
    end

    def render_association_select(form, field_name, field_config)
      assoc = field_config["association"]
      return form.number_field(field_name, placeholder: "ID") unless assoc&.lcp_model?

      input_options = field_config["input_options"] || {}
      include_blank = input_options.fetch("include_blank", I18n.t("lcp_ruby.select.include_blank"))

      html_attrs = {}

      if input_options["depends_on"]
        depends = input_options["depends_on"]
        html_attrs["data-lcp-depends-on"] = depends["field"]
        html_attrs["data-lcp-depends-fk"] = depends["foreign_key"]
        html_attrs["data-lcp-depends-reset"] = depends.fetch("reset_strategy", "clear")
      end

      # Inline create integration
      if input_options["allow_inline_create"] && respond_to?(:current_presenter) && current_presenter
        html_attrs["data-lcp-inline-create"] = "true"
        html_attrs["data-lcp-inline-create-url"] = lcp_ruby.inline_create_path(lcp_slug: current_presenter.slug)
        html_attrs["data-lcp-inline-create-form-url"] = lcp_ruby.inline_create_form_path(lcp_slug: current_presenter.slug)
        html_attrs["data-lcp-target-model"] = assoc.target_model
        html_attrs["data-lcp-label-method"] = input_options["label_method"] || ""
      end

      # Tom Select integration
      search_url = input_options["search"] ? select_options_url_for(field_name) : nil
      if input_options["search"] && search_url
        html_attrs["data-lcp-search"] = "remote"
        html_attrs["data-lcp-search-url"] = search_url
        html_attrs["data-lcp-per-page"] = input_options["per_page"] || 25
        html_attrs["data-lcp-min-query"] = input_options["min_query_length"] || 1
        # For remote mode, options are fetched on demand; render empty select
        options = []
        # If record already has a value, include that option so it displays correctly
        if form.object&.send(field_name).present?
          current_id = form.object.send(field_name)
          target_class = LcpRuby.registry.model_for(assoc.target_model)
          label_method = (input_options["label_method"] || resolve_default_label_method(assoc)).to_sym
          current_record = target_class.find_by(id: current_id)
          options = [ [ resolve_label(current_record, label_method), current_record.id ] ] if current_record
        end
      else
        html_attrs["data-lcp-search"] = "local"
        options = build_association_options(assoc, input_options, record: form.object)
      end

      # Legacy scope: inject disabled option for archived/deactivated records on edit
      if input_options["legacy_scope"] && form.object && !form.object.new_record?
        current_value = form.object.send(field_name)
        if current_value.present? && !option_ids_include?(options, current_value)
          legacy = resolve_legacy_record(assoc, input_options, current_value)
          if legacy
            options = inject_legacy_option(options, legacy)
          end
        end
      end

      if input_options["group_by"] && !input_options["search"]
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
      html_attrs["data-lcp-search"] = "local"

      display_mode = input_options["display_mode"]
      html_attrs["data-lcp-display-mode"] = display_mode if display_mode

      form.select(field_name, options, { include_blank: false }, html_attrs)
    end

    def build_association_options(assoc, input_options, record: nil)
      depends_on_values = extract_depends_on_from_record(input_options, record)
      oq = build_options_query(assoc, input_options, role: current_user_role, depends_on_values: depends_on_values)
      format_options_for_select(oq, input_options)
    end

    def extract_depends_on_from_record(input_options, record)
      depends_on = input_options["depends_on"]
      return {} unless depends_on && record

      parent_field = depends_on["field"]
      if parent_field && record.respond_to?(parent_field)
        parent_value = record.send(parent_field)
        parent_value.present? ? { parent_field => parent_value } : {}
      else
        {}
      end
    end

    def select_options_url_for(field_name)
      if respond_to?(:current_presenter) && current_presenter && respond_to?(:lcp_ruby)
        lcp_ruby.select_options_path(lcp_slug: current_presenter.slug, field: field_name)
      end
    rescue StandardError
      nil
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

    def current_user_role
      LcpRuby::Current.user&.send(LcpRuby.configuration.role_method).to_s
    rescue StandardError
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

    # Check if the current value exists in the flat or grouped options array
    def option_ids_include?(options, value)
      value_i = value.to_i
      if options.is_a?(Hash)
        # Grouped: { "group" => [[label, id], ...] }
        options.values.flatten(1).any? { |opt| opt.is_a?(Array) && opt[1].to_i == value_i }
      elsif options.is_a?(Array)
        options.any? { |opt| opt.is_a?(Array) && opt[1].to_i == value_i }
      else
        false
      end
    end

    # Inject a legacy (archived) option as disabled into the flat options list
    def inject_legacy_option(options, legacy_option)
      label, id = legacy_option
      disabled_opt = [ "#{label} (#{I18n.t('lcp_ruby.select.legacy_group')})", id, { disabled: "disabled", class: "lcp-legacy-option" } ]
      if options.is_a?(Array)
        options + [ disabled_opt ]
      else
        options
      end
    end

    def render_tree_select(form, field_name, field_config)
      assoc = field_config["association"]
      return form.number_field(field_name, placeholder: "ID") unless assoc&.lcp_model?

      input_options = field_config["input_options"] || {}
      parent_field = input_options["parent_field"] || "parent_id"
      label_method = (input_options["label_method"] || resolve_default_label_method(assoc)).to_sym
      max_depth = (input_options["max_depth"] || 10).to_i

      target_class = LcpRuby.registry.model_for(assoc.target_model)
      records = target_class.all
      records = records.order(input_options["sort"]) if input_options["sort"]

      tree_data = build_tree_data(records, parent_field, label_method, max_depth)
      current_value = form.object&.send(field_name)
      current_label = resolve_tree_current_label(records, current_value, label_method)
      include_blank = input_options.fetch("include_blank", I18n.t("lcp_ruby.select.include_blank"))

      hidden = form.hidden_field(field_name, data: {
        lcp_tree_select: true,
        lcp_tree_data: tree_data.to_json,
        lcp_tree_include_blank: include_blank
      })
      trigger = content_tag(:button, current_label || include_blank,
        type: "button", class: "lcp-tree-trigger", data: { lcp_tree_trigger: field_name })
      dropdown = content_tag(:div, "", class: "lcp-tree-dropdown", data: { lcp_tree_dropdown: field_name })

      content_tag(:div, hidden + trigger + dropdown, class: "lcp-tree-select-wrapper")
    end

    def build_tree_data(records, parent_field, label_method, max_depth, parent_id = nil, depth = 0)
      return [] if depth >= max_depth

      records.select { |r| r.send(parent_field) == parent_id }.map do |r|
        {
          id: r.id,
          label: resolve_label(r, label_method),
          children: build_tree_data(records, parent_field, label_method, max_depth, r.id, depth + 1)
        }
      end
    end

    def resolve_tree_current_label(records, current_value, label_method)
      return nil unless current_value.present?
      record = records.find { |r| r.id == current_value.to_i }
      record ? resolve_label(record, label_method) : nil
    end
  end
end
