define_presenter :departments do
  model :department
  label "Departments"
  slug "departments"
  icon "building"

  index do
    tree_view true
    default_expanded 2
    reparentable true

    column :name, link_to: :show
    column :code
  end

  show do
    section "Department Details", columns: 2 do
      field :name, renderer: :heading
      field :code
      field "parent.name", label: "Parent Department"
    end

    association_list "Employees", association: :employees, link: true,
      empty_message: "No employees in this department."

    includes :parent, :employees
  end

  form do
    section "Department Details", columns: 2 do
      field :name, placeholder: "Department name...", autofocus: true
      field :code, placeholder: "e.g. eng, hr, sales..."
      field :parent_id, input_type: :tree_select,
        input_options: { parent_field: :parent_id, label_method: :name, max_depth: 3 }
    end
  end

  search do
    searchable_fields :name, :code
    placeholder "Search departments..."
  end

  action :create, type: :built_in, on: :collection, label: "New Department"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
