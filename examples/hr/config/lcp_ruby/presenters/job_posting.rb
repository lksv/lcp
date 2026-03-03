define_presenter :job_posting do
  model :job_posting
  label "Job Postings"
  slug "job-postings"
  icon "briefcase"

  index do
    default_sort :created_at, :desc
    actions_position :dropdown
    empty_message "No open positions"

    column :title, link_to: :show, sortable: true
    column "organization_unit.name"
    column :status, renderer: :badge, options: { color_map: { draft: "gray", open: "green", on_hold: "yellow", closed: "red", filled: "blue" } }
    column :employment_type, renderer: :badge
    column :headcount
    column :closes_at, renderer: :date, sortable: true
  end

  show do
    section "Posting Details", columns: 2 do
      field :title, renderer: :heading
      field :description, renderer: :rich_text
      field :status, renderer: :badge
      field "organization_unit.name", renderer: :internal_link
      field "position.title"
      field "hiring_manager.full_name", renderer: :internal_link
      field :employment_type
      field :location
      field :remote_option
      field :salary_min, renderer: :currency, options: { currency: "CZK" }
      field :salary_max, renderer: :currency, options: { currency: "CZK" }
      field :currency
      field :headcount
      field :published_at, renderer: :datetime
      field :closes_at, renderer: :date
    end

    association_list "Candidates", association: :candidates,
      sort: { created_at: :desc }, display_template: :default
  end

  form do
    section "Posting Details", columns: 2 do
      field :title, autofocus: true
      field :description, input_type: :rich_text
      field :status, input_type: :select
      field :organization_unit_id, input_type: :tree_select
      field :position_id, input_type: :tree_select
      field :hiring_manager_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :employment_type, input_type: :select
      field :location
      field :remote_option, input_type: :select
      field :salary_min, input_type: :number, prefix: "CZK"
      field :salary_max, input_type: :number, prefix: "CZK"
      field :currency, input_type: :select
      field :headcount, input_type: :number
      field :closes_at, input_type: :date_picker
    end
  end

  search do
    filter :all, label: "All", default: true
    filter :open, label: "Open", scope: :open
    filter :draft, label: "Draft", scope: :draft
  end

  action :create, type: :built_in, on: :collection, label: "New Posting", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
