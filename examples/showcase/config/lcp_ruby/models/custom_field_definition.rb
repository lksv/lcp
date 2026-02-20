# frozen_string_literal: true

define_model :custom_field_definition do
  table_name "custom_field_definitions"
  label "Custom Field Definition"
  label_plural "Custom Field Definitions"
  timestamps true
  label_method :label

  field :target_model, :string do
    validates :presence
  end

  field :field_name, :string do
    validates :presence
    validates :format,
      with: "\\A[a-z][a-z0-9_]*\\z",
      message: "must start with a lowercase letter and contain only lowercase letters, digits, and underscores"
  end

  field :custom_type, :string, default: "string" do
    validates :presence
    validates :inclusion, in: %w[string text integer float decimal boolean date datetime enum]
  end

  field :label, :string do
    validates :presence
  end

  field :description, :text
  field :section, :string, default: "Custom Fields"
  field :position, :integer, default: 0
  field :active, :boolean, default: true
  field :required, :boolean, default: false
  field :default_value, :string
  field :placeholder, :string
  field :min_length, :integer
  field :max_length, :integer
  field :min_value, :decimal, precision: 15, scale: 4
  field :max_value, :decimal, precision: 15, scale: 4
  field :precision, :integer
  field :enum_values, :json
  field :show_in_table, :boolean, default: false
  field :show_in_form, :boolean, default: true
  field :show_in_show, :boolean, default: true
  field :sortable, :boolean, default: false
  field :searchable, :boolean, default: false
  field :input_type, :string
  field :renderer, :string
  field :renderer_options, :json
  field :column_width, :string
  field :extra_validations, :json
  field :readable_by_roles, :json
  field :writable_by_roles, :json

  validates :field_name, :uniqueness, scope: :target_model,
    message: "has already been taken for this target model"
end
