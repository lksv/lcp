define_presenter :company_admin do
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
    section "Company Details", columns: 2 do
      field :name, placeholder: "Enter company name...", autofocus: true
      field :industry, input_type: :select
      field :website, placeholder: "https://..."
      field :phone, placeholder: "+1..."
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
