define_model :role do
  label "Role"
  label_plural "Roles"

  field :name, :string, label: "Name", limit: 50, null: false, transforms: [ :strip ] do
    validates :presence
    validates :uniqueness
    validates :format, with: /\A[a-z][a-z0-9_]*\z/, message: "must start with a lowercase letter and contain only lowercase letters, digits, and underscores"
  end

  field :label, :string, label: "Label", limit: 100

  field :description, :text, label: "Description"

  field :active, :boolean, label: "Active", default: true

  field :position, :integer, label: "Position", default: 0

  scope :active_roles, where: { active: true }
  scope :inactive_roles, where: { active: false }

  timestamps true
  label_method :label
end
