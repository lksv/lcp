define_presenter :organization_unit do
  model :organization_unit
  label "Organization Units"
  slug "organization-units"
  icon "git-branch"

  index do
    tree_view true
    default_expanded 2
    reparentable true

    column :name, width: "30%", link_to: :show, sortable: true
    column :code, width: "15%", sortable: true
    column :budget, width: "15%", renderer: :currency, options: { currency: "CZK" }
    column :active, width: "10%", renderer: :boolean_icon
    column "head.full_name", label: "Head", width: "20%"
  end

  show do
    section "Unit Details", columns: 2 do
      field :name, renderer: :heading
      field :code, copyable: true
      field :description
      field :budget, renderer: :currency, options: { currency: "CZK" }
      field :active, renderer: :boolean_icon
      field "parent.name", label: "Parent Unit", renderer: :internal_link
      field "head.full_name", label: "Head", renderer: :internal_link
    end

    association_list "Employees", association: :employees, limit: 20, display_template: :default
    association_list "Sub-Units", association: :children
  end

  form do
    section "Unit Details", columns: 2 do
      field :name, autofocus: true
      field :code
      field :description, input_type: :textarea
      field :budget, input_type: :number, prefix: "CZK"
      field :active, input_type: :toggle
      field :parent_id, input_type: :tree_select
      field :head_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
    end
  end

  search do
    searchable_fields :name, :code
    placeholder "Search organization units..."
  end

  action :create, type: :built_in, on: :collection, label: "New Unit", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
