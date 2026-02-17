module LcpRuby
  module Metadata
    class EventDefinition
      VALID_TYPES = %w[lifecycle field_change].freeze
      LIFECYCLE_EVENTS = %w[after_create after_update before_destroy after_destroy].freeze

      attr_reader :name, :type, :field, :condition

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @type = (attrs[:type] || infer_type).to_s
        @field = attrs[:field]&.to_s
        @condition = attrs[:condition]

        validate!
      end

      def condition_hash?
        @condition.is_a?(Hash)
      end

      def condition_string?
        @condition.is_a?(String)
      end

      def self.from_hash(hash)
        new(
          name: hash["name"],
          type: hash["type"],
          field: hash["field"],
          condition: hash["condition"]
        )
      end

      def lifecycle?
        type == "lifecycle"
      end

      def field_change?
        type == "field_change"
      end

      private

      def infer_type
        LIFECYCLE_EVENTS.include?(name) ? "lifecycle" : "field_change"
      end

      def validate!
        raise MetadataError, "Event name is required" if @name.blank?
        raise MetadataError, "Field change event '#{@name}' requires a field" if field_change? && @field.blank?
      end
    end
  end
end
