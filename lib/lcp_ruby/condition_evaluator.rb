module LcpRuby
  class ConditionEvaluator
    class << self
      def evaluate(record, condition)
        raise ArgumentError, "condition must be a Hash, got #{condition.class}" unless condition.is_a?(Hash)

        condition = condition.transform_keys(&:to_s)
        field = condition["field"]
        operator = condition["operator"]&.to_s
        value = condition["value"]

        raise ConditionError, "condition is missing required 'field' key" unless field
        raise ConditionError, "condition is missing required 'operator' key" if operator.blank?
        raise ConditionError, "record does not respond to field '#{field}'" unless record.respond_to?(field)

        actual = record.send(field)

        case operator
        when "eq"
          actual.to_s == value.to_s
        when "not_eq", "neq"
          actual.to_s != value.to_s
        when "in"
          Array(value).map(&:to_s).include?(actual.to_s)
        when "not_in"
          !Array(value).map(&:to_s).include?(actual.to_s)
        when "gt"
          actual.to_f > value.to_f
        when "gte"
          actual.to_f >= value.to_f
        when "lt"
          actual.to_f < value.to_f
        when "lte"
          actual.to_f <= value.to_f
        when "present"
          actual.present?
        when "blank"
          actual.blank?
        when "matches"
          value.is_a?(String) && actual.to_s.match?(safe_regexp(value))
        when "not_matches"
          value.is_a?(String) && !actual.to_s.match?(safe_regexp(value))
        else
          raise ConditionError, "unknown condition operator '#{operator}'"
        end
      end

      # Builds a Regexp with a timeout to prevent ReDoS
      def safe_regexp(pattern)
        Regexp.new(pattern, timeout: 1)
      rescue RegexpError
        # Return a regexp that never matches on invalid patterns
        /\A(?!)\z/
      end

      # Returns the condition type: :field_value, :service, or nil
      def condition_type(condition)
        return nil unless condition.is_a?(Hash)

        normalized = condition.transform_keys(&:to_s)
        if normalized.key?("field")
          :field_value
        elsif normalized.key?("service")
          :service
        end
      end

      # Returns true if the condition can be evaluated client-side (field-value only)
      def client_evaluable?(condition)
        condition_type(condition) == :field_value
      end

      # Evaluates a service condition by looking up the service and calling it
      def evaluate_service(record, condition)
        raise ArgumentError, "condition must be a Hash, got #{condition.class}" unless condition.is_a?(Hash)

        normalized = condition.transform_keys(&:to_s)
        service_key = normalized["service"]
        raise ConditionError, "condition is missing required 'service' key" unless service_key

        service = ConditionServiceRegistry.lookup(service_key)
        raise ConditionError, "condition service '#{service_key}' is not registered" unless service

        !!service.call(record)
      end

      # Unified entry point: routes to evaluate or evaluate_service based on type
      def evaluate_any(record, condition)
        raise ArgumentError, "condition must be a Hash, got #{condition.class}" unless condition.is_a?(Hash)

        case condition_type(condition)
        when :field_value
          evaluate(record, condition)
        when :service
          evaluate_service(record, condition)
        else
          raise ConditionError, "condition must contain a 'field' or 'service' key"
        end
      end
    end
  end
end
