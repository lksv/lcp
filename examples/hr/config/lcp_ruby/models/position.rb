define_model :position do
  label "Position"
  label_plural "Positions"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end

  field :code, :string, label: "Code", limit: 50, null: false do
    validates :presence
    validates :uniqueness
  end

  field :level, :integer, label: "Level" do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :min_salary, :decimal, label: "Min Salary", precision: 10, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :max_salary, :decimal, label: "Max Salary", precision: 10, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
    validates :comparison, operator: :gt, field_ref: :min_salary,
      message: "must be greater than min salary"
  end

  field :active, :boolean, label: "Active", default: true
  field :parent_id, :integer
  field :position, :integer

  has_many :employees, model: :employee, foreign_key: :position_id
  has_many :job_postings, model: :job_posting, foreign_key: :position_id

  scope :active, where: { active: true }

  tree
  positioning field: :position, scope: :parent_id
  soft_delete

  timestamps true
  label_method :title
end
