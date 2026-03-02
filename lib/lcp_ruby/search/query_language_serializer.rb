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
        "end" => "$",
        "in" => "in",
        "not_in" => "not in",
        "null" => "is null",
        "not_null" => "is not null",
        "present" => "is present",
        "blank" => "is blank",
        "true" => "is true",
        "false" => "is false",
        "scope" => nil # Scope refs handled specially
      }.freeze

      NO_VALUE_OPERATORS = %w[null not_null present blank true false].freeze

      # Serialize a condition tree to QL text.
      # @param tree [Hash] { "combinator", "conditions", "groups" }
      # @return [String]
      def self.serialize(tree)
        return "" if tree.blank?

        parts = []

        conditions = tree["conditions"] || []
        conditions.each do |condition|
          parts << serialize_condition(condition)
        end

        groups = tree["groups"] || []
        groups.each do |group|
          parts << serialize_group(group)
        end

        parts.compact.join(" and ")
      end

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
        elsif operator == "in" || operator == "not_in"
          serialize_list_condition(field, ql_op, value)
        else
          "#{field} #{ql_op} #{format_value(value)}"
        end
      end
      private_class_method :serialize_condition

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

      def self.serialize_group(group)
        combinator = group["combinator"] || "or"
        conditions = group["conditions"] || []
        return nil if conditions.empty?

        parts = conditions.map { |c| serialize_condition(c) }.compact
        return nil if parts.empty?

        inner = parts.join(" #{combinator} ")
        "(#{inner})"
      end
      private_class_method :serialize_group

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
