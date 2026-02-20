module LcpRuby
  module CustomFields
    class BuiltInModel
      FIELD_TYPE_VALUES = %w[
        string text integer float decimal boolean date datetime enum
      ].freeze

      def self.model_hash
        {
          "name" => "custom_field_definition",
          "table_name" => "custom_field_definitions",
          "options" => {
            "timestamps" => true,
            "label_method" => "label"
          },
          "fields" => [
            { "name" => "target_model", "type" => "string",
              "validations" => [ { "type" => "presence" } ] },
            { "name" => "field_name", "type" => "string",
              "validations" => [
                { "type" => "presence" },
                { "type" => "format", "options" => { "with" => "\\A[a-z][a-z0-9_]*\\z" },
                  "message" => "must start with a lowercase letter and contain only lowercase letters, digits, and underscores" }
              ] },
            { "name" => "custom_type", "type" => "string", "default" => "string",
              "validations" => [
                { "type" => "presence" },
                { "type" => "inclusion", "options" => { "in" => FIELD_TYPE_VALUES } }
              ] },
            { "name" => "label", "type" => "string",
              "validations" => [ { "type" => "presence" } ] },
            { "name" => "description", "type" => "text" },
            { "name" => "section", "type" => "string", "default" => "Custom Fields" },
            { "name" => "position", "type" => "integer", "default" => 0 },
            { "name" => "active", "type" => "boolean", "default" => true },
            { "name" => "required", "type" => "boolean", "default" => false },
            { "name" => "default_value", "type" => "string" },
            { "name" => "placeholder", "type" => "string" },
            { "name" => "min_length", "type" => "integer" },
            { "name" => "max_length", "type" => "integer" },
            { "name" => "min_value", "type" => "decimal", "column_options" => { "precision" => 15, "scale" => 4 } },
            { "name" => "max_value", "type" => "decimal", "column_options" => { "precision" => 15, "scale" => 4 } },
            { "name" => "precision", "type" => "integer" },
            { "name" => "enum_values", "type" => "json" },
            { "name" => "show_in_table", "type" => "boolean", "default" => false },
            { "name" => "show_in_form", "type" => "boolean", "default" => true },
            { "name" => "show_in_show", "type" => "boolean", "default" => true },
            { "name" => "sortable", "type" => "boolean", "default" => false },
            { "name" => "searchable", "type" => "boolean", "default" => false },
            { "name" => "input_type", "type" => "string" },
            { "name" => "renderer", "type" => "string" },
            { "name" => "renderer_options", "type" => "json" },
            { "name" => "column_width", "type" => "string" },
            { "name" => "extra_validations", "type" => "json" },
            { "name" => "readable_by_roles", "type" => "json" },
            { "name" => "writable_by_roles", "type" => "json" }
          ],
          "validations" => [
            {
              "type" => "uniqueness",
              "field" => "field_name",
              "options" => { "scope" => "target_model" },
              "message" => "has already been taken for this target model"
            }
          ]
        }
      end

      def self.model_definition
        Metadata::ModelDefinition.from_hash(model_hash)
      end

      # Reserved field names that cannot be used as custom field names.
      # These conflict with ActiveRecord or built-in model columns.
      RESERVED_NAMES = %w[
        id type created_at updated_at custom_data
      ].freeze

      def self.reserved_name?(name)
        RESERVED_NAMES.include?(name.to_s)
      end
    end
  end
end
