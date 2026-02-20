# frozen_string_literal: true

define_view_group :custom_fields do
  model :custom_field_definition
  primary :custom_fields
  navigation false

  view :custom_fields, label: "Custom Fields"
end
