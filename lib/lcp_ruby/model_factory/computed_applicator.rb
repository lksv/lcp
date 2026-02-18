module LcpRuby
  module ModelFactory
    class ComputedApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        computed_fields = collect_computed_fields
        return if computed_fields.empty?

        @model_class.before_save do |record|
          computed_fields.each do |field_name, config|
            value = ComputedApplicator.compute(record, config)
            record.send("#{field_name}=", value)
          end
        end
      end

      def self.compute(record, config)
        case config
        when String
          # Template interpolation: "{first_name} {last_name}"
          config.gsub(/\{(\w+)\}/) { record.send(Regexp.last_match(1)).to_s }
        when Hash
          service_key = config["service"] || config[:service]
          return unless service_key

          service = Services::Registry.lookup("computed", service_key.to_s)
          unless service
            Rails.logger.warn("[LcpRuby] Computed service '#{service_key}' not found") if defined?(Rails)
            return
          end

          service.call(record)
        end
      end

      private

      def collect_computed_fields
        fields = {}

        @model_definition.fields.each do |field|
          next unless field.computed?

          fields[field.name] = field.computed
        end

        fields
      end
    end
  end
end
