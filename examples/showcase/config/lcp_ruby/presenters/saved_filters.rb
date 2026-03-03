define_presenter :saved_filters do
  model :saved_filter
  label "Saved Filters"
  slug "saved-filters"
  icon "bookmark"

  index do
    description "Management view for saved filter records. Browse, edit, and delete user-created filters across all presenters."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :name, link_to: :show, sortable: true
    column :target_presenter, sortable: true
    column :visibility, renderer: :badge, options: {
      color_map: { personal: "blue", role: "orange", group: "purple", global: "green" }
    }, sortable: true
    column :pinned, renderer: :boolean
    column :default_filter, renderer: :boolean
    column :owner_id, sortable: true
    column :created_at, renderer: :relative_date, sortable: true
  end

  show do
    section "Filter Details", columns: 2 do
      field :name, renderer: :heading
      field :description, renderer: :text
      field :target_presenter
      field :visibility, renderer: :badge, options: {
        color_map: { personal: "blue", role: "orange", group: "purple", global: "green" }
      }
    end

    section "Targeting", columns: 2 do
      field :owner_id
      field :target_role
      field :target_group
    end

    section "Display", columns: 2 do
      field :pinned, renderer: :boolean
      field :default_filter, renderer: :boolean
      field :position
      field :icon
      field :color
    end

    section "Query" do
      field :ql_text, renderer: :code
    end

    section "Metadata", columns: 2 do
      field :created_at, renderer: :relative_date
      field :updated_at, renderer: :relative_date
    end
  end

  form do
    section "Filter Details", columns: 2 do
      field :name, placeholder: "Filter name...", autofocus: true
      field :description, input_type: :textarea, input_options: { rows: 2 }
      field :target_presenter, placeholder: "e.g. showcase-search"
      field :visibility, input_type: :select
    end

    section "Targeting", columns: 2 do
      field :target_role, placeholder: "e.g. admin"
      field :target_group, placeholder: "e.g. engineering"
    end

    section "Display", columns: 2 do
      field :pinned, input_type: :toggle
      field :default_filter, input_type: :toggle
      field :position, input_type: :number
      field :icon, placeholder: "e.g. star"
      field :color, placeholder: "e.g. blue"
    end
  end

  search do
    searchable_fields :name, :description, :target_presenter
    placeholder "Search saved filters..."
    filter :all, label: "All", default: true
    filter :personal, label: "Personal", scope: :personal_only
    filter :global, label: "Global", scope: :global_only
    filter :role, label: "Role", scope: :role_only
    filter :pinned, label: "Pinned", scope: :pinned_only
  end

  action :create, type: :built_in, on: :collection, label: "New Filter", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
