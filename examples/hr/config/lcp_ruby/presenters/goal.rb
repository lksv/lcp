define_presenter :goal do
  model :goal
  label "Goals"
  slug "goals"
  icon "target"

  index do
    reorderable true

    column :title, width: "22%", link_to: :show, sortable: true
    column "employee.full_name", label: "Employee", width: "18%", sortable: true
    column :status, width: "10%", renderer: :badge, options: { color_map: { not_started: "gray", in_progress: "blue", completed: "green", cancelled: "red" } }, sortable: true
    column :priority, width: "10%", renderer: :badge, options: { color_map: { low: "gray", medium: "blue", high: "orange", critical: "red" } }, sortable: true
    column :due_date, width: "12%", renderer: :date, sortable: true
    column :progress, width: "15%", renderer: :progress_bar
    column :weight, width: "8%"
  end

  show do
    section "Goal Details", columns: 2 do
      field :title, renderer: :heading
      field :description
      field "employee.full_name", label: "Employee", renderer: :internal_link
      field :status, renderer: :badge, options: { color_map: { not_started: "gray", in_progress: "blue", completed: "green", cancelled: "red" } }
      field :priority, renderer: :badge, options: { color_map: { low: "gray", medium: "blue", high: "orange", critical: "red" } }
      field :due_date, renderer: :date
      field :progress, renderer: :progress_bar
      field :weight
    end
  end

  form do
    section "Goal Details", columns: 2 do
      field :title, autofocus: true
      field :description, input_type: :textarea
      field :employee_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :performance_review_id, input_type: :association_select
      field :status, input_type: :select
      field :priority, input_type: :select
      field :due_date, input_type: :date
      field :progress, input_type: :slider, input_options: { min: 0, max: 100, step: 5 }
      field :weight, input_type: :number
    end
  end

  search do
    searchable_fields :title
    placeholder "Search goals..."

    filter :all, label: "All", default: true
    filter :in_progress, label: "In Progress", scope: :in_progress
    filter :completed, label: "Completed", scope: :completed
  end

  action :create, type: :built_in, on: :collection, label: "New Goal", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
