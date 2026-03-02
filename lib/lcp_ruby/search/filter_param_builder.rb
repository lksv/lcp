module LcpRuby
  module Search
    class FilterParamBuilder
      # Converts a condition tree into Ransack-compatible params hash.
      #
      # Supports both recursive format:
      #   { "combinator" => "and", "children" => [leaf_or_group, ...] }
      #
      # and legacy format:
      #   { "combinator" => "and", "conditions" => [...], "groups" => [...] }
      #
      # Output: { ransack: { ... }, custom_fields: { ... } }
      def self.build(condition_tree)
        return {} if condition_tree.blank?

        # Detect legacy format and delegate
        if condition_tree.key?("conditions") && !condition_tree.key?("children")
          return build_legacy(condition_tree)
        end

        result = {}
        custom_field_params = {}
        group_counter = { value: 0 }

        # Set root combinator when it's not the default "and"
        root_combinator = condition_tree["combinator"] || "and"
        result["m"] = root_combinator if root_combinator != "and"

        children = condition_tree["children"] || []
        children.each do |child|
          if child.key?("field")
            # Leaf condition at top level
            extract_condition(child, result, custom_field_params)
          else
            # Nested group — emit as Ransack group
            result["g"] ||= {}
            idx = group_counter[:value].to_s
            group_counter[:value] += 1
            group_params = build_ransack_group(child, group_counter, custom_field_params)
            result["g"][idx] = group_params if group_params.present?
          end
        end

        { ransack: result, custom_fields: custom_field_params }
      end

      # Converts association dot-path to Ransack underscore format.
      # e.g., "company.name" -> "company_name"
      def self.dot_path_to_ransack(path)
        path.tr(".", "_")
      end

      private_class_method def self.extract_condition(condition, result, custom_field_params)
        field = condition["field"]
        operator = condition["operator"]&.to_sym
        value = condition["value"]

        if field&.start_with?("cf[")
          custom_field_params[field] = { operator: operator, value: value }
        else
          merge_condition(result, field, operator, value)
        end
      end

      private_class_method def self.build_ransack_group(node, group_counter, custom_field_params)
        combinator = node["combinator"] || "and"
        result = { "m" => combinator }
        children = node["children"] || []

        children.each do |child|
          if child.key?("field")
            extract_condition(child, result, custom_field_params)
          else
            # Nested sub-group
            result["g"] ||= {}
            idx = group_counter[:value].to_s
            group_counter[:value] += 1
            sub_params = build_ransack_group(child, group_counter, custom_field_params)
            result["g"][idx] = sub_params if sub_params.present?
          end
        end

        result
      end

      private_class_method def self.merge_condition(result, field, operator, value)
        return if field.blank? || operator.blank?

        ransack_field = dot_path_to_ransack(field)

        if OperatorRegistry.relative_date?(operator)
          expand_relative_date(result, ransack_field, operator, value)
        elsif OperatorRegistry.range?(operator)
          expand_between(result, ransack_field, value)
        else
          ransack_key = "#{ransack_field}_#{operator}"
          result[ransack_key] = value
        end
      end

      private_class_method def self.expand_between(result, field, value)
        return unless value.is_a?(Array) && value.size == 2

        result["#{field}_gteq"] = value[0]
        result["#{field}_lteq"] = value[1]
      end

      private_class_method def self.expand_relative_date(result, field, operator, value)
        today = Date.current

        case operator
        when :last_n_days
          n = value.to_i
          result["#{field}_gteq"] = n.days.ago.beginning_of_day.iso8601
        when :this_week
          result["#{field}_gteq"] = today.beginning_of_week.iso8601
          result["#{field}_lteq"] = today.end_of_week.iso8601
        when :this_month
          result["#{field}_gteq"] = today.beginning_of_month.iso8601
          result["#{field}_lteq"] = today.end_of_month.iso8601
        when :this_quarter
          result["#{field}_gteq"] = today.beginning_of_quarter.iso8601
          result["#{field}_lteq"] = today.end_of_quarter.iso8601
        when :this_year
          result["#{field}_gteq"] = today.beginning_of_year.iso8601
          result["#{field}_lteq"] = today.end_of_year.iso8601
        end
      end

      # Legacy format support: { "conditions" => [...], "groups" => [...] }
      private_class_method def self.build_legacy(condition_tree)
        result = {}
        custom_field_params = {}

        conditions = condition_tree["conditions"] || []
        conditions.each do |condition|
          extract_condition(condition, result, custom_field_params)
        end

        groups = condition_tree["groups"] || []
        if groups.any?
          result["g"] ||= {}
          groups.each_with_index do |group, idx|
            group_params = build_legacy_group(group, custom_field_params)
            result["g"][idx.to_s] = group_params if group_params.present?
          end
        end

        { ransack: result, custom_fields: custom_field_params }
      end

      private_class_method def self.build_legacy_group(group, custom_field_params)
        combinator = group["combinator"] || "and"
        result = { "m" => combinator }

        (group["conditions"] || []).each do |condition|
          extract_condition(condition, result, custom_field_params)
        end

        result
      end
    end
  end
end
