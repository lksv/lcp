define_presenter :showcase_aggregates do
  model :showcase_aggregate
  label "Virtual Columns"
  slug "showcase-aggregates"
  icon "calculator"

  index do
    description "Demonstrates the full virtual columns system — declarative aggregates (COUNT, SUM, AVG, MIN, MAX), " \
                "expression columns, JOIN-based columns, window functions, service columns, auto_include, " \
                "and item_classes with virtual column conditions. All columns are sortable."
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, width: "15%", link_to: :show, sortable: true, pinned: :left
    column :status, width: "8%", renderer: :badge, options: {
      color_map: { planning: "gray", active: "green", completed: "blue", archived: "orange" }
    }, sortable: true
    column :company_name, width: "10%", sortable: true
    column :tasks_count, width: "6%", sortable: true
    column :completed_count, width: "6%", sortable: true
    column :health_score, width: "6%", renderer: :number, sortable: true
    column :has_overdue_tasks, width: "7%", renderer: :boolean_icon, sortable: true
    column :is_over_budget, width: "7%", renderer: :boolean_icon, sortable: true
    column :budget_per_task, width: "8%", renderer: :currency, sortable: true
    column :total_hours, width: "7%", sortable: true
    column :completed_cost, width: "8%", renderer: :currency, sortable: true
    column :budget_rank, width: "6%", sortable: true
    column :unique_assignees, width: "6%", sortable: true

    # Row styling using virtual column conditions
    item_class "lcp-row-danger",
      when: { field: :has_overdue_tasks, operator: :eq, value: true }

    item_class "lcp-row-warning",
      when: { field: :is_over_budget, operator: :eq, value: true }

    item_class "lcp-row-success",
      when: { field: :status, operator: :eq, value: "completed" }
  end

  show do
    description "All values below are computed dynamically via SQL subqueries, JOINs, window functions, and services — no stored counters."

    section "Project", columns: 2 do
      field :name, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { planning: "gray", active: "green", completed: "blue", archived: "orange" }
      }
      field :description
      field :budget, renderer: :currency
    end

    section "Company (JOIN-based)", columns: 2, description: "Values pulled from a joined table via LEFT JOIN virtual columns." do
      field :company_name
      field :company_country
    end

    section "Aggregate Statistics", columns: 2, description: "Computed via COUNT, SUM, and AVG aggregates over associated tasks." do
      field :tasks_count
      field :completed_count
      field :unique_assignees
      field :total_hours
      field :completed_cost, renderer: :currency
      field :avg_priority, renderer: :number, options: { precision: 1 }
    end

    section "Expression Columns", columns: 2, description: "Inline SQL expressions: boolean checks, derived values, auto-included flags." do
      field :has_overdue_tasks, renderer: :boolean_icon
      field :is_over_budget, renderer: :boolean_icon
      field :budget_per_task, renderer: :currency
    end

    section "Window & Service", columns: 2, description: "ROW_NUMBER() window function and service-computed health score." do
      field :budget_rank
      field :health_score, renderer: :number
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
      field :company_id, input_type: :association_select
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
