module LcpRuby
  # Shared helpers for building association select options.
  # Used by both FormHelper (server-side rendering) and
  # ResourcesController (AJAX JSON endpoint).
  module AssociationOptionsBuilder
    # Maximum number of options returned in non-search mode to prevent
    # unbounded result sets for large tables.
    MAX_SELECT_OPTIONS = 1000

    OptionsQuery = Struct.new(:query, :label_method, :disabled_ids, :target_class, keyword_init: true)

    private

    # Build a fully prepared query for association select options.
    # Applies scope, filter, depends_on, sort, and SELECT column optimization.
    # Returns an OptionsQuery struct ready for formatting.
    def build_options_query(assoc, input_options, role: nil, depends_on_values: {})
      target_class = LcpRuby.registry.model_for(assoc.target_model)
      query = apply_option_scope(target_class, input_options, role: role)
      query = query.where(input_options["filter"]) if input_options["filter"]

      depends_on = input_options["depends_on"]
      if depends_on && depends_on_values.present?
        fk = depends_on["foreign_key"]
        parent_value = depends_on_values[depends_on["field"]]
        query = query.where(fk => parent_value) if fk && parent_value.present?
      end

      query = query.order(input_options["sort"]) if input_options["sort"]

      label_method = (input_options["label_method"] || resolve_default_label_method(assoc)).to_sym
      disabled_ids = resolve_disabled_values(assoc, input_options)

      select_cols = optimize_select_columns(
        target_class, label_method, input_options["group_by"], sort: input_options["sort"]
      )
      query = query.select(*select_cols) if select_cols

      max = (input_options["max_options"] || MAX_SELECT_OPTIONS).to_i
      query = query.limit(max)

      OptionsQuery.new(query: query, label_method: label_method, disabled_ids: disabled_ids, target_class: target_class)
    end

    # Unified scope application for both server-side and AJAX select options.
    def apply_option_scope(target_class, input_options, role: nil)
      if input_options["scope_by_role"] && role.present?
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

    # Format OptionsQuery result as Rails select-compatible arrays.
    # Flat: [[label, id], [label, id, {disabled}], ...]
    # Grouped: { "group" => [[label, id], ...], ... }
    def format_options_for_select(oq, input_options)
      if input_options["group_by"]
        group_attr = input_options["group_by"]
        oq.query.group_by { |r| r.respond_to?(group_attr) ? r.send(group_attr) : "Other" }
          .sort_by { |group_name, _| group_name.to_s }
          .to_h
          .transform_values do |records|
            records.map do |r|
              option = [ resolve_label(r, oq.label_method), r.id ]
              option << { disabled: "disabled" } if oq.disabled_ids.include?(r.id)
              option
            end
          end
      else
        oq.query.map do |r|
          option = [ resolve_label(r, oq.label_method), r.id ]
          option << { disabled: "disabled" } if oq.disabled_ids.include?(r.id)
          option
        end
      end
    end

    # Format OptionsQuery result as JSON-compatible hashes.
    # Flat: [{value:, label:}, ...]
    # Grouped: [{group:, options: [{value:, label:}]}, ...]
    def format_options_for_json(oq, input_options)
      if input_options["group_by"]
        group_attr = input_options["group_by"]
        grouped = oq.query.group_by { |r| r.respond_to?(group_attr) ? r.send(group_attr) : "Other" }
        grouped.sort_by { |k, _| k.to_s }.map do |group_name, records|
          {
            group: group_name.to_s,
            options: records.map { |r|
              opt = { value: r.id, label: resolve_label(r, oq.label_method) }
              opt[:disabled] = true if oq.disabled_ids.include?(r.id)
              opt
            }
          }
        end
      else
        oq.query.map { |r|
          opt = { value: r.id, label: resolve_label(r, oq.label_method) }
          opt[:disabled] = true if oq.disabled_ids.include?(r.id)
          opt
        }
      end
    end

    def resolve_label(record, label_method)
      record.respond_to?(label_method) ? record.send(label_method) : record.to_s
    end

    def resolve_default_label_method(assoc)
      target_model_def = LcpRuby.loader.model_definition(assoc.target_model)
      method = target_model_def&.label_method
      method && method != "to_s" ? method : "to_label"
    rescue LcpRuby::MetadataError
      "to_label"
    end

    # Returns a Set of disabled IDs from static disabled_values or a named scope.
    def resolve_disabled_values(assoc, input_options)
      disabled = Set.new

      if input_options["disabled_values"].is_a?(Array)
        input_options["disabled_values"].each { |v| disabled << v.to_i }
      end

      if input_options["disabled_scope"]
        target_class = LcpRuby.registry.model_for(assoc.target_model)
        scope_name = input_options["disabled_scope"]
        if target_class.respond_to?(scope_name)
          target_class.send(scope_name).pluck(:id).each { |id| disabled << id }
        end
      end

      disabled
    end

    # Returns [label, id] if the record exists in the legacy scope but not in
    # the normal option set, nil otherwise.
    def resolve_legacy_record(assoc, input_options, current_value)
      return nil unless current_value.present?

      legacy_scope_name = input_options["legacy_scope"]
      return nil unless legacy_scope_name

      target_class = LcpRuby.registry.model_for(assoc.target_model)
      return nil unless target_class.respond_to?(legacy_scope_name)

      label_method = (input_options["label_method"] || resolve_default_label_method(assoc)).to_sym
      record = target_class.send(legacy_scope_name).find_by(id: current_value)
      return nil unless record

      [ resolve_label(record, label_method), record.id ]
    end

    # Returns array of columns to SELECT, or nil when optimization is not safe.
    # Optimization is skipped when any referenced column (label, group_by, sort)
    # is not a real DB column (e.g. computed method like :to_label).
    def optimize_select_columns(target_class, label_method, group_by, sort: nil)
      return nil unless target_class.respond_to?(:column_names)

      label_col = label_method.to_s
      return nil unless target_class.column_names.include?(label_col)

      cols = [ :id, label_col.to_sym ]

      if group_by
        return nil unless target_class.column_names.include?(group_by.to_s)
        cols << group_by.to_sym
      end

      if sort.is_a?(Hash)
        sort.each_key do |col|
          col_s = col.to_s
          return nil unless target_class.column_names.include?(col_s)
          cols << col_s.to_sym
        end
      end

      cols.uniq
    end
  end
end
