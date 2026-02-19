define_presenter :showcase_permissions do
  model :showcase_permission
  label "Permissions"
  slug "showcase-permissions"
  icon "shield"

  index do
    description "Multi-role permissions demo. Switch roles to see different views."
    default_sort :created_at, :desc
    per_page 25

    column :title, link_to: :show, sortable: true
    column :status, renderer: :badge, options: {
      color_map: { open: "green", in_progress: "blue", locked: "orange", archived: "gray" }
    }, sortable: true
    column :priority, renderer: :badge, options: {
      color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
    }
    column :confidential, renderer: :boolean_icon
    column :owner_id, renderer: :number
  end

  show do
    description "Field visibility depends on the current user's role."

    section "Record Details", columns: 2 do
      field :title, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { open: "green", in_progress: "blue", locked: "orange", archived: "gray" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
      }
      field :confidential, renderer: :boolean_icon
      field :owner_id, renderer: :number
      field :assignee_id, renderer: :number
    end

    section "Notes", columns: 1 do
      field :public_notes
      field :internal_notes
    end
  end

  form do
    description "Writable fields depend on your role. Locked records cannot be edited (except by admin)."

    section "Record Details", columns: 2 do
      field :title, placeholder: "Enter title...", autofocus: true
      field :status, input_type: :select
      field :priority, input_type: :select
      field :confidential, input_type: :toggle
      field :owner_id, input_type: :number
      field :assignee_id, input_type: :number
    end

    section "Notes", columns: 1 do
      field :public_notes, input_type: :textarea
      field :internal_notes, input_type: :textarea, hint: "Only visible/writable by admin."
    end
  end

  search do
    searchable_fields :title
    placeholder "Search permissions demo..."
    filter :all, label: "All", default: true
    filter :open, label: "Open", scope: :open_items
    filter :in_progress, label: "In Progress", scope: :in_progress_items
  end

  action :create, type: :built_in, on: :collection, label: "New Record"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :lock, type: :custom, on: :single,
    label: "Lock", icon: "lock",
    confirm: true, confirm_message: "Lock this record? Only admins can edit locked records.",
    visible_when: { field: :status, operator: :not_eq, value: "locked" },
    style: :danger
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
