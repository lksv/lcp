define_presenter :group_memberships do
  model :group_membership
  label "Group Memberships"
  slug "group-memberships"
  icon "user-plus"

  index do
    description "Group membership records linking users to groups."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column "group.label", label: "Group"
    column :user_id, sortable: true
    column :source, renderer: :badge, options: {
      color_map: { manual: "blue", ldap: "purple", api: "teal" }
    }
    column :created_at, renderer: :datetime

    includes :group
  end

  show do
    section "Membership Details", columns: 2 do
      field "group.label", label: "Group"
      field :user_id
      field :source, renderer: :badge, options: {
        color_map: { manual: "blue", ldap: "purple", api: "teal" }
      }
      field :created_at, renderer: :datetime
    end

    includes :group
  end

  form do
    section "Membership", columns: 2 do
      field :group_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :label, include_blank: "Select group..." }
      field :user_id, input_type: :number, hint: "User ID from the host application"
      field :source, input_type: :select
    end
  end

  search do
    searchable_fields :user_id
    placeholder "Search by user ID..."
  end

  action :create, type: :built_in, on: :collection, label: "Add Member", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
