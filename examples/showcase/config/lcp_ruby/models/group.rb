define_model :group do
  label "Group"
  label_plural "Groups"

  field :name, :string, label: "Name", limit: 50, null: false, transforms: [ :strip ] do
    validates :presence
    validates :uniqueness
    validates :format, with: /\A[a-z][a-z0-9_]*\z/,
      message: "must start with a lowercase letter and contain only lowercase letters, digits, and underscores"
  end

  field :label, :string, label: "Label", limit: 100
  field :description, :text, label: "Description"
  field :external_id, :string, label: "External ID", limit: 255
  field :source, :enum, label: "Source", values: %w[manual ldap api], default: "manual"
  field :active, :boolean, label: "Active", default: true

  has_many :group_memberships, model: :group_membership, dependent: :destroy
  has_many :group_role_mappings, model: :group_role_mapping, dependent: :destroy

  scope :active_groups, where: { active: true }
  scope :inactive_groups, where: { active: false }

  timestamps true
  label_method :label
end
