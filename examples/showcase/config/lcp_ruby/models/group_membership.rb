define_model :group_membership do
  label "Group Membership"
  label_plural "Group Memberships"

  field :user_id, :integer, label: "User ID", null: false do
    validates :presence
    validates :uniqueness, fields: [ :group_id, :user_id ]
  end

  field :source, :enum, label: "Source", values: %w[manual ldap api], default: "manual"

  belongs_to :group, model: :group, required: true

  timestamps true
  label_method :user_id
end
