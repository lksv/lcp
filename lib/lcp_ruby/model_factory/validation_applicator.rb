module LcpRuby
  module ModelFactory
    class ValidationApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        apply_field_validations
        apply_model_validations
      end

      private

      def apply_field_validations
        @model_definition.fields.each do |field|
          field.validations.each do |validation|
            apply_validation(field.name, validation)
          end

          apply_type_default_validations(field) if field.type_definition
        end
      end

      def apply_type_default_validations(field)
        explicit_types = field.validations.map(&:type)

        field.type_definition.validations.each do |type_validation|
          validation_type = type_validation["type"]
          next if explicit_types.include?(validation_type)

          validation_def = Metadata::ValidationDefinition.new(type_validation)
          apply_validation(field.name, validation_def)
        end
      end

      def apply_model_validations
        @model_definition.validations.each do |validation|
          apply_model_level_validation(validation)
        end
      end

      def apply_validation(field_name, validation)
        case
        when validation.custom?
          apply_custom_validation(field_name, validation)
        when validation.comparison?
          apply_comparison_validation(field_name, validation)
        when validation.service?
          apply_service_validation(field_name, validation)
        else
          apply_standard_validation(field_name, validation)
        end
      end

      def apply_standard_validation(field_name, validation)
        opts = build_options(validation.options, validation)

        case validation.type
        when "presence"
          @model_class.validates field_name.to_sym, presence: opts.empty? ? true : opts
        when "length"
          @model_class.validates field_name.to_sym, length: opts
        when "numericality"
          @model_class.validates field_name.to_sym, numericality: opts.empty? ? true : opts
        when "format"
          if opts[:with].is_a?(String)
            opts[:with] = ConditionEvaluator.safe_regexp(opts[:with])
          end
          @model_class.validates field_name.to_sym, format: opts
        when "inclusion"
          @model_class.validates field_name.to_sym, inclusion: opts
        when "exclusion"
          @model_class.validates field_name.to_sym, exclusion: opts
        when "uniqueness"
          @model_class.validates field_name.to_sym, uniqueness: opts.empty? ? true : opts
        when "confirmation"
          @model_class.validates field_name.to_sym, confirmation: opts.empty? ? true : opts
        end
      end

      def apply_custom_validation(field_name, validation)
        validator_class = validation.validator_class.constantize
        opts = validation.options.merge(fields: [ field_name.to_sym ])
        apply_when_condition!(opts, validation)
        @model_class.validates_with validator_class, **opts
      rescue NameError => e
        raise SchemaError,
          "Custom validator '#{validation.validator_class}' not found: #{e.message}"
      end

      def apply_comparison_validation(field_name, validation)
        field_ref = validation.field_ref
        operator = validation.operator
        message = validation.message || "failed comparison (#{operator}) with #{field_ref}"
        when_condition = validation.when_condition

        @model_class.validate do |record|
          # Skip if when: condition is not met
          if when_condition
            next unless ConditionEvaluator.evaluate_any(record, when_condition)
          end

          current_value = record.send(field_name)
          ref_value = record.send(field_ref) if record.respond_to?(field_ref)

          # Skip comparison if either value is nil
          next if current_value.nil? || ref_value.nil?

          result = case operator
          when "gt"     then current_value > ref_value
          when "gte"    then current_value >= ref_value
          when "lt"     then current_value < ref_value
          when "lte"    then current_value <= ref_value
          when "eq"     then current_value == ref_value
          when "not_eq" then current_value != ref_value
          else true
          end

          record.errors.add(field_name.to_sym, message) unless result
        end
      end

      def apply_service_validation(field_name, validation)
        service_key = validation.service_key
        when_condition = validation.when_condition

        @model_class.validate do |record|
          if when_condition
            next unless ConditionEvaluator.evaluate_any(record, when_condition)
          end

          service = Services::Registry.lookup("validators", service_key)
          unless service
            Rails.logger.warn("[LcpRuby] Validator service '#{service_key}' not found") if defined?(Rails)
            next
          end

          service.call(record, field: field_name.to_sym)
        end
      end

      def apply_model_level_validation(validation)
        if validation.custom?
          validator_class = validation.validator_class.constantize
          opts = validation.options.dup
          apply_when_condition!(opts, validation)
          @model_class.validates_with validator_class, **opts
        elsif validation.service?
          apply_model_service_validation(validation)
        elsif validation.target_field
          # Standard validation targeting a specific field (e.g., FK field)
          apply_validation(validation.target_field, validation)
        end
      rescue NameError => e
        raise SchemaError,
          "Custom validator '#{validation.validator_class}' not found: #{e.message}"
      end

      def apply_model_service_validation(validation)
        service_key = validation.service_key
        when_condition = validation.when_condition

        @model_class.validate do |record|
          if when_condition
            next unless ConditionEvaluator.evaluate_any(record, when_condition)
          end

          service = Services::Registry.lookup("validators", service_key)
          unless service
            Rails.logger.warn("[LcpRuby] Validator service '#{service_key}' not found") if defined?(Rails)
            next
          end

          service.call(record)
        end
      end

      def build_options(options, validation = nil)
        opts = options.dup

        # Handle conditional validations (legacy if/unless strings)
        if opts[:if].is_a?(String)
          method_name = opts[:if]
          opts[:if] = ->(record) { record.send(method_name) }
        end

        if opts[:unless].is_a?(String)
          method_name = opts[:unless]
          opts[:unless] = ->(record) { record.send(method_name) }
        end

        # Handle when: condition
        apply_when_condition!(opts, validation) if validation

        # Inject message for standard validations
        opts[:message] = validation.message if validation&.message

        opts
      end

      def apply_when_condition!(opts, validation)
        return unless validation&.when_condition

        condition = validation.when_condition
        existing_if = opts[:if]

        when_proc = ->(record) { ConditionEvaluator.evaluate_any(record, condition) }

        if existing_if
          original_if = existing_if
          opts[:if] = ->(record) { original_if.call(record) && when_proc.call(record) }
        else
          opts[:if] = when_proc
        end
      end
    end
  end
end
