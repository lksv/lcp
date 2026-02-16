module LcpRuby
  module Types
    class TypeDefinition
      BASE_TYPE_COLUMN_MAP = {
        "enum" => :string,
        "rich_text" => :text,
        "uuid" => :string,
        "json" => :jsonb,
        "file" => :string
      }.freeze

      attr_reader :name, :base_type, :transforms, :validations,
                  :input_type, :display_type, :column_options, :html_input_attrs

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @base_type = attrs[:base_type].to_s
        @transforms = Array(attrs[:transforms]).map(&:to_s)
        @validations = Array(attrs[:validations]).map { |v| normalize_validation(v) }
        @input_type = attrs[:input_type]&.to_s
        @display_type = attrs[:display_type]&.to_s
        @column_options = attrs[:column_options] || {}
        @html_input_attrs = attrs[:html_input_attrs] || {}

        validate!
      end

      def self.from_hash(hash)
        hash = hash.transform_keys(&:to_s) if hash.is_a?(Hash)
        new(
          name: hash["name"],
          base_type: hash["base_type"],
          transforms: hash["transforms"],
          validations: hash["validations"],
          input_type: hash["input_type"],
          display_type: hash["display_type"],
          column_options: symbolize_keys(hash["column_options"]),
          html_input_attrs: symbolize_keys(hash["html_input_attrs"])
        )
      end

      def column_type
        BASE_TYPE_COLUMN_MAP[base_type] || base_type.to_sym
      end

      private

      def validate!
        raise MetadataError, "Type name is required" if @name.blank?
        raise MetadataError, "Base type is required for type '#{@name}'" if @base_type.blank?

        valid_base = Metadata::FieldDefinition::BASE_TYPES
        unless valid_base.include?(@base_type)
          raise MetadataError,
            "Invalid base_type '#{@base_type}' for type '#{@name}'. Valid: #{valid_base.join(', ')}"
        end
      end

      def normalize_validation(v)
        case v
        when Hash
          v.transform_keys(&:to_s)
        else
          v
        end
      end

      def self.symbolize_keys(hash)
        return {} unless hash.is_a?(Hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
