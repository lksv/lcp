define_presenter :contact_admin do
  model :contact
  label "Contacts"
  slug "contacts"
  icon "users"

  index do
    default_view :table
    default_sort :last_name, :asc
    per_page 25
    row_click :show

    column :full_name, width: "30%", link_to: :show, sortable: true
    column :email, width: "25%", display: :email_link
    column :phone, width: "15%", display: :phone_link
    column :active, width: "10%", display: :boolean_icon
  end

  show do
    section "Contact Information", columns: 2, responsive: { mobile: { columns: 1 } } do
      field :full_name, display: :heading
      field :email, display: :email_link
      field :phone, display: :phone_link
      field :position
      field :active, display: :boolean_icon
    end
  end

  form do
    section "Contact Details", columns: 2 do
      field :first_name, placeholder: "First name...", autofocus: true
      field :last_name, placeholder: "Last name..."
      field :email, placeholder: "email@example.com"
      field :phone, placeholder: "+1..."
      field :position, placeholder: "Job title..."
      field :active, input_type: :toggle
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

end
