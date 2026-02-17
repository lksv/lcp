module LcpRuby
  module Metadata
    class ValidationDefinition
      VALID_TYPES = %w[
        presence length numericality format inclusion exclusion
        uniqueness confirmation custom comparison service
      ].freeze

      attr_reader :type, :options, :validator_class, :when_condition,
                  :field_ref, :operator, :message, :service_key, :target_field

      def initialize(attrs = {})
        attrs = attrs.transform_keys(&:to_s) if attrs.is_a?(Hash)
        @type = (attrs["type"] || attrs[:type]).to_s
        @options = normalize_options(attrs["options"] || attrs[:options] || {})
        @validator_class = attrs["validator_class"] || attrs[:validator_class]
        @when_condition = attrs["when"]
        @field_ref = (attrs["field_ref"] || attrs[:field_ref])&.to_s
        @operator = (attrs["operator"] || attrs[:operator])&.to_s
        @message = attrs["message"] || attrs[:message]
        @service_key = (attrs["service"] || attrs[:service])&.to_s
        @target_field = (attrs["field"] || attrs[:field])&.to_s&.presence

        validate!
      end

      def custom?
        type == "custom"
      end

      def comparison?
        type == "comparison"
      end

      def service?
        type == "service"
      end

      private

      def validate!
        raise MetadataError, "Validation type '#{@type}' is invalid" unless VALID_TYPES.include?(@type)
        raise MetadataError, "Custom validation requires validator_class" if custom? && @validator_class.blank?
        raise MetadataError, "Comparison validation requires field_ref and operator" if comparison? && (@field_ref.blank? || @operator.blank?)
        raise MetadataError, "Service validation requires service key" if service? && @service_key.blank?
      end

      def normalize_options(opts)
        return {} unless opts.is_a?(Hash)
        opts.transform_keys(&:to_sym)
      end
    end
  end
end
