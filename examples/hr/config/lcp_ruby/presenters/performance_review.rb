define_presenter :performance_review do
  model :performance_review
  label "Performance Reviews"
  slug "performance-reviews"
  icon "clipboard"

  index do
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column "employee.full_name", label: "Employee", width: "20%", sortable: true
    column :review_period, width: "12%", renderer: :badge, sortable: true
    column :year, width: "8%", sortable: true
    column :status, width: "15%", renderer: :badge, options: { color_map: { draft: "gray", self_review: "blue", manager_review: "yellow", completed: "green", acknowledged: "green" } }, sortable: true
    column :overall_rating, width: "12%", renderer: :rating, options: { max: 5 }
  end

  show do
    section "Review Details", columns: 2 do
      field "employee.full_name", label: "Employee", renderer: :heading
      field "reviewer.full_name", label: "Reviewer", renderer: :internal_link
      field :review_period, renderer: :badge
      field :year
      field :status, renderer: :badge, options: { color_map: { draft: "gray", self_review: "blue", manager_review: "yellow", completed: "green", acknowledged: "green" } }
    end

    section "Self Review", columns: 2 do
      field :self_rating, renderer: :rating, options: { max: 5 }
      field :self_comments
    end

    section "Manager Review", columns: 2 do
      field :manager_rating, renderer: :rating, options: { max: 5 }
      field :manager_comments
      field :overall_rating, renderer: :rating, options: { max: 5 }
      field :strengths
      field :improvements
    end

    section "Summary" do
      field :goals_summary
      field :completed_at, renderer: :relative_date
    end

    association_list "Goals", association: :goals
  end

  form do
    layout :tabs

    section "General", columns: 2 do
      field :employee_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :reviewer_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :review_period, input_type: :select
      field :year, input_type: :number
      field :status, input_type: :select
    end

    section "Self Review", columns: 2 do
      field :self_rating, input_type: :slider, input_options: { min: 1, max: 5, step: 1 }
      field :self_comments, input_type: :textarea
    end

    section "Manager Review", columns: 2 do
      field :manager_rating, input_type: :slider, input_options: { min: 1, max: 5, step: 1 }
      field :manager_comments, input_type: :textarea
      field :overall_rating, input_type: :slider, input_options: { min: 1, max: 5, step: 1 }
      field :strengths, input_type: :textarea
      field :improvements, input_type: :textarea
    end
  end

  search do
    placeholder "Search performance reviews..."

    filter :all, label: "All", default: true
    filter :in_progress, label: "In Progress", scope: :in_progress
    filter :completed, label: "Completed", scope: :completed
  end

  action :create, type: :built_in, on: :collection, label: "New Review", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
end
