define_model :asset do
  label "Asset"
  label_plural "Assets"

  field :name, :string, label: "Name", limit: 255, null: false do
    validates :presence
  end

  field :asset_tag, :string, label: "Asset Tag", limit: 50, null: false do
    validates :presence
    validates :uniqueness
    validates :format, with: '\A[A-Z]{3}-\d{4}-\d{4}\z', message: "must match format XXX-0000-0000"
  end

  field :asset_uuid, :uuid, label: "Asset UUID"

  field :category, :enum, label: "Category",
    values: {
      laptop: "Laptop",
      phone: "Phone",
      monitor: "Monitor",
      desk: "Desk",
      chair: "Chair",
      vehicle: "Vehicle",
      access_card: "Access Card",
      other: "Other"
    }

  field :brand, :string, label: "Brand", limit: 100
  field :product_model, :string, label: "Model", limit: 100
  field :serial_number, :string, label: "Serial Number", limit: 100
  field :purchase_date, :date, label: "Purchase Date"

  field :purchase_price, :decimal, label: "Purchase Price", precision: 10, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :warranty_until, :date, label: "Warranty Until"

  field :status, :enum, label: "Status", default: "available",
    values: {
      available: "Available",
      assigned: "Assigned",
      in_repair: "In Repair",
      retired: "Retired"
    }

  field :photo, :attachment, label: "Photo", options: {
    accept: "image/*",
    max_size: "5MB",
    content_types: %w[image/jpeg image/png image/webp]
  }

  field :notes, :text, label: "Notes"

  has_many :asset_assignments, model: :asset_assignment, foreign_key: :asset_id, dependent: :nullify

  scope :available, where: { status: "available" }
  scope :assigned,  where: { status: "assigned" }
  scope :in_repair, where: { status: "in_repair" }

  display_template :default, template: "{name}", subtitle: "{asset_tag}", badge: "{status}"

  on_field_change :on_status_change, field: :status

  soft_delete
  auditing expand_custom_fields: true
  custom_fields true
  userstamps store_name: true

  timestamps true
  label_method :name
end
