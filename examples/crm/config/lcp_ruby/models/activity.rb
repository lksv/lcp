define_model :activity do
  label "Activity"
  label_plural "Activities"

  field :subject, :string, label: "Subject", limit: 255, null: false do
    validates :presence
  end

  field :activity_type, :enum, label: "Type", null: false,
    values: {
      call: "Call",
      meeting: "Meeting",
      email: "Email",
      note: "Note",
      task: "Task"
    } do
    validates :presence
  end

  field :description, :text, label: "Description"
  field :scheduled_at, :datetime, label: "Scheduled At"

  field :completed, :boolean, label: "Completed", default: false
  field :completed_at, :datetime, label: "Completed At"
  field :outcome, :text, label: "Outcome"

  belongs_to :company, model: :company, required: true
  belongs_to :contact, model: :contact, required: false
  belongs_to :deal, model: :deal, required: false

  scope :pending, where: { completed: false }
  scope :completed_activities, where: { completed: true }

  scope :scheduled_within_days, type: :parameterized, parameters: [
    { name: :days, type: :integer, default: 7, min: 1, max: 90 }
  ]

  userstamps

  timestamps true
  label_method :subject
end
