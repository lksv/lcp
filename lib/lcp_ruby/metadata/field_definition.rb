module LcpRuby
  module Metadata
    class FieldDefinition
      BASE_TYPES = %w[
        string text integer float decimal boolean
        date datetime enum file rich_text json uuid
      ].freeze

      # Backward compatibility
      VALID_TYPES = BASE_TYPES

      attr_reader :name, :type, :label, :column_options, :validations,
                  :enum_values, :default, :type_definition, :transforms, :computed

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @type = attrs[:type].to_s
        @label = attrs[:label] || @name.humanize
        @column_options = attrs[:column_options] || {}
        @validations = (attrs[:validations] || []).map { |v| ValidationDefinition.new(v) }
        @enum_values = attrs[:enum_values] || []
        @default = attrs[:default]
        @transforms = Array(attrs[:transforms]).map(&:to_s)
        @computed = attrs[:computed]

        validate!
        resolve_type_definition!
      end

      def self.from_hash(hash)
        new(
          name: hash["name"],
          type: hash["type"],
          label: hash["label"],
          column_options: symbolize_keys(hash["column_options"]),
          validations: hash["validations"],
          enum_values: hash["enum_values"],
          default: hash["default"],
          transforms: hash["transforms"],
          computed: hash["computed"]
        )
      end

      def computed?
        !!@computed
      end

      def column_type
        if @type_definition
          @type_definition.column_type
        else
          case type
          when "enum" then :string
          when "rich_text" then :text
          when "uuid" then :string
          when "json" then :jsonb
          when "file" then :string
          else type.to_sym
          end
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

        unless BASE_TYPES.include?(@type) || Types::TypeRegistry.registered?(@type)
          raise MetadataError, "Field type '#{@type}' is invalid for field '#{@name}'"
        end
      end

      def resolve_type_definition!
        @type_definition = Types::TypeRegistry.resolve(@type)
      end

      def self.symbolize_keys(hash)
        return {} unless hash.is_a?(Hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
