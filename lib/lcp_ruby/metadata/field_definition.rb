module LcpRuby
  module Metadata
    class FieldDefinition
      BASE_TYPES = %w[
        string text integer float decimal boolean
        date datetime enum file rich_text json uuid
        attachment array
      ].freeze

      VALID_ARRAY_ITEM_TYPES = %w[string integer float].freeze

      # Backward compatibility
      VALID_TYPES = BASE_TYPES

      attr_reader :name, :type, :label, :column_options, :validations,
                  :enum_values, :default, :type_definition, :transforms, :computed,
                  :attachment_options, :source, :item_type, :sequence

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
        @attachment_options = attrs[:attachment_options] || {}
        @source = attrs[:source]
        @item_type = attrs[:item_type]&.to_s
        @sequence = normalize_sequence(attrs[:sequence])

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
          computed: hash["computed"],
          attachment_options: hash["options"] || {},
          source: hash["source"],
          item_type: hash["item_type"],
          sequence: hash["sequence"]
        )
      end

      def computed?
        !!@computed
      end

      def sequence?
        !!@sequence
      end

      def virtual?
        source.present?
      end

      def external?
        source == "external" || source == :external
      end

      def service_accessor?
        source.is_a?(Hash) && source.key?("service")
      end

      def column_type
        return nil if attachment?
        return nil if virtual?

        if array?
          if LcpRuby.postgresql?
            pg_array_column_type
          else
            LcpRuby.json_column_type
          end
        elsif @type_definition
          @type_definition.column_type
        else
          case type
          when "enum" then :string
          when "rich_text" then :text
          when "uuid" then :string
          when "json" then LcpRuby.json_column_type
          when "file" then :string
          else type.to_sym
          end
        end
      end

      def resolved_base_type
        if type_definition
          type_definition.base_type
        else
          type
        end
      end

      def enum?
        type == "enum"
      end

      def attachment?
        type == "attachment"
      end

      def array?
        type == "array"
      end

      def attachment_multiple?
        attachment? && attachment_options["multiple"] == true
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

        if array? && !VALID_ARRAY_ITEM_TYPES.include?(@item_type)
          raise MetadataError,
            "Field '#{@name}': array type requires item_type (#{VALID_ARRAY_ITEM_TYPES.join(', ')})"
        end

        if @source && @computed
          raise MetadataError,
            "Field '#{@name}': cannot have both 'source' and 'computed' — use one or the other"
        end

        if @sequence && @computed
          raise MetadataError,
            "Field '#{@name}': cannot have both 'sequence' and 'computed' — use one or the other"
        end

        if @sequence && @source
          raise MetadataError,
            "Field '#{@name}': cannot have both 'sequence' and 'source' — use one or the other"
        end
      end

      def pg_array_column_type
        case item_type
        when "string"  then :text
        when "integer" then :integer
        when "float"   then :float
        end
      end

      def resolve_type_definition!
        @type_definition = Types::TypeRegistry.resolve(@type)
      end

      def normalize_sequence(value)
        return nil if value.nil?

        value.is_a?(Hash) ? value : {}
      end

      def self.symbolize_keys(hash)
        return {} unless hash.is_a?(Hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
