define_presenter :showcase_aggregates do
  model :showcase_aggregate
  label "Aggregates"
  slug "showcase-aggregates"
  icon "calculator"

  index do
    description "Demonstrates aggregate columns — virtual computed values (COUNT, SUM, AVG, MIN, MAX) " \
                "from associated records via SQL subqueries. All columns are sortable."
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, width: "20%", link_to: :show, sortable: true, pinned: :left
    column :status, width: "10%", renderer: :badge, options: {
      color_map: { planning: "gray", active: "green", completed: "blue", archived: "orange" }
    }, sortable: true
    column :tasks_count, width: "8%", sortable: true
    column :completed_count, width: "8%", sortable: true
    column :unique_assignees, width: "8%", sortable: true
    column :total_hours, width: "10%", sortable: true
    column :completed_cost, width: "10%", renderer: :currency, sortable: true
    column :avg_priority, width: "8%", sortable: true
    column :earliest_due_date, width: "10%", renderer: :date, sortable: true
    column :latest_due_date, width: "10%", renderer: :date, sortable: true
  end

  show do
    description "All aggregate values below are computed dynamically from associated tasks via SQL subqueries — no stored counters."

    section "Project", columns: 2 do
      field :name, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { planning: "gray", active: "green", completed: "blue", archived: "orange" }
      }
      field :description
      field :budget, renderer: :currency
    end

    section "Task Statistics", columns: 2, description: "Computed via COUNT, SUM, and AVG aggregates over associated tasks." do
      field :tasks_count
      field :completed_count
      field :unique_assignees
      field :total_hours
      field :completed_cost, renderer: :currency
      field :avg_priority
    end

    section "Date Range", columns: 2, description: "MIN and MAX aggregates on the due_date field." do
      field :earliest_due_date, renderer: :date
      field :latest_due_date, renderer: :date
    end

    association_list "Tasks", association: :showcase_aggregate_items,
      display_template: :default, link: false,
      empty_message: "No tasks yet."
  end

  form do
    section "Project", columns: 2 do
      field :name, placeholder: "Project name...", autofocus: true, col_span: 2
      field :status, input_type: :select
      field :budget
    end

    section "Description" do
      field :description, input_type: :textarea, input_options: { rows: 4 }
    end
  end

  search do
    searchable_fields :name, :description
    placeholder "Search projects..."
  end

  action :create, type: :built_in, on: :collection, label: "New Project", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
