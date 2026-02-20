define_presenter :roles do
  model :role
  label "Roles"
  slug "roles"
  icon "shield-check"

  index do
    description "DB-backed role management. Roles defined here are validated during authorization — unknown role names on users are filtered out and logged."
    default_sort :position, :asc
    per_page 25
    row_click :show

    column :name, link_to: :show, sortable: true, renderer: :code
    column :label, sortable: true, renderer: :heading
    column :description, renderer: :truncate, options: { max: 60 }
    column :active, renderer: :boolean_icon, sortable: true
    column :position, sortable: true, renderer: :number
  end

  show do
    description "Role details. The name must match role keys used in permissions YAML files."

    section "Role Details", columns: 2 do
      field :name, renderer: :code
      field :label, renderer: :heading
      field :active, renderer: :boolean_icon
      field :position, renderer: :number
    end

    section "Description" do
      field :description
    end
  end

  form do
    description "Role names are lowercase identifiers used in permissions YAML (e.g., admin, manager, viewer)."

    section "Role Details", columns: 2 do
      field :name, placeholder: "e.g. admin, manager, viewer", autofocus: true,
        hint: "Lowercase identifier matching keys in permissions YAML"
      field :label, placeholder: "e.g. Administrator, Manager"
      field :description, input_type: :textarea, col_span: 2
      field :active, input_type: :toggle
      field :position, input_type: :number
    end
  end

  search do
    searchable_fields :name, :label
    placeholder "Search roles..."
    filter :all, label: "All", default: true
    filter :active, label: "Active", scope: :active_roles
    filter :inactive, label: "Inactive", scope: :inactive_roles
  end

  action :create, type: :built_in, on: :collection, label: "New Role", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
