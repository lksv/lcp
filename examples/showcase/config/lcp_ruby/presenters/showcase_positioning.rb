define_presenter :showcase_positioning do
  model :showcase_positioning
  label "Priority List"
  slug "showcase-positioning"
  icon "list"

  index do
    description "Demonstrates drag-and-drop reordering. Drag rows to change order — position updates automatically."
    reorderable true
    per_page 25
    row_click :show

    column :name, link_to: :show
    column :status, renderer: :badge, options: {
      color_map: { todo: "gray", in_progress: "blue", done: "green" }
    }
    column :priority, renderer: :badge, options: {
      color_map: { low: "gray", medium: "blue", high: "orange", critical: "red" }
    }
    column :position, sortable: false
  end

  show do
    section "Item Details", columns: 2 do
      field :name, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { todo: "gray", in_progress: "blue", done: "green" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "gray", medium: "blue", high: "orange", critical: "red" }
      }
      field :position, renderer: :number
    end

    section "Description" do
      field :description
    end
  end

  form do
    description "Position is managed automatically via drag-and-drop on the index page."

    section "Item Details", columns: 2 do
      field :name, autofocus: true
      field :status, input_type: :select
      field :priority, input_type: :select
      field :description, input_type: :textarea, input_options: { rows: 3 }
    end
  end

  search do
    searchable_fields :name, :description
    placeholder "Search priority items..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Item", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
