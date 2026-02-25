define_presenter :groups do
  model :group
  label "Groups"
  slug "groups"
  icon "users-cog"

  index do
    description "DB-backed group management. Groups map organizational units to authorization roles via memberships and role mappings."
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, link_to: :show, sortable: true, renderer: :code
    column :label, sortable: true, renderer: :heading
    column :description, renderer: :truncate, options: { max: 60 }
    column :source, renderer: :badge, options: {
      color_map: { manual: "blue", ldap: "purple", api: "teal" }
    }
    column :active, renderer: :boolean_icon, sortable: true
  end

  show do
    description "Group details with memberships and role mappings."

    section "Group Details", columns: 2 do
      field :name, renderer: :code
      field :label, renderer: :heading
      field :active, renderer: :boolean_icon
      field :source, renderer: :badge, options: {
        color_map: { manual: "blue", ldap: "purple", api: "teal" }
      }
      field :external_id
    end

    section "Description" do
      field :description
    end

    association_list "Members", association: :group_memberships, link: true,
      empty_message: "No members assigned to this group."

    association_list "Role Mappings", association: :group_role_mappings, link: true,
      empty_message: "No role mappings defined for this group."

    includes :group_memberships, :group_role_mappings
  end

  form do
    description "Group names are lowercase identifiers used for group membership lookup."

    section "Group Details", columns: 2 do
      field :name, placeholder: "e.g. engineering, sales_team", autofocus: true,
        hint: "Lowercase identifier for group membership"
      field :label, placeholder: "e.g. Engineering Team"
      field :description, input_type: :textarea, col_span: 2
      field :external_id, placeholder: "e.g. CN=Engineering,OU=Groups,DC=corp"
      field :source, input_type: :select
      field :active, input_type: :toggle
    end
  end

  search do
    searchable_fields :name, :label
    placeholder "Search groups..."
    filter :all, label: "All", default: true
    filter :active, label: "Active", scope: :active_groups
    filter :inactive, label: "Inactive", scope: :inactive_groups
  end

  action :create, type: :built_in, on: :collection, label: "New Group", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
