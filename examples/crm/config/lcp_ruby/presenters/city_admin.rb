define_presenter :city_admin do
  model :city
  label "Cities"
  slug "cities"
  icon "map-pin"

  index do
    default_view :table
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, width: "40%", link_to: :show, sortable: true
    column "region.name", label: "Region", width: "30%", sortable: true
    column :population, width: "30%", sortable: true
  end

  show do
    section "City Information", columns: 2 do
      field :name, display: :heading
      field "region.name", label: "Region"
      field :population
      field :created_at, display: :relative_date
    end
  end

  form do
    section "City Details", columns: 2 do
      field :name, placeholder: "City name...", autofocus: true
      field :region_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name }
      field :population, input_type: :number, input_options: { min: 0 }
    end
  end

  search do
    searchable_fields :name
    placeholder "Search cities..."
  end

  action :create, type: :built_in, on: :collection, label: "New City", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
