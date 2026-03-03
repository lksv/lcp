define_model :training_course do
  label "Training Course"
  label_plural "Training Courses"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end

  field :description, :rich_text, label: "Description"

  field :category, :enum, label: "Category",
    values: {
      onboarding: "Onboarding",
      technical: "Technical",
      compliance: "Compliance",
      leadership: "Leadership",
      safety: "Safety",
      other: "Other"
    }

  field :format, :enum, label: "Format",
    values: {
      in_person: "In Person",
      online: "Online",
      hybrid: "Hybrid"
    }

  field :duration_hours, :decimal, label: "Duration (hours)", precision: 5, scale: 1 do
    validates :numericality, greater_than: 0, allow_nil: true
  end

  field :max_participants, :integer, label: "Max Participants" do
    validates :numericality, greater_than: 0, allow_nil: true
  end

  field :instructor, :string, label: "Instructor", limit: 255
  field :location, :string, label: "Location", limit: 255
  field :url, :url, label: "URL"
  field :starts_at, :datetime, label: "Starts At"
  field :ends_at, :datetime, label: "Ends At"
  field :active, :boolean, label: "Active", default: true

  has_many :training_enrollments, model: :training_enrollment, foreign_key: :training_course_id, dependent: :destroy

  scope :active,   where: { active: true }
  scope :upcoming, order: { starts_at: :asc }

  soft_delete
  userstamps store_name: true

  timestamps true
  label_method :title
end
