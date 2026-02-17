module LcpRuby
  class ConditionEvaluator
    class << self
      def evaluate(record, condition)
        return true unless condition

        condition = condition.transform_keys(&:to_s) if condition.is_a?(Hash)
        field = condition["field"]
        operator = condition["operator"]&.to_s
        value = condition["value"]

        return true unless field && record.respond_to?(field)

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
          actual.to_s == value.to_s
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
        return true unless condition

        normalized = condition.transform_keys(&:to_s) if condition.is_a?(Hash)
        service_key = normalized["service"]
        return true unless service_key

        service = ConditionServiceRegistry.lookup(service_key)
        unless service
          Rails.logger.warn("[LcpRuby] Condition service '#{service_key}' not registered, defaulting to true")
          return true
        end

        !!service.call(record)
      end

      # Unified entry point: routes to evaluate or evaluate_service based on type
      def evaluate_any(record, condition)
        return true unless condition

        case condition_type(condition)
        when :field_value
          evaluate(record, condition)
        when :service
          evaluate_service(record, condition)
        else
          true
        end
      end
    end
  end
end
