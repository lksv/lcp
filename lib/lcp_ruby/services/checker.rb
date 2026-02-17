module LcpRuby
  module Services
    class Checker
      CheckResult = Struct.new(:errors, keyword_init: true) do
        def valid?
          errors.empty?
        end

        def to_s
          if valid?
            "All service references are valid."
          else
            lines = ["Service reference errors (#{errors.size}):"]
            errors.each { |e| lines << "  [ERROR] #{e}" }
            lines.join("\n")
          end
        end
      end

      def initialize(model_definitions)
        @model_definitions = model_definitions
        @errors = []
      end

      def check
        @errors = []

        @model_definitions.each_value do |model_def|
          check_model(model_def)
        end

        CheckResult.new(errors: @errors.dup)
      end

      private

      def check_model(model_def)
        model_def.fields.each do |field|
          check_field_defaults(model_def, field)
          check_field_computed(model_def, field)
          check_field_transforms(model_def, field)
          check_field_validations(model_def, field)
        end

        check_model_validations(model_def)
      end

      def check_field_defaults(model_def, field)
        return unless field.default

        if field.default.is_a?(Hash)
          service_key = (field.default["service"] || field.default[:service])&.to_s
          return unless service_key

          unless Services::Registry.registered?("defaults", service_key)
            @errors << "Model '#{model_def.name}', field '#{field.name}': " \
                       "default service '#{service_key}' not found in Services::Registry"
          end
        elsif field.default.is_a?(String) && Services::Registry.registered?("defaults", field.default)
          # String defaults that match a registered service are valid
        elsif field.default.is_a?(String) && !literal_default?(field)
          # String defaults that don't match any service could be literal values;
          # only flag if they look like a service reference (contain no spaces, not a date, etc.)
          # We skip this check — literal string defaults are valid and common.
        end
      end

      def check_field_computed(model_def, field)
        return unless field.computed.is_a?(Hash)

        service_key = (field.computed["service"] || field.computed[:service])&.to_s
        return unless service_key

        unless Services::Registry.registered?("computed", service_key)
          @errors << "Model '#{model_def.name}', field '#{field.name}': " \
                     "computed service '#{service_key}' not found in Services::Registry"
        end
      end

      def check_field_transforms(model_def, field)
        field.transforms.each do |key|
          next if Services::Registry.registered?("transforms", key)
          next if Types::ServiceRegistry.lookup("transform", key)

          @errors << "Model '#{model_def.name}', field '#{field.name}': " \
                     "transform '#{key}' not found in Services::Registry or Types::ServiceRegistry"
        end
      end

      def check_field_validations(model_def, field)
        field.validations.each do |validation|
          check_service_validation(model_def, validation, field.name)
        end
      end

      def check_model_validations(model_def)
        model_def.validations.each do |validation|
          check_service_validation(model_def, validation)
        end
      end

      def check_service_validation(model_def, validation, field_name = nil)
        return unless validation.service?

        unless Services::Registry.registered?("validators", validation.service_key)
          context = field_name ? "field '#{field_name}'" : "model-level"
          @errors << "Model '#{model_def.name}', #{context}: " \
                     "validator service '#{validation.service_key}' not found in Services::Registry"
        end
      end

      def literal_default?(field)
        # Enum defaults, booleans, numbers are literal values, not service references
        field.enum? || %w[boolean integer float decimal].include?(field.type)
      end
    end
  end
end
