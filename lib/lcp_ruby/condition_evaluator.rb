module LcpRuby
  class ConditionEvaluator
    MAX_NESTING_DEPTH = 20

    class << self
      # Builds a Regexp with a timeout to prevent ReDoS
      def safe_regexp(pattern)
        Regexp.new(pattern, timeout: 1)
      rescue RegexpError
        /\A(?!)\z/
      end

      # Returns the condition type: :field_value, :service, :compound, :collection, or nil
      def condition_type(condition)
        return nil unless condition.is_a?(Hash)

        normalized = condition.transform_keys(&:to_s)
        if normalized.key?("all") || normalized.key?("any") || normalized.key?("not")
          :compound
        elsif normalized.key?("collection")
          :collection
        elsif normalized.key?("field")
          :field_value
        elsif normalized.key?("service")
          :service
        end
      end

      # Returns true if the condition can be evaluated client-side
      # (flat field-value with literal value, no dot-path, no dynamic refs)
      def client_evaluable?(condition)
        return false unless condition.is_a?(Hash)

        normalized = condition.transform_keys(&:to_s)
        return false unless normalized.key?("field")
        return false if normalized["value"].is_a?(Hash)
        return false if normalized["field"].to_s.include?(".")

        true
      end

      # Unified recursive entry point: routes to the appropriate evaluator
      def evaluate_any(record, condition, context: {}, depth: 0)
        raise ArgumentError, "condition must be a Hash, got #{condition.class}" unless condition.is_a?(Hash)

        if depth > MAX_NESTING_DEPTH
          raise ConditionError, "condition nesting depth exceeded maximum of #{MAX_NESTING_DEPTH}"
        end

        normalized = condition.transform_keys(&:to_s)

        if normalized.key?("all")
          children = normalized["all"]
          if children.empty?
            if defined?(Rails) && Rails.respond_to?(:logger) && !Rails.env.production?
              Rails.logger.warn("[LcpRuby] Empty 'all' condition list evaluates to true (vacuous truth)")
            end
            return true
          end
          children.all? { |child| evaluate_any(record, child, context: context, depth: depth + 1) }
        elsif normalized.key?("any")
          children = normalized["any"]
          return false if children.empty?
          children.any? { |child| evaluate_any(record, child, context: context, depth: depth + 1) }
        elsif normalized.key?("not")
          child = normalized["not"]
          !evaluate_any(record, child, context: context, depth: depth + 1)
        elsif normalized.key?("collection")
          evaluate_collection(record, normalized, context: context, depth: depth)
        elsif normalized.key?("field")
          evaluate_field(record, normalized, context: context)
        elsif normalized.key?("service")
          evaluate_service(record, normalized, context: context)
        else
          raise ConditionError, "condition must contain 'field', 'service', 'all', 'any', 'not', or 'collection' key"
        end
      end

      private

      # Evaluates a flat field-value condition (already normalized)
      def evaluate_field(record, normalized, context: {})
        field = normalized["field"]
        operator = normalized["operator"]&.to_s
        raw_value = normalized["value"]

        raise ConditionError, "condition is missing required 'field' key" unless field
        raise ConditionError, "condition is missing required 'operator' key" if operator.blank?

        actual = resolve_field_path(record, field)
        value = resolve_value(raw_value, record, context)

        compare(actual, value, operator)
      end

      # Evaluates a service condition by looking up the service and calling it.
      # Passes context if the service accepts keyword arguments.
      def evaluate_service(record, normalized, context: {})
        service_key = normalized["service"]
        raise ConditionError, "condition is missing required 'service' key" unless service_key

        service = ConditionServiceRegistry.lookup(service_key)
        raise ConditionError, "condition service '#{service_key}' is not registered" unless service

        callable = service.respond_to?(:call) ? service.method(:call) : service
        accepts_context = callable.parameters.any? { |type, name| name == :context && (type == :key || type == :keyreq) }
        if accepts_context
          !!service.call(record, context: context)
        else
          !!service.call(record)
        end
      end

      # Evaluates a collection condition (has_many quantifier)
      def evaluate_collection(record, normalized, context: {}, depth: 0)
        collection_name = normalized["collection"]
        quantifier = normalized["quantifier"]&.to_s || "any"
        inner_condition = normalized["condition"]

        raise ConditionError, "collection condition is missing 'collection' key" unless collection_name
        raise ConditionError, "collection condition is missing inner 'condition'" unless inner_condition

        unless record.respond_to?(collection_name)
          raise ConditionError, "record does not respond to collection '#{collection_name}'"
        end

        items = record.send(collection_name)

        case quantifier
        when "any"
          items.any? { |item| evaluate_any(item, inner_condition, context: context, depth: depth + 1) }
        when "all"
          items.all? { |item| evaluate_any(item, inner_condition, context: context, depth: depth + 1) }
        when "none"
          items.none? { |item| evaluate_any(item, inner_condition, context: context, depth: depth + 1) }
        else
          raise ConditionError, "unknown collection quantifier '#{quantifier}' (expected: any, all, none)"
        end
      end

      # Resolves a dot-path field (e.g., "company.country.code") by traversing associations
      def resolve_field_path(record, field_path)
        segments = field_path.to_s.split(".")

        if segments.size == 1
          unless record.respond_to?(segments.first)
            raise ConditionError, "record does not respond to field '#{field_path}'"
          end
          return record.send(segments.first)
        end

        current = record
        segments.each_with_index do |segment, idx|
          unless current.respond_to?(segment)
            path_so_far = segments[0..idx].join(".")
            raise ConditionError, "cannot resolve field path '#{field_path}': " \
                                  "'#{current.class.name}' does not respond to '#{segment}' (at '#{path_so_far}')"
          end

          current = current.send(segment)

          # Intermediate nil means the chain is broken
          if current.nil? && idx < segments.size - 1
            path_so_far = segments[0..idx].join(".")
            raise ConditionError, "cannot resolve field path '#{field_path}': " \
                                  "intermediate value is nil at '#{path_so_far}'"
          end
        end

        current
      end

      # Resolves a value that may be a literal, field_ref, current_user, date, or service reference
      def resolve_value(value, record, context)
        return value unless value.is_a?(Hash)

        normalized = value.transform_keys(&:to_s)

        if normalized.key?("field_ref")
          resolve_field_path(record, normalized["field_ref"])
        elsif normalized.key?("current_user")
          user = context[:current_user]
          raise ConditionError, "current_user value reference requires context[:current_user]" unless user

          attr = normalized["current_user"].to_s
          unless user.respond_to?(attr)
            raise ConditionError, "current_user does not respond to '#{attr}'"
          end
          user.send(attr)
        elsif normalized.key?("date")
          resolve_date_reference(normalized["date"])
        elsif normalized.key?("lookup")
          resolve_lookup_value(normalized, record, context)
        elsif normalized.key?("service")
          resolve_value_service(normalized, record, context)
        else
          value
        end
      end

      def resolve_date_reference(ref)
        case ref.to_s
        when "today"
          Date.current
        when "now"
          Time.current
        else
          raise ConditionError, "unknown date reference '#{ref}' (expected: today, now)"
        end
      end

      def resolve_lookup_value(normalized, record, context)
        model_name = normalized["lookup"].to_s
        match = normalized["match"]
        pick = normalized["pick"]&.to_s

        raise ConditionError, "lookup value reference is missing required 'match' key" unless match.is_a?(Hash)
        raise ConditionError, "lookup value reference is missing required 'pick' key" unless pick

        # Resolve each match value (supports field_ref, current_user, date — reject nested lookup)
        resolved_match = match.transform_keys(&:to_s).each_with_object({}) do |(k, v), h|
          if v.is_a?(Hash)
            v_normalized = v.transform_keys(&:to_s)
            raise ConditionError, "nested lookup value references are not supported" if v_normalized.key?("lookup")
          end
          h[k] = resolve_value(v, record, context)
        end

        model_class = begin
          LcpRuby.registry.model_for(model_name)
        rescue LcpRuby::MetadataError
          raise ConditionError, "lookup value reference: model '#{model_name}' is not registered"
        end

        matched_record = model_class.find_by(resolved_match)
        raise ConditionError, "lookup value reference: no record found in '#{model_name}' matching #{resolved_match}" unless matched_record

        unless matched_record.respond_to?(pick)
          raise ConditionError, "lookup value reference: matched record does not respond to '#{pick}'"
        end

        matched_record.send(pick)
      end

      def resolve_value_service(normalized, record, context)
        service_key = normalized["service"]
        service = ConditionServiceRegistry.lookup(service_key)
        raise ConditionError, "value service '#{service_key}' is not registered" unless service

        raw_params = normalized["params"] || {}
        resolved_params = raw_params.transform_values { |v| resolve_value(v, record, context) }

        service.call(record, **resolved_params.transform_keys(&:to_sym))
      end

      # Compares actual vs expected using the given operator
      def compare(actual, value, operator)
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
          compare_values(actual, value) { |a, b| a > b }
        when "gte"
          compare_values(actual, value) { |a, b| a >= b }
        when "lt"
          compare_values(actual, value) { |a, b| a < b }
        when "lte"
          compare_values(actual, value) { |a, b| a <= b }
        when "present"
          actual.present?
        when "blank"
          actual.blank?
        when "starts_with"
          actual.to_s.start_with?(value.to_s)
        when "ends_with"
          actual.to_s.end_with?(value.to_s)
        when "contains"
          actual.to_s.downcase.include?(value.to_s.downcase)
        when "matches"
          value.is_a?(String) && actual.to_s.match?(safe_regexp(value))
        when "not_matches"
          value.is_a?(String) && !actual.to_s.match?(safe_regexp(value))
        else
          raise ConditionError, "unknown condition operator '#{operator}'"
        end
      end

      # Compares two values natively if both are the same comparable type,
      # falls back to .to_f for backward compatibility.
      # Returns false when either side is nil (nil is not comparable).
      def compare_values(actual, value)
        return false if actual.nil? || value.nil?

        if natively_comparable?(actual, value)
          yield(actual, value)
        else
          yield(actual.to_f, value.to_f)
        end
      end

      def natively_comparable?(a, b)
        (a.is_a?(Numeric) && b.is_a?(Numeric)) ||
          (a.is_a?(Date) && b.is_a?(Date)) ||
          (a.is_a?(Time) && b.is_a?(Time))
      end
    end
  end
end
