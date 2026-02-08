module LcpRuby
  module Metadata
    class ValidationDefinition
      VALID_TYPES = %w[
        presence length numericality format inclusion exclusion
        uniqueness confirmation custom
      ].freeze

      attr_reader :type, :options, :validator_class

      def initialize(attrs = {})
        attrs = attrs.transform_keys(&:to_s) if attrs.is_a?(Hash)
        @type = (attrs["type"] || attrs[:type]).to_s
        @options = normalize_options(attrs["options"] || attrs[:options] || {})
        @validator_class = attrs["validator_class"] || attrs[:validator_class]

        validate!
      end

      def custom?
        type == "custom"
      end

      private

      def validate!
        raise MetadataError, "Validation type '#{@type}' is invalid" unless VALID_TYPES.include?(@type)
        raise MetadataError, "Custom validation requires validator_class" if custom? && @validator_class.blank?
      end

      def normalize_options(opts)
        return {} unless opts.is_a?(Hash)
        opts.transform_keys(&:to_sym)
      end
    end
  end
end
