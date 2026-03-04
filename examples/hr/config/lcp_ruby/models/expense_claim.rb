define_model :expense_claim do
  label "Expense Claim"
  label_plural "Expense Claims"
  label_method :title

  field :title, :string, null: false do
    validates :presence
  end

  field :description, :text

  field :amount, :decimal, precision: 10, scale: 2, null: false do
    validates :presence
    validates :numericality, greater_than: 0
  end

  field :currency, :enum, default: "CZK",
    values: {
      CZK: "CZK",
      EUR: "EUR",
      USD: "USD",
      GBP: "GBP"
    }

  field :category, :enum,
    values: {
      travel: "Travel",
      meals: "Meals",
      accommodation: "Accommodation",
      equipment: "Equipment",
      education: "Education",
      other: "Other"
    }

  field :status, :enum, default: "draft",
    values: {
      draft: "Draft",
      submitted: "Submitted",
      approved: "Approved",
      rejected: "Rejected",
      reimbursed: "Reimbursed"
    }

  field :receipt, :attachment, options: {
    multiple: true,
    max_files: 10,
    max_size: "10MB"
  }

  field :expense_date, :date, null: false do
    validates :presence
  end

  field :approved_at, :datetime
  field :rejection_note, :text
  field :items, :json

  validates_model :service, service: "expense_receipt_required"

  belongs_to :employee, model: :employee, required: true
  belongs_to :approved_by, model: :employee, required: false, foreign_key: :approved_by_id

  scope :pending, where: { status: "submitted" }
  scope :approved, where: { status: "approved" }

  auditing
  userstamps store_name: true

  timestamps true
end
