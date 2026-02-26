define_presenter :group_role_mappings do
  model :group_role_mapping
  label "Group Role Mappings"
  slug "group-role-mappings"
  icon "shield-check"

  index do
    description "Maps groups to authorization roles. Users in a group automatically gain the mapped roles."
    default_sort :role_name, :asc
    per_page 25
    row_click :show

    column "group.label", label: "Group"
    column :role_name, renderer: :code, sortable: true
    column :created_at, renderer: :datetime

    includes :group
  end

  show do
    section "Mapping Details", columns: 2 do
      field "group.label", label: "Group"
      field :role_name, renderer: :code
      field :created_at, renderer: :datetime
    end

    includes :group
  end

  form do
    section "Role Mapping", columns: 2 do
      field :group_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :label, include_blank: "Select group..." }
      field :role_name, placeholder: "e.g. editor, viewer",
        hint: "Must match a role name from the Roles list"
    end
  end

  search do
    searchable_fields :role_name
    placeholder "Search by role name..."
  end

  action :create, type: :built_in, on: :collection, label: "Add Mapping", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
