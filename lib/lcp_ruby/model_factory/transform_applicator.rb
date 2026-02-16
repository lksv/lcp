module LcpRuby
  module ModelFactory
    class TransformApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.fields.each do |field|
          next unless field.type_definition
          next if field.type_definition.transforms.empty?

          apply_transforms(field)
        end
      end

      private

      def apply_transforms(field)
        transforms = resolve_transforms(field.type_definition.transforms)
        return if transforms.empty?

        field_name = field.name.to_sym
        @model_class.normalizes field_name, with: ->(value) {
          transforms.reduce(value) { |v, t| t.call(v) }
        }
      end

      def resolve_transforms(transform_keys)
        transform_keys.filter_map do |key|
          service = Types::ServiceRegistry.lookup("transform", key)
          unless service
            Rails.logger.warn("[LcpRuby] Transform '#{key}' not found in ServiceRegistry") if defined?(Rails)
          end
          service
        end
      end
    end
  end
end
