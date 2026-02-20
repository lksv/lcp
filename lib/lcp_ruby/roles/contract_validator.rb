module LcpRuby
  module Roles
    class ContractValidator
      # Validates that the given model definition satisfies the role model contract.
      # @param model_def [Metadata::ModelDefinition] the role model definition
      # @param field_mapping [Hash] field mapping from configuration (e.g., { name: "name", active: "active" })
      # @return [Metadata::ContractResult]
      def self.validate(model_def, field_mapping = nil)
        new(model_def, field_mapping).validate
      end

      def initialize(model_def, field_mapping = nil)
        @model_def = model_def
        @field_mapping = (field_mapping || LcpRuby.configuration.role_model_fields).transform_keys(&:to_s)
        @errors = []
        @warnings = []
      end

      def validate
        validate_name_field
        validate_active_field

        Metadata::ContractResult.new(errors: @errors, warnings: @warnings)
      end

      private

      def validate_name_field
        name_field_name = @field_mapping["name"]

        field = find_field(name_field_name)
        if field.nil?
          @errors << "Role model '#{@model_def.name}' must have a '#{name_field_name}' field (mapped as name)"
          return
        end

        unless field.type == "string"
          @errors << "Role model '#{@model_def.name}': '#{name_field_name}' field must be type 'string' (got '#{field.type}')"
        end

        unless has_uniqueness_validation?(field)
          @warnings << "Role model '#{@model_def.name}': '#{name_field_name}' field should have a uniqueness validation"
        end
      end

      def validate_active_field
        active_field_name = @field_mapping["active"]
        return unless active_field_name

        field = find_field(active_field_name)
        return unless field # Missing active field is OK — all roles are treated as active

        unless field.type == "boolean"
          @errors << "Role model '#{@model_def.name}': '#{active_field_name}' field must be type 'boolean' (got '#{field.type}')"
        end
      end

      def find_field(name)
        @model_def.fields.find { |f| f.name == name.to_s }
      end

      def has_uniqueness_validation?(field)
        field.validations.any? { |v| v.type == "uniqueness" }
      end
    end
  end
end
