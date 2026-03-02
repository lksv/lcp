module LcpRuby
  module Auditing
    class ContractValidator
      REQUIRED_FIELDS = {
        "auditable_type" => "string",
        "auditable_id" => "integer",
        "action" => "string",
        "changes_data" => "json"
      }.freeze

      RECOMMENDED_FIELDS = {
        "user_id" => "integer",
        "user_snapshot" => "json"
      }.freeze

      # Validates that the given model definition satisfies the audit model contract.
      # @param model_def [Metadata::ModelDefinition] the audit model definition
      # @param field_mapping [Hash] field mapping from configuration
      # @return [Metadata::ContractResult]
      def self.validate(model_def, field_mapping = nil)
        new(model_def, field_mapping).validate
      end

      def initialize(model_def, field_mapping = nil)
        @model_def = model_def
        @field_mapping = (field_mapping || LcpRuby.configuration.audit_model_fields).transform_keys(&:to_s)
        @errors = []
        @warnings = []
      end

      def validate
        validate_required_fields
        validate_recommended_fields
        validate_created_at

        Metadata::ContractResult.new(errors: @errors, warnings: @warnings)
      end

      private

      def validate_required_fields
        REQUIRED_FIELDS.each do |logical_name, expected_type|
          mapped_name = @field_mapping[logical_name] || logical_name
          field = find_field(mapped_name)

          if field.nil?
            @errors << "Audit model '#{@model_def.name}' must have a '#{mapped_name}' field (mapped as #{logical_name})"
            next
          end

          actual_type = field.type
          # json and jsonb are equivalent
          expected_types = expected_type == "json" ? %w[json jsonb] : [ expected_type ]
          unless expected_types.include?(actual_type)
            @errors << "Audit model '#{@model_def.name}': '#{mapped_name}' field must be type " \
                       "'#{expected_type}' (got '#{actual_type}')"
          end
        end
      end

      def validate_recommended_fields
        RECOMMENDED_FIELDS.each do |logical_name, expected_type|
          mapped_name = @field_mapping[logical_name] || logical_name
          field = find_field(mapped_name)

          if field.nil?
            @warnings << "Audit model '#{@model_def.name}': '#{mapped_name}' field is recommended " \
                         "for full audit trail (mapped as #{logical_name})"
            next
          end

          actual_type = field.type
          expected_types = expected_type == "json" ? %w[json jsonb] : [ expected_type ]
          unless expected_types.include?(actual_type)
            @errors << "Audit model '#{@model_def.name}': '#{mapped_name}' field must be type " \
                       "'#{expected_type}' (got '#{actual_type}')"
          end
        end
      end

      def validate_created_at
        # Audit logs need a created_at field (either from timestamps or explicit)
        field = find_field("created_at")
        if field.nil? && !@model_def.options.fetch("timestamps", false)
          @warnings << "Audit model '#{@model_def.name}': should have a 'created_at' field " \
                       "or timestamps enabled for chronological ordering"
        end
      end

      def find_field(name)
        @model_def.fields.find { |f| f.name == name.to_s }
      end
    end
  end
end
