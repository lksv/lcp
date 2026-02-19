define_presenter :country do
  model :country
  label "Countries"
  slug "countries"
  icon "globe"

  index do
    default_view :table
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, width: "50%", link_to: :show, sortable: true
    column :code, width: "20%", sortable: true
    column :active, width: "30%", display: :boolean_icon, sortable: true
  end

  show do
    section "Country Information", columns: 2 do
      field :name, display: :heading
      field :code
      field :active, display: :boolean_icon
      field :created_at, display: :relative_date
    end
    association_list "Regions", association: :regions
  end

  form do
    section "Country Details", columns: 2 do
      field :name, placeholder: "Country name...", autofocus: true
      field :code, placeholder: "e.g. CZE"
      field :active, input_type: :toggle
    end
  end

  search do
    searchable_fields :name, :code
    placeholder "Search countries..."
  end

  action :create, type: :built_in, on: :collection, label: "New Country", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
