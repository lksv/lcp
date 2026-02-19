define_presenter :region_admin do
  model :region
  label "Regions"
  slug "regions"
  icon "map"

  index do
    default_view :table
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, width: "50%", link_to: :show, sortable: true
    column "country.name", label: "Country", width: "50%", sortable: true
  end

  show do
    section "Region Information", columns: 2 do
      field :name, display: :heading
      field "country.name", label: "Country"
      field :created_at, display: :relative_date
    end
    association_list "Cities", association: :cities
  end

  form do
    section "Region Details", columns: 2 do
      field :name, placeholder: "Region name...", autofocus: true
      field :country_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name }
    end
  end

  search do
    searchable_fields :name
    placeholder "Search regions..."
  end

  action :create, type: :built_in, on: :collection, label: "New Region", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
