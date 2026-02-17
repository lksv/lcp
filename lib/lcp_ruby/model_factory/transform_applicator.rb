module LcpRuby
  module ModelFactory
    class TransformApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.fields.each do |field|
          type_transforms = field.type_definition&.transforms || []
          field_transforms = field.transforms

          # Merge: type-level first, then field-level (deduplicated)
          all_keys = (type_transforms + field_transforms).uniq
          next if all_keys.empty?

          apply_transforms(field, all_keys)
        end
      end

      private

      def apply_transforms(field, transform_keys)
        transforms = resolve_transforms(transform_keys)
        return if transforms.empty?

        field_name = field.name.to_sym
        @model_class.normalizes field_name, with: ->(value) {
          transforms.reduce(value) { |v, t| t.call(v) }
        }
      end

      def resolve_transforms(transform_keys)
        transform_keys.filter_map do |key|
          service = Services::Registry.lookup("transforms", key) ||
                    Types::ServiceRegistry.lookup("transform", key)
          unless service
            Rails.logger.warn("[LcpRuby] Transform '#{key}' not found in registry") if defined?(Rails)
          end
          service
        end
      end
    end
  end
end
