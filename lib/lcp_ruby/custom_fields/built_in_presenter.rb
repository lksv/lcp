module LcpRuby
  module CustomFields
    class BuiltInPresenter
      # Generate a presenter definition hash for managing custom fields of a target model.
      # The target_model parameter is used only for naming; scoping is handled by the controller.
      #
      # @param target_model [String] the model name that custom fields are managed for
      # @return [Hash] presenter definition hash suitable for PresenterDefinition.from_hash
      def self.presenter_hash(target_model:)
        {
          "name" => "custom_fields_#{target_model}",
          "model" => "custom_field_definition",
          "label" => "Custom Fields",
          "index" => {
            "table_columns" => [
              { "field" => "field_name", "label" => "Field Name", "sortable" => true },
              { "field" => "custom_type", "label" => "Type", "sortable" => true },
              { "field" => "label", "label" => "Label", "sortable" => true },
              { "field" => "section", "label" => "Section" },
              { "field" => "position", "label" => "Position", "sortable" => true },
              { "field" => "active", "label" => "Active", "renderer" => "boolean" },
              { "field" => "required", "label" => "Required", "renderer" => "boolean" }
            ],
            "default_sort" => { "field" => "position", "direction" => "asc" },
            "empty_state" => { "message" => "No custom fields defined yet." }
          },
          "show" => {
            "layout" => [
              {
                "section" => "General",
                "columns" => 2,
                "fields" => [
                  { "field" => "field_name" },
                  { "field" => "custom_type" },
                  { "field" => "label" },
                  { "field" => "section" },
                  { "field" => "position" },
                  { "field" => "active" },
                  { "field" => "required" },
                  { "field" => "description", "col_span" => 2 }
                ]
              },
              {
                "section" => "Constraints",
                "columns" => 2,
                "fields" => [
                  { "field" => "min_length" },
                  { "field" => "max_length" },
                  { "field" => "min_value" },
                  { "field" => "max_value" },
                  { "field" => "precision" },
                  { "field" => "default_value" },
                  { "field" => "placeholder" }
                ]
              },
              {
                "section" => "Display",
                "columns" => 2,
                "fields" => [
                  { "field" => "show_in_table" },
                  { "field" => "show_in_form" },
                  { "field" => "show_in_show" },
                  { "field" => "sortable" },
                  { "field" => "searchable" },
                  { "field" => "input_type" },
                  { "field" => "renderer" },
                  { "field" => "column_width" }
                ]
              }
            ]
          },
          "form" => {
            "layout" => "sections",
            "sections" => [
              {
                "title" => "General",
                "columns" => 2,
                "fields" => [
                  { "field" => "field_name" },
                  { "field" => "custom_type" },
                  { "field" => "label" },
                  { "field" => "section" },
                  { "field" => "position" },
                  { "field" => "active" },
                  { "field" => "required" },
                  { "field" => "description", "col_span" => 2 }
                ]
              },
              {
                "title" => "Text Constraints",
                "columns" => 2,
                "fields" => [
                  { "field" => "min_length" },
                  { "field" => "max_length" },
                  { "field" => "default_value" },
                  { "field" => "placeholder" }
                ]
              },
              {
                "title" => "Numeric Constraints",
                "columns" => 2,
                "fields" => [
                  { "field" => "min_value" },
                  { "field" => "max_value" },
                  { "field" => "precision" }
                ]
              },
              {
                "title" => "Enum Values",
                "fields" => [
                  { "field" => "enum_values" }
                ]
              },
              {
                "title" => "Display Options",
                "columns" => 2,
                "fields" => [
                  { "field" => "show_in_table" },
                  { "field" => "show_in_form" },
                  { "field" => "show_in_show" },
                  { "field" => "sortable" },
                  { "field" => "searchable" },
                  { "field" => "input_type" },
                  { "field" => "renderer" },
                  { "field" => "column_width" }
                ]
              }
            ]
          },
          "search" => {
            "enabled" => true,
            "searchable_fields" => %w[field_name label section]
          },
          "actions" => {
            "collection" => [
              { "name" => "create", "type" => "built_in", "label" => "New Field" }
            ],
            "single" => [
              { "name" => "show", "type" => "built_in" },
              { "name" => "edit", "type" => "built_in" },
              { "name" => "destroy", "type" => "built_in", "confirm" => "Are you sure?" }
            ]
          }
        }
      end

      def self.presenter_definition(target_model:)
        Metadata::PresenterDefinition.from_hash(presenter_hash(target_model: target_model))
      end
    end
  end
end
