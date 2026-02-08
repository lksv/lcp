module LcpRuby
  module Metadata
    class FieldDefinition
      VALID_TYPES = %w[
        string text integer float decimal boolean
        date datetime enum file rich_text json uuid
      ].freeze

      attr_reader :name, :type, :label, :column_options, :validations,
                  :enum_values, :default

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @type = attrs[:type].to_s
        @label = attrs[:label] || @name.humanize
        @column_options = attrs[:column_options] || {}
        @validations = (attrs[:validations] || []).map { |v| ValidationDefinition.new(v) }
        @enum_values = attrs[:enum_values] || []
        @default = attrs[:default]

        validate!
      end

      def self.from_hash(hash)
        new(
          name: hash["name"],
          type: hash["type"],
          label: hash["label"],
          column_options: symbolize_keys(hash["column_options"]),
          validations: hash["validations"],
          enum_values: hash["enum_values"],
          default: hash["default"]
        )
      end

      def column_type
        case type
        when "enum" then :string
        when "rich_text" then :text
        when "uuid" then :string
        when "json" then :jsonb
        when "file" then :string
        else type.to_sym
        end
      end

      def enum?
        type == "enum"
      end

      def enum_value_names
        enum_values.map { |v| v.is_a?(Hash) ? (v["value"] || v[:value]).to_s : v.to_s }
      end

      private

      def validate!
        raise MetadataError, "Field name is required" if @name.blank?
        raise MetadataError, "Field type '#{@type}' is invalid for field '#{@name}'" unless VALID_TYPES.include?(@type)
      end

      def self.symbolize_keys(hash)
        return {} unless hash.is_a?(Hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
