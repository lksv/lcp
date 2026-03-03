define_presenter :position do
  model :position
  label "Positions"
  slug "positions"
  icon "briefcase"

  index do
    tree_view true
    reparentable true

    column :title, width: "25%", link_to: :show, sortable: true
    column :code, width: "15%", sortable: true
    column :level, width: "10%", sortable: true
    column :min_salary, width: "15%", renderer: :currency, options: { currency: "CZK" }
    column :max_salary, width: "15%", renderer: :currency, options: { currency: "CZK" }
    column :active, width: "10%", renderer: :boolean_icon
  end

  show do
    section "Position Details", columns: 2 do
      field :title, renderer: :heading
      field :code, copyable: true
      field :level
      field :min_salary, renderer: :currency, options: { currency: "CZK" }
      field :max_salary, renderer: :currency, options: { currency: "CZK" }
      field :active, renderer: :boolean_icon
      field "parent.title", label: "Parent Position", renderer: :internal_link
    end

    association_list "Employees", association: :employees
  end

  form do
    section "Position Details", columns: 2 do
      field :title, autofocus: true
      field :code
      field :level, input_type: :number
      field :min_salary, input_type: :number, prefix: "CZK"
      field :max_salary, input_type: :number, prefix: "CZK"
      field :active, input_type: :toggle
      field :parent_id, input_type: :tree_select
    end
  end

  search do
    searchable_fields :title, :code
    placeholder "Search positions..."
  end

  action :create, type: :built_in, on: :collection, label: "New Position", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
