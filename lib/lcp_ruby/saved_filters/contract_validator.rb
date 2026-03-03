module LcpRuby
  module SavedFilters
    class ContractValidator
      REQUIRED_FIELDS = {
        "name" => "string",
        "target_presenter" => "string",
        "condition_tree" => %w[json jsonb],
        "visibility" => "enum",
        "owner_id" => "integer",
        "pinned" => "boolean",
        "default_filter" => "boolean"
      }.freeze

      RECOMMENDED_FIELDS = {
        "ql_text" => "text",
        "description" => "text",
        "target_role" => "string",
        "target_group" => "string",
        "position" => "integer",
        "icon" => "string",
        "color" => "string"
      }.freeze

      # Validates that the given model definition satisfies the saved filter contract.
      # @param model_def [Metadata::ModelDefinition]
      # @return [Metadata::ContractResult]
      def self.validate(model_def)
        new(model_def).validate
      end

      def initialize(model_def)
        @model_def = model_def
        @errors = []
        @warnings = []
      end

      def validate
        validate_required_fields
        validate_recommended_fields

        Metadata::ContractResult.new(errors: @errors, warnings: @warnings)
      end

      private

      def validate_required_fields
        REQUIRED_FIELDS.each do |field_name, expected_type|
          field = find_field(field_name)

          if field.nil?
            @errors << "Saved filter model '#{@model_def.name}' must have a '#{field_name}' field"
            next
          end

          expected_types = Array(expected_type)
          unless expected_types.include?(field.type)
            @errors << "Saved filter model '#{@model_def.name}': '#{field_name}' field must be type " \
                       "'#{expected_types.join(' or ')}' (got '#{field.type}')"
          end
        end
      end

      def validate_recommended_fields
        RECOMMENDED_FIELDS.each do |field_name, expected_type|
          field = find_field(field_name)

          if field.nil?
            @warnings << "Saved filter model '#{@model_def.name}': '#{field_name}' field is recommended"
            next
          end

          expected_types = Array(expected_type)
          unless expected_types.include?(field.type)
            @warnings << "Saved filter model '#{@model_def.name}': '#{field_name}' field should be type " \
                         "'#{expected_types.join(' or ')}' (got '#{field.type}')"
          end
        end
      end

      def find_field(name)
        @model_def.fields.find { |f| f.name == name.to_s }
      end
    end
  end
end
