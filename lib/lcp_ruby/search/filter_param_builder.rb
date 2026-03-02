module LcpRuby
  module Search
    class FilterParamBuilder
      # Converts a condition tree (from the visual filter builder) into
      # Ransack-compatible params hash.
      #
      # Input format (condition tree):
      #   {
      #     "combinator" => "and",
      #     "conditions" => [
      #       { "field" => "title", "operator" => "cont", "value" => "Acme" },
      #       { "field" => "value", "operator" => "gteq", "value" => 10000 },
      #       { "field" => "company.name", "operator" => "cont", "value" => "Corp" }
      #     ],
      #     "groups" => [
      #       {
      #         "combinator" => "or",
      #         "conditions" => [
      #           { "field" => "stage", "operator" => "eq", "value" => "lead" },
      #           { "field" => "stage", "operator" => "eq", "value" => "prospect" }
      #         ]
      #       }
      #     ]
      #   }
      #
      # Output: Ransack-compatible params hash.
      def self.build(condition_tree)
        return {} if condition_tree.blank?

        result = {}
        custom_field_params = {}

        conditions = condition_tree["conditions"] || []
        conditions.each do |condition|
          field = condition["field"]
          operator = condition["operator"]&.to_sym
          value = condition["value"]

          # Separate custom field conditions
          if field&.start_with?("cf[")
            custom_field_params[field] = { operator: operator, value: value }
            next
          end

          merge_condition(result, field, operator, value)
        end

        # Handle groups (OR/AND sub-groups)
        groups = condition_tree["groups"] || []
        if groups.any?
          result["g"] ||= {}
          groups.each_with_index do |group, idx|
            group_params = build_group(group)
            result["g"][idx.to_s] = group_params if group_params.present?
          end
        end

        { ransack: result, custom_fields: custom_field_params }
      end

      # Converts association dot-path to Ransack underscore format.
      # e.g., "company.name" -> "company_name"
      def self.dot_path_to_ransack(path)
        path.tr(".", "_")
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

      private_class_method def self.build_group(group)
        combinator = group["combinator"] || "and"
        result = { "m" => combinator }
        conditions = {}

        (group["conditions"] || []).each do |condition|
          merge_condition(conditions, condition["field"], condition["operator"]&.to_sym, condition["value"])
        end

        result.merge(conditions)
      end
    end
  end
end
