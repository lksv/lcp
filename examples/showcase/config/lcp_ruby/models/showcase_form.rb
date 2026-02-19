define_model :showcase_form do
  label "Form Feature"
  label_plural "Form Features"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :form_type, :enum, label: "Type", default: "simple",
    values: { simple: "Simple", advanced: "Advanced", special: "Special" }
  field :priority, :integer, label: "Priority", default: 50
  field :satisfaction, :integer, label: "Satisfaction", default: 3
  field :is_premium, :boolean, label: "Premium", default: false
  field :detailed_notes, :rich_text, label: "Detailed Notes"
  field :config_data, :json, label: "Configuration"
  field :reason, :string, label: "Reason", limit: 255
  field :rejection_reason, :text, label: "Rejection Reason"
  field :advanced_field_1, :string, label: "Advanced Field 1", limit: 255
  field :advanced_field_2, :string, label: "Advanced Field 2", limit: 255

  timestamps true
  label_method :name
end
