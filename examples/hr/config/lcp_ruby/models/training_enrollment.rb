define_model :training_enrollment do
  label "Training Enrollment"
  label_plural "Training Enrollments"

  field :status, :enum, default: "enrolled",
    values: {
      enrolled: "Enrolled",
      completed: "Completed",
      cancelled: "Cancelled",
      no_show: "No Show"
    }

  field :completed_at, :datetime

  field :score, :integer do
    validates :numericality, greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true
  end

  field :feedback, :text

  field :certificate, :attachment, options: {
    max_size: "5MB",
    content_types: %w[application/pdf]
  }

  belongs_to :employee, model: :employee, required: true
  belongs_to :training_course, model: :training_course, required: true

  validates :employee_id, :uniqueness, scope: :training_course_id

  userstamps store_name: true

  timestamps true
end
