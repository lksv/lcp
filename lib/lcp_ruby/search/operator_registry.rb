module LcpRuby
  module Search
    class OperatorRegistry
      NUMERIC_OPERATORS = %i[eq not_eq gt gteq lt lteq between present blank null not_null].freeze
      # Operators resolved at query time to absolute date ranges (not native Ransack predicates)
      RELATIVE_DATE_OPERATORS = %i[last_n_days this_week this_month this_quarter this_year].freeze

      TEMPORAL_OPERATORS = (NUMERIC_OPERATORS + RELATIVE_DATE_OPERATORS).freeze

      OPERATORS_BY_TYPE = {
        string:   %i[eq not_eq cont not_cont start not_start end not_end in not_in present blank null not_null],
        text:     %i[cont not_cont present blank null not_null],
        integer:  %i[eq not_eq gt gteq lt lteq between in not_in present blank null not_null],
        float:    NUMERIC_OPERATORS,
        decimal:  NUMERIC_OPERATORS,
        boolean:  %i[true not_true false not_false null not_null],
        date:     TEMPORAL_OPERATORS,
        datetime: TEMPORAL_OPERATORS,
        enum:     %i[eq not_eq in not_in present blank null not_null],
        uuid:     %i[eq not_eq in not_in present blank null not_null],
        array:    %i[array_contains array_overlaps present blank null not_null]
      }.freeze

      # Union of all operators across all types (used for validation and metadata)
      ALL_OPERATORS = OPERATORS_BY_TYPE.values.flatten.uniq.freeze

      # Operators that require no value input
      NO_VALUE_OPERATORS = %i[present blank null not_null true not_true false not_false
                              this_week this_month this_quarter this_year].freeze

      # Operators that accept multiple values
      MULTI_VALUE_OPERATORS = %i[in not_in].freeze

      # Operators that accept two values (from + to)
      RANGE_OPERATORS = %i[between].freeze

      # Operators that require a numeric parameter (e.g., "last N days" -> N)
      PARAMETERIZED_OPERATORS = %i[last_n_days].freeze

      # Returns the list of operator symbols for a given field type.
      def self.operators_for(field_type)
        OPERATORS_BY_TYPE[field_type.to_sym] || []
      end

      # Returns the i18n-backed label for an operator.
      def self.label_for(operator)
        I18n.t(
          "lcp_ruby.search.operators.#{operator}",
          default: operator.to_s.humanize
        )
      end

      # Returns true if the operator requires no value input.
      def self.no_value?(operator)
        NO_VALUE_OPERATORS.include?(operator.to_sym)
      end

      # Returns true if the operator accepts multiple values.
      def self.multi_value?(operator)
        MULTI_VALUE_OPERATORS.include?(operator.to_sym)
      end

      # Returns true if the operator accepts two values (from + to).
      def self.range?(operator)
        RANGE_OPERATORS.include?(operator.to_sym)
      end

      # Returns true if the operator requires a numeric parameter.
      def self.parameterized?(operator)
        PARAMETERIZED_OPERATORS.include?(operator.to_sym)
      end

      # Returns true if the operator is a relative date operator (resolved at query time).
      def self.relative_date?(operator)
        RELATIVE_DATE_OPERATORS.include?(operator.to_sym)
      end
    end
  end
end
