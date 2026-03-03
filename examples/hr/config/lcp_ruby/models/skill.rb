define_model :skill do
  label "Skill"
  label_plural "Skills"

  field :name, :string, label: "Name", limit: 255, null: false do
    validates :presence
  end

  field :description, :text, label: "Description"

  field :category, :enum, label: "Category",
    values: {
      technical: "Technical",
      soft: "Soft",
      language: "Language",
      certification: "Certification"
    }

  field :parent_id, :integer

  has_many :employee_skills, model: :employee_skill, foreign_key: :skill_id, dependent: :destroy

  tree

  timestamps true
  label_method :name
end
