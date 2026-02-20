module LcpRuby
  module ModelFactory
    class ServiceAccessorApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.fields.select(&:service_accessor?).each do |field|
          apply_service_accessor(field)
        end
      end

      private

      def apply_service_accessor(field)
        service_key = field.source["service"]
        options = (field.source["options"] || {}).freeze
        service = Services::Registry.lookup("accessors", service_key)

        unless service
          raise MetadataError,
            "Model '#{@model_definition.name}', field '#{field.name}': " \
            "accessor service '#{service_key}' not found"
        end

        field_name = field.name.to_sym

        @model_class.define_method(field_name) do
          service.get(self, options: options)
        end

        @model_class.define_method(:"#{field_name}=") do |value|
          service.set(self, value, options: options)
        end
      end
    end
  end
end
