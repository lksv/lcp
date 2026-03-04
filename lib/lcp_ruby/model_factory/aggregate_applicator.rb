module LcpRuby
  module ModelFactory
    class AggregateApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.aggregates.each_value do |agg_def|
          validate_service_aggregate!(agg_def) if agg_def.service_type?
        end
      end

      private

      def validate_service_aggregate!(agg_def)
        unless Services::Registry.registered?("aggregates", agg_def.service)
          raise MetadataError,
            "Model '#{@model_definition.name}', aggregate '#{agg_def.name}': " \
            "service '#{agg_def.service}' not found in aggregates registry"
        end
      end
    end
  end
end
