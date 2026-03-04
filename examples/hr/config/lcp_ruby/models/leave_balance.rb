define_model :leave_balance do
  label "Leave Balance"
  label_plural "Leave Balances"
  label_method :year

  field :year, :integer, null: false, default: { service: "current_year" } do
    validates :presence
  end

  field :total_days, :decimal, precision: 4, scale: 1, null: false do
    validates :presence
  end

  field :used_days, :decimal, precision: 4, scale: 1, default: 0

  field :remaining, :decimal, precision: 4, scale: 1,
    computed: { service: "leave_remaining" }

  belongs_to :employee, model: :employee, required: true
  belongs_to :leave_type, model: :leave_type, required: true

  validates :employee_id, :uniqueness, scope: [ :leave_type_id, :year ]

  scope :for_year, type: :parameterized, parameters: [
    { name: :year, type: :integer, default: 2026 }
  ]

  userstamps store_name: true

  timestamps true
end
