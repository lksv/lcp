module LcpRuby
  module ModelFactory
    class DefaultApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        dynamic_defaults = collect_dynamic_defaults
        return if dynamic_defaults.empty?

        @model_class.after_initialize do |record|
          next unless record.new_record?

          dynamic_defaults.each do |field_name, default_config|
            next if record.send(field_name).present?

            value = DefaultApplicator.resolve_default(record, field_name, default_config)
            record.send("#{field_name}=", value) unless value.nil?
          end
        end
      end

      def self.resolve_default(record, field_name, default_config)
        case default_config
        when Hash
          service_key = default_config["service"] || default_config[:service]
          return unless service_key

          service = Services::Registry.lookup("defaults", service_key.to_s)
          unless service
            Rails.logger.warn("[LcpRuby] Default service '#{service_key}' not found") if defined?(Rails)
            return
          end

          if service.respond_to?(:call)
            service.call(record, field_name)
          end
        when String
          # Built-in default keys like "current_date", "current_datetime", "current_user_id"
          service = Services::Registry.lookup("defaults", default_config)
          if service&.respond_to?(:call)
            service.call(record, field_name)
          end
        end
      end

      private

      def collect_dynamic_defaults
        defaults = {}

        @model_definition.fields.each do |field|
          next unless field.default

          if field.default.is_a?(Hash) && (field.default.key?("service") || field.default.key?(:service))
            defaults[field.name] = field.default
          elsif field.default.is_a?(String) && Services::Registry.registered?("defaults", field.default)
            defaults[field.name] = field.default
          end
        end

        defaults
      end
    end
  end
end
