define_presenter :contact do
  model :contact
  label "Contacts"
  slug "contacts"
  icon "users"

  index do
    default_view :table
    default_sort :last_name, :asc
    per_page 25
    row_click :show

    column :full_name, width: "25%", link_to: :show, sortable: true
    column "company.name", label: "Company", width: "15%"
    column "company.industry", label: "Industry", width: "10%", renderer: :badge
    column :email, width: "20%", renderer: :email_link
    column :phone, width: "15%", renderer: :phone_link
    column :active, width: "10%", renderer: :boolean_icon
  end

  show do
    section "Contact Information", columns: 2, responsive: { mobile: { columns: 1 } } do
      field :full_name, renderer: :heading
      field :email, renderer: :email_link
      field :phone, renderer: :phone_link
      field :position
      field :active, renderer: :boolean_icon
      field :avatar, renderer: :attachment_preview, options: { variant: "medium" }
      field "company.name", label: "Company"
      field "company.industry", label: "Industry", renderer: :badge
    end

    section "Documents" do
      field :documents, renderer: :attachment_list
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
      field :avatar, input_options: { preview: true, drag_drop: true }
      field :company_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, group_by: :industry }
    end

    section "Documents" do
      field :documents, input_options: { preview: true, drag_drop: true }
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
