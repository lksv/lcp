module LcpRuby
  module ModelFactory
    # Registers ActiveRecord attribute types for array fields.
    # On PostgreSQL, native array columns work out of the box — only the default is set.
    # On SQLite/MySQL, a custom ArrayType handles JSON serialization transparently.
    class ArrayTypeApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.fields.select(&:array?).each do |field|
          if LcpRuby.postgresql?
            apply_pg_array(field)
          else
            apply_json_array(field)
          end
        end
      end

      private

      def apply_pg_array(field)
        @model_class.attribute field.name.to_sym, default: field.default || []
      end

      def apply_json_array(field)
        @model_class.attribute field.name.to_sym, ArrayType.new(field.item_type), default: field.default || []
      end
    end
  end
end
