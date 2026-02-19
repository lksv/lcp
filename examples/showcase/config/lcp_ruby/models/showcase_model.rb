define_model :showcase_model do
  label "Model Feature"
  label_plural "Model Features"

  # Transforms: strip + presence + length + uniqueness
  field :name, :string, label: "Name", limit: 100, null: false, transforms: [:strip] do
    validates :presence
    validates :length, maximum: 100
    validates :uniqueness
  end

  # Transforms: strip + downcase, validates: format (regex)
  field :code, :string, label: "Code", limit: 50, transforms: [:strip, :downcase] do
    validates :presence
    validates :format, with: /\A[a-z0-9_-]+\z/, message: "only lowercase letters, numbers, hyphens and underscores"
  end

  # Enum with default
  field :status, :enum, label: "Status", default: "draft",
    values: {
      draft: "Draft",
      active: "Active",
      completed: "Completed",
      cancelled: "Cancelled"
    }

  # Conditional presence validation
  field :amount, :decimal, label: "Amount", precision: 10, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
    validates :presence, when: { field: :status, operator: :in, value: %w[active completed] }
  end

  # Default: current_date
  field :due_date, :date, label: "Due Date", default: "current_date"

  # Default: service
  field :auto_date, :date, label: "Auto Date",
    default: { service: "one_week_from_now" }

  # Computed: template
  field :computed_label, :string, label: "Computed Label",
    computed: { template: "{name} ({code})" }

  # Computed: service
  field :computed_score, :decimal, label: "Computed Score", precision: 10, scale: 2,
    computed: { service: "showcase_score" }

  # Business types with built-in transforms + validations
  field :email, :email, label: "Email"
  field :phone, :phone, label: "Phone"
  field :website, :url, label: "Website"

  # Comparison validators
  field :max_value, :integer, label: "Max Value", default: 100
  field :min_value, :integer, label: "Min Value" do
    validates :comparison, operator: :lt, field_ref: :max_value,
      message: "must be less than Max Value"
  end

  # JSON field
  field :tags_json, :json, label: "Tags (JSON)"

  # Scopes
  scope :active, where: { status: "active" }
  scope :draft, where: { status: "draft" }
  scope :overdue, where_not: { status: %w[completed cancelled] }
  scope :recent, order: { created_at: :desc }, limit: 10

  # Events
  on_field_change :on_status_change, field: :status

  timestamps true
  label_method :name
end
