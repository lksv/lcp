define_presenter :group do
  model :group
  label "Groups"
  slug "groups"
  icon "users"

  index do
    column :name, link_to: :show
    column :code
    column :group_type, renderer: :badge
    column :active, renderer: :boolean_icon
  end

  show do
    section "Group Details", columns: 2 do
      field :name, renderer: :heading
      field :code, copyable: true
      field :description
      field :group_type, renderer: :badge
      field :active, renderer: :boolean_icon
    end

    association_list "Members", association: :group_memberships
  end

  form do
    section "Group Details", columns: 2 do
      field :name
      field :code
      field :description, input_type: :textarea
      field :group_type, input_type: :select
      field :active, input_type: :toggle
    end

    nested_fields "Members", association: :group_memberships,
      allow_add: true, allow_remove: true do
      field :employee_id, input_type: :association_select
      field :role_in_group, input_type: :select
      field :joined_at, input_type: :date_picker
      field :active, input_type: :checkbox
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Group", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true
end
