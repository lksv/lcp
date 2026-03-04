define_model :group_membership do
  label "Group Membership"
  label_plural "Group Memberships"
  label_method :role_in_group

  field :role_in_group, :enum, default: "member",
    values: {
      member: "Member",
      lead: "Lead",
      admin: "Admin"
    }

  field :joined_at, :date, null: false do
    validates :presence
  end

  field :left_at, :date
  field :active, :boolean, default: true

  belongs_to :group, model: :group, required: true
  belongs_to :employee, model: :employee, required: true

  userstamps store_name: true

  timestamps true
end
