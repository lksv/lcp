define_model :leave_request do
  label "Leave Request"
  label_plural "Leave Requests"

  field :start_date, :date, null: false do
    validates :presence
  end

  field :end_date, :date, null: false do
    validates :presence
    validates :comparison, operator: :gte, field_ref: :start_date,
      message: "must be on or after start date"
  end

  field :days_count, :decimal, precision: 4, scale: 1

  field :status, :enum, default: "draft",
    values: {
      draft: "Draft",
      pending: "Pending",
      approved: "Approved",
      rejected: "Rejected",
      cancelled: "Cancelled"
    }

  field :reason, :text
  field :rejection_note, :text
  field :approved_at, :datetime

  field :attachment, :attachment, options: {
    max_size: "10MB",
    content_types: %w[application/pdf image/jpeg image/png]
  }

  belongs_to :employee, model: :employee, required: true
  belongs_to :leave_type, model: :leave_type, required: true
  belongs_to :approved_by, model: :employee, required: false, foreign_key: :approved_by_id

  validates_model :service, service: "leave_balance_check"

  on_field_change :on_status_change, field: :status

  scope :pending, where: { status: "pending" }
  scope :approved, where: { status: "approved" }
  scope :recent, order: { created_at: :desc }, limit: 10

  auditing
  userstamps store_name: true

  timestamps true
  label_method :start_date
end
