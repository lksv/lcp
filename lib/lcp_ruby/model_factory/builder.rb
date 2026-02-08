module LcpRuby
  module ModelFactory
    class Builder
      attr_reader :model_definition

      def initialize(model_definition)
        @model_definition = model_definition
      end

      def build
        model_class = create_model_class
        apply_table_name(model_class)
        apply_enums(model_class)
        apply_validations(model_class)
        apply_associations(model_class)
        apply_scopes(model_class)
        apply_callbacks(model_class)
        apply_label_method(model_class)
        model_class
      end

      private

      def create_model_class
        klass = Class.new(ActiveRecord::Base)
        class_name = model_definition.name.camelize

        # Register under LcpRuby::Dynamic namespace
        LcpRuby::Dynamic.const_set(class_name, klass)
        klass
      end

      def apply_table_name(model_class)
        table = model_definition.table_name
        model_class.table_name = table
      end

      def apply_enums(model_class)
        model_definition.enum_fields.each do |field|
          values = field.enum_value_names.index_with(&:itself)
          model_class.enum field.name.to_sym, values, default: field.default
        end
      end

      def apply_validations(model_class)
        ValidationApplicator.new(model_class, model_definition).apply!
      end

      def apply_associations(model_class)
        AssociationApplicator.new(model_class, model_definition).apply!
      end

      def apply_scopes(model_class)
        ScopeApplicator.new(model_class, model_definition).apply!
      end

      def apply_callbacks(model_class)
        CallbackApplicator.new(model_class, model_definition).apply!
      end

      def apply_label_method(model_class)
        label_attr = model_definition.label_method
        return if label_attr == "to_s"

        model_class.define_method(:to_label) do
          send(label_attr)
        end
      end
    end
  end
end
