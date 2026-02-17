module LcpRuby
  module ConditionHelper
    # Evaluates a condition (field-value or service) against a record
    def condition_met?(record, condition)
      ConditionEvaluator.evaluate_any(record, condition)
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

    # Checks if any sections or fields in the presenter have service conditions
    def service_conditions?(presenter_definition)
      sections = presenter_definition.form_config["sections"] || []
      sections.any? do |section|
        has_service = section_has_service_condition?(section)
        fields_have = (section["fields"] || []).any? { |f| field_has_service_condition?(f) }
        has_service || fields_have
      end
    end

    private

    def section_has_service_condition?(section)
      %w[visible_when disable_when].any? do |key|
        cond = section[key]
        cond.is_a?(Hash) && ConditionEvaluator.condition_type(cond) == :service
      end
    end

    def field_has_service_condition?(field_config)
      %w[visible_when disable_when].any? do |key|
        cond = field_config[key]
        cond.is_a?(Hash) && ConditionEvaluator.condition_type(cond) == :service
      end
    end
  end
end
