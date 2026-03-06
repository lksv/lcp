module LcpRuby
  module Dsl
    class ConditionBuilder
      def initialize
        @conditions = []
      end

      # Adds a field condition proxy for building { field, operator, value } hashes
      def field(name)
        FieldConditionProxy.new(name.to_s, self)
      end

      # AND — all child conditions must be true
      def all(&block)
        builder = ConditionBuilder.new
        builder.instance_eval(&block)
        @conditions << { "all" => builder.to_conditions }
      end

      # OR — at least one child condition must be true
      def any(&block)
        builder = ConditionBuilder.new
        builder.instance_eval(&block)
        @conditions << { "any" => builder.to_conditions }
      end

      # NOT — negates the child condition
      def not_condition(&block)
        builder = ConditionBuilder.new
        builder.instance_eval(&block)
        children = builder.to_conditions
        child = children.size == 1 ? children.first : { "all" => children }
        @conditions << { "not" => child }
      end

      # Collection condition with quantifier
      def collection(name, quantifier: :any, &block)
        builder = ConditionBuilder.new
        builder.instance_eval(&block)
        children = builder.to_conditions
        inner = children.size == 1 ? children.first : { "all" => children }
        @conditions << {
          "collection" => name.to_s,
          "quantifier" => quantifier.to_s,
          "condition" => inner
        }
      end

      # Service condition
      def service(name)
        @conditions << { "service" => name.to_s }
      end

      # Returns the built conditions as an array
      def to_conditions
        @conditions
      end

      # Returns a single condition hash (wraps in 'all' if multiple)
      def to_condition
        case @conditions.size
        when 0
          raise ArgumentError, "condition block is empty"
        when 1
          @conditions.first
        else
          { "all" => @conditions }
        end
      end

      # Adds a raw condition hash (used by FieldConditionProxy)
      def add_condition(condition)
        @conditions << condition
      end

      # Returns a lookup value reference hash for use in condition values.
      # Usage: field(:price).lt(ConditionBuilder.lookup(:tax_limit, match: { key: "vat_a" }, pick: :threshold))
      def self.lookup(model, match:, pick:)
        normalized_match = match.transform_keys(&:to_s).transform_values { |v| v.is_a?(Hash) ? v.transform_keys(&:to_s) : v }
        { "lookup" => model.to_s, "match" => normalized_match, "pick" => pick.to_s }
      end

      # DSL entry point: builds a condition hash from a block
      def self.build(&block)
        builder = new
        builder.instance_eval(&block)
        builder.to_condition
      end
    end

    class FieldConditionProxy
      def initialize(field_name, builder)
        @field_name = field_name
        @builder = builder
      end

      def eq(value)
        emit("eq", value)
      end

      def not_eq(value)
        emit("not_eq", value)
      end

      def gt(value)
        emit("gt", value)
      end

      def gte(value)
        emit("gte", value)
      end

      def lt(value)
        emit("lt", value)
      end

      def lte(value)
        emit("lte", value)
      end

      def in(*values)
        values = values.flatten
        emit("in", values)
      end

      def not_in(*values)
        values = values.flatten
        emit("not_in", values)
      end

      def present
        emit_no_value("present")
      end

      def blank
        emit_no_value("blank")
      end

      def starts_with(value)
        emit("starts_with", value)
      end

      def ends_with(value)
        emit("ends_with", value)
      end

      def contains(value)
        emit("contains", value)
      end

      def matches(value)
        emit("matches", value)
      end

      def not_matches(value)
        emit("not_matches", value)
      end

      private

      def emit(operator, value)
        condition = { "field" => @field_name, "operator" => operator, "value" => normalize_value(value) }
        @builder.add_condition(condition)
      end

      def emit_no_value(operator)
        condition = { "field" => @field_name, "operator" => operator }
        @builder.add_condition(condition)
      end

      def normalize_value(value)
        case value
        when Hash
          value.transform_keys(&:to_s)
        when Array
          value.map { |v| v.is_a?(Hash) ? v.transform_keys(&:to_s) : v }
        else
          value
        end
      end
    end
  end
end
