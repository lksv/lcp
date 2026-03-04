define_model :goal do
  label "Goal"
  label_plural "Goals"
  label_method :title

  field :title, :string, null: false do
    validates :presence
  end

  field :description, :text

  field :status, :enum, default: "not_started",
    values: {
      not_started: "Not Started",
      in_progress: "In Progress",
      completed: "Completed",
      cancelled: "Cancelled"
    }

  field :priority, :enum, default: "medium",
    values: {
      low: "Low",
      medium: "Medium",
      high: "High",
      critical: "Critical"
    }

  field :due_date, :date

  field :progress, :integer, default: 0 do
    validates :numericality, greater_than_or_equal_to: 0, less_than_or_equal_to: 100
  end

  field :weight, :integer, default: 1
  field :position, :integer

  belongs_to :employee, model: :employee, required: true
  belongs_to :performance_review, model: :performance_review, required: false

  scope :in_progress, where: { status: "in_progress" }
  scope :completed, where: { status: "completed" }

  positioning field: :position

  userstamps store_name: true

  timestamps true
end
