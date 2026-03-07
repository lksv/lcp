define_presenter :showcase_aggregates_tiles, inherits: :showcase_aggregates do
  label "Virtual Columns (Tiles)"
  slug "showcase-aggregates-tiles"

  index do
    layout :tiles
    default_sort :name, :asc
    per_page 6

    tile do
      title_field :name
      subtitle_field :status, renderer: :badge, options: {
        color_map: { planning: "gray", active: "green", completed: "blue", archived: "orange" }
      }
      description_field :description, max_lines: 3
      columns 2
      card_link :show
      actions :inline

      field :budget, label: "Budget", renderer: :currency
      field :tasks_count, label: "Tasks"
      field :completed_count, label: "Completed"
      field :health_score, label: "Health %", renderer: :number
      field :has_overdue_tasks, label: "Overdue?", renderer: :boolean_icon
      field :company_name, label: "Company"
    end

    sort_field :name, label: "Name"
    sort_field :budget, label: "Budget"
    sort_field :tasks_count, label: "Tasks"
    sort_field :health_score, label: "Health"

    per_page_options 6, 12

    summary do
      field :budget, function: :sum, label: "Total Budget", renderer: :currency
      field :budget, function: :avg, label: "Avg Budget", renderer: :currency
      field :name, function: :count, label: "Project Count"
      field :budget, function: :max, label: "Max Budget", renderer: :currency
      field :budget, function: :min, label: "Min Budget", renderer: :currency
    end
  end
end
