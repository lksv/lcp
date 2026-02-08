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
        end
      end

      def apply_model_validations
        @model_definition.validations.each do |validation|
          apply_model_level_validation(validation)
        end
      end

      def apply_validation(field_name, validation)
        if validation.custom?
          apply_custom_validation(field_name, validation)
        else
          apply_standard_validation(field_name, validation)
        end
      end

      def apply_standard_validation(field_name, validation)
        opts = build_options(validation.options)

        case validation.type
        when "presence"
          @model_class.validates field_name.to_sym, presence: opts.empty? ? true : opts
        when "length"
          @model_class.validates field_name.to_sym, length: opts
        when "numericality"
          @model_class.validates field_name.to_sym, numericality: opts.empty? ? true : opts
        when "format"
          if opts[:with].is_a?(String)
            opts[:with] = Regexp.new(opts[:with])
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
        opts = validation.options.merge(fields: [field_name.to_sym])
        @model_class.validates_with validator_class, **opts
      rescue NameError => e
        raise SchemaError,
          "Custom validator '#{validation.validator_class}' not found: #{e.message}"
      end

      def apply_model_level_validation(validation)
        return unless validation.custom?

        validator_class = validation.validator_class.constantize
        @model_class.validates_with validator_class, **validation.options
      rescue NameError => e
        raise SchemaError,
          "Custom validator '#{validation.validator_class}' not found: #{e.message}"
      end

      def build_options(options)
        opts = options.dup

        # Handle conditional validations
        if opts[:if].is_a?(String)
          method_name = opts[:if]
          opts[:if] = ->(record) { record.send(method_name) }
        end

        if opts[:unless].is_a?(String)
          method_name = opts[:unless]
          opts[:unless] = ->(record) { record.send(method_name) }
        end

        opts
      end
    end
  end
end
