module LcpRuby
  module Dsl
    class TypeBuilder
      def initialize(name)
        @name = name.to_s
        @base_type_value = nil
        @transforms = []
        @validations = []
        @input_type_value = nil
        @display_type_value = nil
        @column_options = {}
        @html_input_attrs = {}
      end

      def base_type(value)
        @base_type_value = value.to_s
      end

      def transform(key)
        @transforms << key.to_s
      end

      def validate(type, **options)
        validation = { "type" => type.to_s }
        validation["options"] = stringify_keys(options) unless options.empty?
        @validations << validation
      end

      def input_type(value)
        @input_type_value = value.to_s
      end

      def display_type(value)
        @display_type_value = value.to_s
      end

      def column_option(key, value)
        @column_options[key.to_sym] = value
      end

      def html_attr(key, value)
        @html_input_attrs[key.to_sym] = value
      end

      def to_hash
        hash = {
          "name" => @name,
          "base_type" => @base_type_value
        }
        hash["transforms"] = @transforms unless @transforms.empty?
        hash["validations"] = @validations unless @validations.empty?
        hash["input_type"] = @input_type_value if @input_type_value
        hash["display_type"] = @display_type_value if @display_type_value
        hash["column_options"] = stringify_keys(@column_options) unless @column_options.empty?
        hash["html_input_attrs"] = stringify_keys(@html_input_attrs) unless @html_input_attrs.empty?
        hash
      end

      private

      def stringify_keys(hash)
        return hash unless hash.is_a?(Hash)
        hash.transform_keys(&:to_s).transform_values do |v|
          case v
          when Hash then stringify_keys(v)
          when Symbol then v.to_s
          else v
          end
        end
      end
    end
  end
end
