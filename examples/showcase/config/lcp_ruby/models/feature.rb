define_model :feature do
  label "Feature"
  label_plural "Feature Catalog"

  field :name, :string, label: "Feature Name", limit: 100, null: false do
    validates :presence
  end

  field :category, :enum, label: "Category", null: false,
    values: %w[field_types display_types input_types model_features presenter form permissions extensibility navigation attachments authentication] do
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
  scope :by_category_extensibility, where: { category: "extensibility" }
  scope :by_category_navigation, where: { category: "navigation" }
  scope :by_category_attachments, where: { category: "attachments" }
  scope :by_category_authentication, where: { category: "authentication" }
end
