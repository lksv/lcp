define_presenter :company do
  model :company
  label "Companies"
  slug "companies"
  icon "building"

  index do
    default_view :table
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, width: "30%", link_to: :show, sortable: true, pinned: :left
    column :industry, width: "20%", display: :badge, sortable: true
    column :website, width: "25%", display: :url_link
    column :phone, width: "25%", display: :phone_link
    column "contacts.first_name", label: "Contacts", display: :collection, display_options: { limit: 3, overflow: "..." }
  end

  show do
    section "Company Information", columns: 2 do
      field :name, display: :heading
      field :industry, display: :badge
      field :website, display: :url_link
      field :phone, display: :phone_link
      field :created_at, display: :relative_date
      field "contacts.first_name", label: "Contacts", display: :collection, display_options: { limit: 5 }
    end
    association_list "Contacts", association: :contacts
    association_list "Deals", association: :deals
  end

  form do
    layout :tabs

    section "Company Details", columns: 2 do
      field :name, placeholder: "Enter company name...", autofocus: true
      field :industry, input_type: :select
      field :website, placeholder: "https://..."
      field :phone, placeholder: "+1..."
    end

    section "Address", columns: 2 do
      field :address_type, input_type: :radio

      field :country_id, input_type: :association_select,
        visible_when: { field: :address_type, operator: :eq, value: "known" },
        input_options: {
          scope: "active",
          legacy_scope: "with_archived",
          sort: { name: :asc },
          allow_inline_create: true,
          label_method: :name
        }

      field :region_id, input_type: :association_select,
        visible_when: { field: :address_type, operator: :eq, value: "known" },
        input_options: {
          depends_on: { field: :country_id, foreign_key: :country_id },
          sort: { name: :asc },
          label_method: :name
        }

      field :city_id, input_type: :association_select,
        visible_when: { field: :address_type, operator: :eq, value: "known" },
        input_options: {
          depends_on: { field: :region_id, foreign_key: :region_id },
          search: true,
          search_fields: [ "name" ],
          per_page: 20,
          min_query_length: 1,
          sort: { name: :asc },
          disabled_scope: "small_cities",
          label_method: :name
        }

      field :street,
        visible_when: { field: :address_type, operator: :eq, value: "known" },
        placeholder: "Street address..."
    end
  end

  search do
    searchable_fields :name
    placeholder "Search companies..."
  end

  action :create, type: :built_in, on: :collection, label: "New Company", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
