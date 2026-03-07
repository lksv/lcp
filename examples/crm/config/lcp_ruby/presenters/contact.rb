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

    column :full_name, width: "20%", link_to: :show, sortable: true
    column "company.name", label: "Company", width: "15%"
    column "company.industry", label: "Industry", width: "10%", renderer: :badge
    column :email, width: "15%", renderer: :email_link
    column :phone, width: "10%", renderer: :phone_link
    column :activities_count, width: "10%", sortable: true
    column :completed_activities_count, width: "10%", sortable: true
    column :skills, width: "15%", renderer: :collection, options: { item_renderer: "badge", separator: " " }
    column :active, width: "10%", renderer: :boolean_icon

    item_class "lcp-row-muted", when: { field: :active, operator: :eq, value: false }
  end

  show do
    section "Contact Information", columns: 2, responsive: { mobile: { columns: 1 } } do
      field :full_name, renderer: :heading
      field :email, renderer: :email_link
      field :phone, renderer: :phone_link
      field :position
      field :active, renderer: :boolean_icon
      field :skills, renderer: :collection, options: { item_renderer: "badge", separator: " " }
      field :avatar, renderer: :attachment_preview, options: { variant: "medium" }
      field "company.name", label: "Company"
      field "company.industry", label: "Industry", renderer: :badge
      field :created_by_name
      field :updated_by_name
    end

    section "Activity Statistics", columns: 2 do
      field :activities_count
      field :completed_activities_count
    end

    # Dot-path condition: show deal info only for contacts at technology companies
    section "Technology Partner Details", columns: 2,
      visible_when: { field: "company.industry", operator: :eq, value: "technology" } do
      field "company.website", label: "Company Website", renderer: :url_link
      field "company.phone", label: "Company Phone", renderer: :phone_link
    end

    section "Documents" do
      field :documents, renderer: :attachment_list
    end

    association_list "Activities", association: :activities
  end

  form do
    section "Contact Details", columns: 2 do
      field :first_name, placeholder: "First name...", autofocus: true
      field :last_name, placeholder: "Last name..."
      field :email, placeholder: "email@example.com"
      field :phone, placeholder: "+1..."
      field :position, placeholder: "Job title..."
      field :skills, input_type: :array_input,
        input_options: {
          placeholder: "Add skill...",
          max: 15,
          suggestions: %w[Ruby Python JavaScript Java DevOps Cloud Finance Sales Marketing Legal]
        }
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
    searchable_fields :first_name, :last_name, :email, :skills
    placeholder "Search contacts..."

    advanced_filter do
      enabled true
      max_nesting_depth 2
      max_association_depth 1
      allow_or_groups true
      query_language true

      filterable_fields_except :position

      preset :active_contacts,
        label: "Active contacts",
        conditions: [
          { field: "active", operator: "eq", value: "true" }
        ]

      saved_filters do
        enabled true
        display :inline
        max_visible_pinned 3
      end
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Contact", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
