define_model :employee_skill do
  label "Employee Skill"
  label_plural "Employee Skills"

  field :proficiency, :enum,
    values: {
      beginner: "Beginner",
      intermediate: "Intermediate",
      advanced: "Advanced",
      expert: "Expert"
    }

  field :certified, :boolean, default: false
  field :certified_at, :date
  field :expires_at, :date

  field :certificate, :attachment, options: {
    max_size: "5MB",
    content_types: %w[application/pdf image/jpeg image/png]
  }

  belongs_to :employee, model: :employee, required: true
  belongs_to :skill, model: :skill, required: true

  validates :employee_id, :uniqueness, scope: :skill_id

  timestamps true
end
