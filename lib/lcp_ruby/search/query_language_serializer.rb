module LcpRuby
  module Search
    class QueryLanguageSerializer
      OPERATOR_TO_QL = {
        "eq" => "=",
        "not_eq" => "!=",
        "gt" => ">",
        "gteq" => ">=",
        "lt" => "<",
        "lteq" => "<=",
        "cont" => "~",
        "not_cont" => "!~",
        "start" => "^",
        "not_start" => "!^",
        "end" => "$",
        "not_end" => "!$",
        "in" => "in",
        "not_in" => "not in",
        "between" => "between",
        "null" => "is null",
        "not_null" => "is not null",
        "present" => "is present",
        "blank" => "is blank",
        "true" => "is true",
        "not_true" => "is not true",
        "false" => "is false",
        "not_false" => "is not false",
        "last_n_days" => "in",
        "this_week" => "is this_week",
        "this_month" => "is this_month",
        "this_quarter" => "is this_quarter",
        "this_year" => "is this_year",
        "scope" => nil # Scope refs handled specially
      }.freeze

      NO_VALUE_OPERATORS = OperatorRegistry::NO_VALUE_OPERATORS.map(&:to_s).freeze

      # Serialize a condition tree to QL text.
      # Supports both recursive format { "combinator", "children" }
      # and legacy format { "combinator", "conditions", "groups" }.
      # @param tree [Hash]
      # @return [String]
      def self.serialize(tree)
        return "" if tree.blank?

        # Detect legacy format and delegate
        if tree.key?("conditions") && !tree.key?("children")
          return serialize_legacy(tree)
        end

        serialize_node(tree, parent_combinator: nil)
      end

      # Recursively serialize a node (leaf condition or group).
      def self.serialize_node(node, parent_combinator:)
        return "" if node.blank?

        # Leaf condition
        if node.key?("field")
          return serialize_condition(node)
        end

        # Group node with children
        children = node["children"] || []
        return "" if children.empty?

        combinator = node["combinator"] || "and"
        parts = children.filter_map { |child| serialize_node(child, parent_combinator: combinator) }
        return "" if parts.empty?
        return parts.first if parts.size == 1

        joined = parts.join(" #{combinator} ")

        # Wrap in parentheses when nested inside a different combinator
        if parent_combinator && parent_combinator != combinator
          "(#{joined})"
        else
          joined
        end
      end
      private_class_method :serialize_node

      def self.serialize_condition(condition)
        field = condition["field"]
        operator = condition["operator"].to_s
        value = condition["value"]

        # Scope reference
        if operator == "scope" && field&.start_with?("@")
          return field
        end

        ql_op = OPERATOR_TO_QL[operator]
        return nil unless ql_op

        if NO_VALUE_OPERATORS.include?(operator)
          "#{field} #{ql_op}"
        elsif operator == "between"
          serialize_between_condition(field, value)
        elsif %w[in not_in last_n_days].include?(operator)
          serialize_list_condition(field, ql_op, value)
        else
          "#{field} #{ql_op} #{format_value(value)}"
        end
      end
      private_class_method :serialize_condition

      def self.serialize_between_condition(field, value)
        values = Array(value)
        return nil unless values.size == 2

        "#{field} >= #{format_value(values[0])} and #{field} <= #{format_value(values[1])}"
      end
      private_class_method :serialize_between_condition

      def self.serialize_list_condition(field, ql_op, value)
        if value.is_a?(String) && value.start_with?("{") && value.end_with?("}")
          # Relative date marker
          "#{field} #{ql_op} #{value}"
        else
          values = Array(value).map { |v| format_value(v) }
          "#{field} #{ql_op} [#{values.join(', ')}]"
        end
      end
      private_class_method :serialize_list_condition

      # Legacy format support: { "conditions" => [...], "groups" => [...] }
      def self.serialize_legacy(tree)
        parts = []

        conditions = tree["conditions"] || []
        conditions.each do |condition|
          parts << serialize_condition(condition)
        end

        groups = tree["groups"] || []
        groups.each do |group|
          combinator = group["combinator"] || "or"
          group_conditions = group["conditions"] || []
          next if group_conditions.empty?

          group_parts = group_conditions.filter_map { |c| serialize_condition(c) }
          next if group_parts.empty?

          inner = group_parts.join(" #{combinator} ")
          parts << "(#{inner})"
        end

        parts.compact.join(" and ")
      end
      private_class_method :serialize_legacy

      def self.format_value(value)
        if value.is_a?(String) && value.start_with?("{") && value.end_with?("}")
          # Relative date marker — keep as-is
          value
        elsif numeric_string?(value)
          value.to_s
        else
          "'#{escape_string(value.to_s)}'"
        end
      end
      private_class_method :format_value

      def self.numeric_string?(value)
        value.to_s =~ /\A-?\d+(\.\d+)?\z/
      end
      private_class_method :numeric_string?

      def self.escape_string(str)
        str.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")
      end
      private_class_method :escape_string
    end
  end
end
