define_presenter :showcase_aggregate_items do
  model :showcase_aggregate_item
  label "Aggregate Tasks"
  slug "showcase-aggregate-items"
  icon "check-square"

  index do
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :title, link_to: :show, sortable: true
    column :status, renderer: :badge, options: {
      color_map: { todo: "gray", in_progress: "blue", done: "green", cancelled: "red" }
    }, sortable: true
    column :hours, sortable: true
    column :cost, renderer: :currency, sortable: true
    column :priority_score, sortable: true
    column :assignee, sortable: true
    column :due_date, renderer: :date, sortable: true
    column :showcase_aggregate_id, sortable: true
  end

  show do
    section "Task Details", columns: 2 do
      field :title, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { todo: "gray", in_progress: "blue", done: "green", cancelled: "red" }
      }
      field :hours
      field :cost, renderer: :currency
      field :priority_score
      field :assignee
      field :due_date, renderer: :date
      field :showcase_aggregate_id
    end
  end

  form do
    section "Task", columns: 2 do
      field :title, placeholder: "Task title...", autofocus: true, col_span: 2
      field :status, input_type: :select
      field :hours
      field :cost
      field :priority_score
      field :assignee, placeholder: "Assignee name..."
      field :due_date, input_type: :date
      field :showcase_aggregate_id, input_type: :association_select
    end
  end

  search do
    searchable_fields :title, :assignee
    placeholder "Search tasks..."
  end

  action :create, type: :built_in, on: :collection, label: "New Task", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
