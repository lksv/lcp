define_model :feature do
  label "Feature"
  label_plural "Feature Catalog"

  field :name, :string, label: "Feature Name", limit: 100, null: false do
    validates :presence
  end

  field :category, :enum, label: "Category", null: false,
    values: %w[field_types display_types input_types model_features presenter form permissions permission_source role_source extensibility navigation attachments authentication custom_fields virtual_fields] do
    validates :presence
  end

  field :description, :text, label: "Description"
  field :config_example, :text, label: "Configuration Example"
  field :demo_path, :string, label: "Demo Link", limit: 255
  field :demo_hint, :text, label: "What to Look For"

  field :status, :enum, label: "Status",
    values: %w[stable beta planned], default: "stable"

  timestamps true
  label_method :name

  scope :by_category_field_types, where: { category: "field_types" }
  scope :by_category_display_types, where: { category: "display_types" }
  scope :by_category_input_types, where: { category: "input_types" }
  scope :by_category_model_features, where: { category: "model_features" }
  scope :by_category_presenter, where: { category: "presenter" }
  scope :by_category_form, where: { category: "form" }
  scope :by_category_permissions, where: { category: "permissions" }
  scope :by_category_permission_source, where: { category: "permission_source" }
  scope :by_category_role_source, where: { category: "role_source" }
  scope :by_category_extensibility, where: { category: "extensibility" }
  scope :by_category_navigation, where: { category: "navigation" }
  scope :by_category_attachments, where: { category: "attachments" }
  scope :by_category_authentication, where: { category: "authentication" }
  scope :by_category_custom_fields, where: { category: "custom_fields" }
  scope :by_category_virtual_fields, where: { category: "virtual_fields" }
end
