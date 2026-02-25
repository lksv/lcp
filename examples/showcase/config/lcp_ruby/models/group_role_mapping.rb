define_model :group_role_mapping do
  label "Group Role Mapping"
  label_plural "Group Role Mappings"

  field :role_name, :string, label: "Role Name", limit: 50, null: false do
    validates :presence
    validates :uniqueness, fields: [:group_id, :role_name]
  end

  belongs_to :group, model: :group, required: true

  timestamps true
  label_method :role_name
end
