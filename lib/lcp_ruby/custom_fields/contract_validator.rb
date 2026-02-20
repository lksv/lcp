module LcpRuby
  module CustomFields
    class ContractValidator
      REQUIRED_FIELDS = {
        "field_name" => "string",
        "custom_type" => "string",
        "target_model" => "string",
        "label" => "string",
        "active" => "boolean"
      }.freeze

      def self.validate(model_def)
        new(model_def).validate
      end

      def initialize(model_def)
        @model_def = model_def
        @errors = []
        @warnings = []
      end

      def validate
        REQUIRED_FIELDS.each do |field_name, expected_type|
          validate_required_field(field_name, expected_type)
        end

        validate_field_name_uniqueness

        Metadata::ContractResult.new(errors: @errors, warnings: @warnings)
      end

      private

      def validate_required_field(field_name, expected_type)
        field = find_field(field_name)
        if field.nil?
          @errors << "Custom field definition model '#{@model_def.name}' must have a '#{field_name}' field"
          return
        end

        unless field.type == expected_type
          @errors << "Custom field definition model '#{@model_def.name}': '#{field_name}' field must be type '#{expected_type}' (got '#{field.type}')"
        end
      end

      def validate_field_name_uniqueness
        field = find_field("field_name")
        return unless field

        # Check model-level validations (YAML format stores them here)
        has_scoped_uniqueness = @model_def.validations.any? do |v|
          v.type == "uniqueness" &&
            v.target_field == "field_name" &&
            v.options.is_a?(Hash) &&
            v.options[:scope]&.to_s == "target_model"
        end

        # Check field-level validations (DSL format merges them into the field)
        has_scoped_uniqueness ||= field.validations.any? do |v|
          v.type == "uniqueness" &&
            v.options.is_a?(Hash) &&
            v.options[:scope]&.to_s == "target_model"
        end

        unless has_scoped_uniqueness
          @warnings << "Custom field definition model '#{@model_def.name}': 'field_name' field should have a uniqueness validation scoped to 'target_model'"
        end
      end

      def find_field(name)
        @model_def.fields.find { |f| f.name == name.to_s }
      end
    end
  end
end
