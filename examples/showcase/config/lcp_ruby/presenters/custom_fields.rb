# frozen_string_literal: true

define_presenter :custom_fields do
  model :custom_field_definition
  label "Custom Fields"
  slug "custom-fields"

  index do
    default_sort :position, :asc
    empty_message "No custom fields defined yet."

    column :field_name, label: "Field Name", sortable: true
    column :custom_type, label: "Type", sortable: true
    column :label, label: "Label", sortable: true
    column :section, label: "Section"
    column :position, label: "Position", sortable: true
    column :active, label: "Active", renderer: "boolean"
    column :required, label: "Required", renderer: "boolean"
  end

  show do
    section "General", columns: 2 do
      field :field_name
      field :custom_type
      field :label
      field :section
      field :position
      field :active
      field :required
      field :description, col_span: 2
    end

    section "Constraints", columns: 2 do
      field :min_length
      field :max_length
      field :min_value
      field :max_value
      field :precision
      field :default_value
      field :placeholder
    end

    section "Display", columns: 2 do
      field :show_in_table
      field :show_in_form
      field :show_in_show
      field :sortable
      field :searchable
      field :input_type
      field :renderer
      field :column_width
    end
  end

  form do
    layout :sections

    section "General", columns: 2 do
      field :field_name
      field :custom_type
      field :label
      field :section
      field :position
      field :active
      field :required
      field :description, col_span: 2
    end

    section "Text Constraints", columns: 2 do
      field :min_length
      field :max_length
      field :default_value
      field :placeholder
    end

    section "Numeric Constraints", columns: 2 do
      field :min_value
      field :max_value
      field :precision
    end

    section "Enum Values" do
      field :enum_values
    end

    section "Display Options", columns: 2 do
      field :show_in_table
      field :show_in_form
      field :show_in_show
      field :sortable
      field :searchable
      field :input_type
      field :renderer
      field :column_width
    end
  end

  search do
    searchable_fields :field_name, :label, :section
  end

  action :create, type: :built_in, on: :collection, label: "New Field"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: "Are you sure?"
end
