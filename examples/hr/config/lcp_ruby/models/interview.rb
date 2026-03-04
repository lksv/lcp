define_model :interview do
  label "Interview"
  label_plural "Interviews"
  label_method :interview_type

  field :interview_type, :enum,
    values: {
      phone_screen: "Phone Screen",
      technical: "Technical",
      behavioral: "Behavioral",
      panel: "Panel",
      final: "Final"
    }

  field :scheduled_at, :datetime, null: false do
    validates :presence
  end

  field :duration_minutes, :integer, default: 60
  field :location, :string
  field :meeting_url, :url

  field :status, :enum, default: "scheduled",
    values: {
      scheduled: "Scheduled",
      completed: "Completed",
      cancelled: "Cancelled",
      no_show: "No Show"
    }

  field :rating, :integer do
    validates :numericality, greater_than_or_equal_to: 1, less_than_or_equal_to: 5, allow_nil: true
  end

  field :feedback, :text

  field :recommendation, :enum,
    values: {
      strong_yes: "Strong Yes",
      yes: "Yes",
      neutral: "Neutral",
      no: "No",
      strong_no: "Strong No"
    }

  field :notes, :json

  belongs_to :candidate, model: :candidate, required: true
  belongs_to :interviewer, model: :employee, required: true, foreign_key: :interviewer_id

  userstamps store_name: true

  timestamps true
end
