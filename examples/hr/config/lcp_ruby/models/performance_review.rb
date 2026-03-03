define_model :performance_review do
  label "Performance Review"
  label_plural "Performance Reviews"

  field :review_period, :enum,
    values: {
      q1: "Q1",
      q2: "Q2",
      q3: "Q3",
      q4: "Q4",
      annual: "Annual"
    }

  field :year, :integer, null: false do
    validates :presence
  end

  field :status, :enum, default: "draft",
    values: {
      draft: "Draft",
      self_review: "Self Review",
      manager_review: "Manager Review",
      completed: "Completed",
      acknowledged: "Acknowledged"
    }

  field :self_rating, :integer do
    validates :numericality, greater_than_or_equal_to: 1, less_than_or_equal_to: 5, allow_nil: true
  end

  field :manager_rating, :integer do
    validates :numericality, greater_than_or_equal_to: 1, less_than_or_equal_to: 5, allow_nil: true
  end

  field :overall_rating, :integer do
    validates :numericality, greater_than_or_equal_to: 1, less_than_or_equal_to: 5, allow_nil: true
  end

  field :self_comments, :text
  field :manager_comments, :text
  field :goals_summary, :text
  field :strengths, :text
  field :improvements, :text
  field :completed_at, :datetime

  belongs_to :employee, model: :employee, required: true
  belongs_to :reviewer, model: :employee, required: true, foreign_key: :reviewer_id

  has_many :goals, model: :goal, foreign_key: :performance_review_id

  scope :in_progress, where_not: { status: [ "draft", "completed", "acknowledged" ] }
  scope :completed, where: { status: "completed" }

  auditing
  userstamps store_name: true

  timestamps true
end
