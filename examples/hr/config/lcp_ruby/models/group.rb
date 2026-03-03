define_model :group do
  label "Group"
  label_plural "Groups"

  field :name, :string, null: false do
    validates :presence
    validates :uniqueness
  end

  field :code, :string, null: false do
    validates :presence
    validates :uniqueness
  end

  field :description, :text

  field :group_type, :enum,
    values: {
      committee: "Committee",
      project: "Project",
      interest: "Interest",
      cross_functional: "Cross-functional",
      temporary: "Temporary"
    }

  field :active, :boolean, default: true

  has_many :group_memberships, model: :group_membership, dependent: :destroy,
    nested_attributes: { allow_destroy: true }
  has_many :employees, model: :employee, through: :group_memberships

  auditing
  userstamps store_name: true

  timestamps true
  label_method :name
end
