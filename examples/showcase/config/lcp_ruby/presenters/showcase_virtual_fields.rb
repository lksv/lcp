define_presenter :showcase_virtual_fields do
  model :showcase_virtual_field
  label "Virtual Fields"
  slug "showcase-virtual-fields"
  icon "zap"

  index do
    description "Demonstrates virtual fields: JSON-backed service accessors and external computed fields."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :name, link_to: :show, sortable: true
    column :color, sortable: false
    column :priority, renderer: :number, sortable: false
    column :unit_price, renderer: :currency, options: { currency: "USD" }, sortable: false
    column :featured, renderer: :boolean_icon, sortable: false
    column :category, renderer: :badge, options: {
      color_map: {
        electronics: "blue", clothing: "purple", food: "green",
        furniture: "orange", other: "gray"
      }
    }, sortable: false
    column :priority_label
  end

  show do
    description "Each section groups virtual fields by source type."

    section "Identity", columns: 2 do
      field :name, renderer: :heading
      field :created_at, renderer: :relative_date
    end

    section "Service Accessor Fields", columns: 2,
      description: "These fields are stored in the `properties` JSON column and accessed via the `json_field` service." do
      field :color
      field :priority, renderer: :number
      field :unit_price, renderer: :currency, options: { currency: "USD" }
      field :featured, renderer: :boolean_icon
      field :category, renderer: :badge, options: {
        color_map: {
          electronics: "blue", clothing: "purple", food: "green",
          furniture: "orange", other: "gray"
        }
      }
      field :warehouse
      field :release_date, renderer: :date
      field :sku_code, renderer: :code
    end

    section "Location & External Fields", columns: 2,
      description: "city and country are JSON-backed. full_location and priority_label use `source: external` with host-defined methods." do
      field :city
      field :country
      field :full_location
      field :priority_label
    end

    section "Raw JSON", columns: 1 do
      field :properties, renderer: :code
    end

    section "Metadata", columns: 1 do
      field :updated_at, renderer: :relative_date
    end
  end

  form do
    description "Virtual fields are editable through their accessor methods — the JSON column is updated transparently."

    section "Identity", columns: 2 do
      field :name, placeholder: "Enter name...", autofocus: true
    end

    section "Service Accessor Fields", columns: 2,
      description: "Each field reads/writes a key in the `properties` JSON column." do
      field :color, hint: "String stored in JSON"
      field :priority, input_type: :number, hint: "Integer 1–5"
      field :unit_price, input_type: :number, prefix: "$", hint: "Decimal stored in JSON"
      field :featured, input_type: :checkbox, hint: "Boolean stored in JSON"
      field :category, input_type: :select, hint: "Enum with inclusion validation"
      field :warehouse, hint: "Defaults to MAIN-01 if left blank"
      field :release_date, input_type: :date_picker, hint: "Date stored in JSON"
      field :sku_code, hint: "Another string field from the same JSON column"
    end

    section "Location", columns: 2,
      description: "City and country are JSON-backed. Full location is computed externally." do
      field :city, hint: "Stored in properties JSON"
      field :country, hint: "Stored in properties JSON"
    end
  end

  search do
    searchable_fields :name
    placeholder "Search virtual fields..."
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
