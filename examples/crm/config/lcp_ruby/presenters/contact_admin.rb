define_presenter :contact_admin do
  model :contact
  label "Contacts"
  slug "contacts"
  icon "users"

  index do
    default_view :table
    default_sort :last_name, :asc
    per_page 25
    column :first_name, width: "20%", link_to: :show, sortable: true
    column :last_name, width: "20%", sortable: true
    column :email, width: "25%"
    column :position, width: "20%"
  end

  show do
    section "Contact Information", columns: 2 do
      field :first_name, display: :heading
      field :last_name
      field :email
      field :phone
      field :position
    end
  end

  form do
    section "Contact Details", columns: 2 do
      field :first_name, placeholder: "First name...", autofocus: true
      field :last_name, placeholder: "Last name..."
      field :email, placeholder: "email@example.com"
      field :phone, placeholder: "+1..."
      field :position, placeholder: "Job title..."
      field :company_id, input_type: :association_select
    end
  end

  search do
    searchable_fields :first_name, :last_name, :email
    placeholder "Search contacts..."
  end

  action :create, type: :built_in, on: :collection, label: "New Contact", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger

  navigation menu: :main, position: 2
end
