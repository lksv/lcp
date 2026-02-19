define_model :department do
  label "Department"
  label_plural "Departments"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :code, :string, label: "Code", limit: 20, transforms: [:strip, :downcase] do
    validates :presence
    validates :uniqueness
  end

  belongs_to :parent, model: :department, required: false
  has_many :children, model: :department, foreign_key: :parent_id
  has_many :employees, model: :employee

  timestamps true
  label_method :name
end
