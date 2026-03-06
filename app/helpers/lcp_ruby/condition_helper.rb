module LcpRuby
  module ConditionHelper
    # Evaluates a condition (field-value, service, or compound) against a record
    def condition_met?(record, condition, context: {})
      return true unless condition
      ConditionEvaluator.evaluate_any(record, condition, context: context)
    end

    # Serializes a field-value condition into data attributes for client-side JS
    def condition_data_attrs(condition, prefix)
      return {} unless condition.is_a?(Hash)

      normalized = condition.transform_keys(&:to_s)
      return {} unless normalized.key?("field")

      attrs = {}
      attrs[:"data-lcp-#{prefix}-field"] = normalized["field"]
      attrs[:"data-lcp-#{prefix}-operator"] = normalized["operator"] if normalized["operator"]
      if normalized.key?("value")
        value = normalized["value"]
        attrs[:"data-lcp-#{prefix}-value"] = value.is_a?(Array) ? value.join(",") : value.to_s
      end
      attrs
    end

    # Builds combined data attributes for both visible_when and disable_when
    def conditional_data(config)
      attrs = {}
      service_types = []

      visible_when = config["visible_when"]
      disable_when = config["disable_when"]

      if visible_when.is_a?(Hash)
        if ConditionEvaluator.client_evaluable?(visible_when)
          attrs.merge!(condition_data_attrs(visible_when, "visible"))
        else
          service_types << "visible"
        end
      end

      if disable_when.is_a?(Hash)
        if ConditionEvaluator.client_evaluable?(disable_when)
          attrs.merge!(condition_data_attrs(disable_when, "disable"))
        else
          service_types << "disable"
        end
      end

      attrs[:"data-lcp-service-condition"] = service_types.join(",") if service_types.any?

      attrs
    end

    # Checks if any sections or fields in the presenter have non-client-evaluable conditions
    def service_conditions?(presenter_definition)
      sections = presenter_definition.form_config["sections"] || []
      sections.any? do |section|
        has_non_client_condition?(section) ||
          (section["fields"] || []).any? { |f| has_non_client_condition?(f) }
      end
    end

    # Evaluates visible_when condition, returning true if no condition is set
    def condition_visible?(config, record, context: condition_context)
      cond = config["visible_when"]
      return true unless cond.is_a?(Hash)
      condition_met?(record, cond, context: context)
    end

    # Evaluates disable_when condition, returning false if no condition is set
    def condition_disabled?(config, record, context: condition_context)
      cond = config["disable_when"]
      return false unless cond.is_a?(Hash)
      condition_met?(record, cond, context: context)
    end

    private

    def has_non_client_condition?(config)
      %w[visible_when disable_when].any? do |key|
        cond = config[key]
        cond.is_a?(Hash) && !ConditionEvaluator.client_evaluable?(cond)
      end
    end
  end
end
