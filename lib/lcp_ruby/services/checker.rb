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
            lines = [ "Service reference errors (#{errors.size}):" ]
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
          check_field_accessors(model_def, field)
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
        end
        # String defaults are either registered service keys (handled by
        # DefaultApplicator at runtime) or literal values — both are valid.
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

          @errors << "Model '#{model_def.name}', field '#{field.name}': " \
                     "transform '#{key}' not found in Services::Registry"
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

      def check_field_accessors(model_def, field)
        return unless field.service_accessor?

        service_key = field.source["service"]
        unless Services::Registry.registered?("accessors", service_key)
          @errors << "Model '#{model_def.name}', field '#{field.name}': " \
                     "accessor service '#{service_key}' not found in Services::Registry"
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
    end
  end
end
