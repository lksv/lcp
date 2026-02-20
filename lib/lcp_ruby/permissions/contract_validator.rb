module LcpRuby
  module Permissions
    class ContractValidator
      # Validates that the given model definition satisfies the permission config model contract.
      # @param model_def [Metadata::ModelDefinition] the permission config model definition
      # @param field_mapping [Hash] field mapping from configuration
      # @return [Metadata::ContractResult]
      def self.validate(model_def, field_mapping = nil)
        new(model_def, field_mapping).validate
      end

      def initialize(model_def, field_mapping = nil)
        @model_def = model_def
        @field_mapping = (field_mapping || LcpRuby.configuration.permission_model_fields).transform_keys(&:to_s)
        @errors = []
        @warnings = []
      end

      def validate
        validate_target_model_field
        validate_definition_field
        validate_active_field

        Metadata::ContractResult.new(errors: @errors, warnings: @warnings)
      end

      private

      def validate_target_model_field
        field_name = @field_mapping["target_model"]
        field = find_field(field_name)

        if field.nil?
          @errors << "Permission config model '#{@model_def.name}' must have a '#{field_name}' field (mapped as target_model)"
          return
        end

        unless field.type == "string"
          @errors << "Permission config model '#{@model_def.name}': '#{field_name}' field must be type 'string' (got '#{field.type}')"
        end
      end

      def validate_definition_field
        field_name = @field_mapping["definition"]
        field = find_field(field_name)

        if field.nil?
          @errors << "Permission config model '#{@model_def.name}' must have a '#{field_name}' field (mapped as definition)"
          return
        end

        unless field.type == "json"
          @errors << "Permission config model '#{@model_def.name}': '#{field_name}' field must be type 'json' (got '#{field.type}')"
        end
      end

      def validate_active_field
        field_name = @field_mapping["active"]
        return unless field_name

        field = find_field(field_name)
        return unless field # Missing active field is OK - all records are treated as active

        unless field.type == "boolean"
          @errors << "Permission config model '#{@model_def.name}': '#{field_name}' field must be type 'boolean' (got '#{field.type}')"
        end
      end

      def find_field(name)
        @model_def.fields.find { |f| f.name == name.to_s }
      end
    end
  end
end
