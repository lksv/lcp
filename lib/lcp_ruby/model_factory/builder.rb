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
        apply_transforms(model_class)
        apply_associations(model_class)
        apply_attachments(model_class)
        apply_scopes(model_class)
        apply_callbacks(model_class)
        apply_defaults(model_class)
        apply_computed(model_class)
        apply_external_fields(model_class)
        apply_model_extensions(model_class)
        apply_custom_fields(model_class)
        apply_label_method(model_class)
        validate_external_methods!(model_class)
        model_class
      rescue => e
        raise LcpRuby::MetadataError,
          "Failed to build model '#{model_definition.name}': #{e.message}"
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
          if field.virtual?
            # Virtual enums can't use AR enum macro (no DB column).
            # Auto-add inclusion validation so enum constraints are enforced.
            valid_values = field.enum_value_names
            model_class.validates field.name.to_sym, inclusion: { in: valid_values }, allow_nil: true
            next
          end
          values = field.enum_value_names.index_with(&:itself)
          model_class.enum field.name.to_sym, values, default: field.default
        end
      end

      def apply_validations(model_class)
        ValidationApplicator.new(model_class, model_definition).apply!
      end

      def apply_transforms(model_class)
        TransformApplicator.new(model_class, model_definition).apply!
      end

      def apply_associations(model_class)
        AssociationApplicator.new(model_class, model_definition).apply!
      end

      def apply_attachments(model_class)
        AttachmentApplicator.new(model_class, model_definition).apply!
      end

      def apply_scopes(model_class)
        ScopeApplicator.new(model_class, model_definition).apply!
      end

      def apply_callbacks(model_class)
        CallbackApplicator.new(model_class, model_definition).apply!
      end

      def apply_defaults(model_class)
        DefaultApplicator.new(model_class, model_definition).apply!
      end

      def apply_computed(model_class)
        ComputedApplicator.new(model_class, model_definition).apply!
      end

      def apply_external_fields(model_class)
        ServiceAccessorApplicator.new(model_class, model_definition).apply!
      end

      def validate_external_methods!(model_class)
        model_definition.fields.select(&:external?).each do |field|
          unless model_class.method_defined?(field.name.to_sym)
            raise LcpRuby::MetadataError,
              "Model '#{model_definition.name}', field '#{field.name}': " \
              "source is 'external' but no getter method defined. " \
              "Define it in Rails.application.config.after_initialize (runs before LcpRuby.boot!)."
          end
          unless model_class.method_defined?(:"#{field.name}=")
            raise LcpRuby::MetadataError,
              "Model '#{model_definition.name}', field '#{field.name}': " \
              "source is 'external' but no setter method defined. " \
              "Define it in Rails.application.config.after_initialize (runs before LcpRuby.boot!)."
          end
        end
      end

      def apply_model_extensions(model_class)
        extensions = LcpRuby.configuration.model_extensions[model_definition.name] || []
        extensions.each { |block| block.call(model_class) }
      end

      def apply_custom_fields(model_class)
        CustomFields::Applicator.new(model_class, model_definition).apply!
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
