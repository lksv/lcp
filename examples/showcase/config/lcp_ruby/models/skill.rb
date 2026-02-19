define_model :skill do
  label "Skill"
  label_plural "Skills"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
    validates :uniqueness
  end
  field :category, :enum, label: "Category",
    values: {
      technical: "Technical",
      soft: "Soft Skills",
      management: "Management",
      language: "Language"
    }

  has_many :employee_skills, model: :employee_skill, dependent: :destroy
  has_many :employees, through: :employee_skills

  timestamps true
  label_method :name
end
