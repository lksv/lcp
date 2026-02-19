define_model :showcase_field do
  label "Field Type"
  label_plural "Field Types"

  # String types
  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end
  field :description, :text, label: "Description"
  field :notes, :rich_text, label: "Notes"

  # Numeric types
  field :count, :integer, label: "Count", default: 0
  field :rating_value, :float, label: "Rating Value"
  field :price, :decimal, label: "Price", precision: 10, scale: 2

  # Boolean
  field :is_active, :boolean, label: "Active", default: true

  # Temporal types
  field :start_date, :date, label: "Start Date"
  field :event_time, :datetime, label: "Event Time"

  # Enum types
  field :status, :enum, label: "Status", default: "draft",
    values: {
      draft: "Draft",
      active: "Active",
      archived: "Archived",
      deleted: "Deleted"
    }

  field :priority, :enum, label: "Priority", default: "medium",
    values: {
      low: "Low",
      medium: "Medium",
      high: "High",
      critical: "Critical"
    }

  # Special types
  field :metadata, :json, label: "Metadata"
  field :external_id, :uuid, label: "External ID"

  # Business types
  field :email, :email, label: "Email"
  field :phone, :phone, label: "Phone"
  field :website, :url, label: "Website"
  field :brand_color, :color, label: "Brand Color"

  timestamps true
  label_method :title
end
