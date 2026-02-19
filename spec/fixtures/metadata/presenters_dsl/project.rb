define_presenter :project do
  model :project
  label "Project Management"
  slug "projects"
  icon "folder"

  index do
    default_view :table
    views_available :table, :tiles
    default_sort :created_at, :desc
    per_page 25
    column :title, width: "30%", link_to: :show, sortable: true
    column :status, width: "15%", display: :badge, sortable: true
    column :budget, display: :currency, sortable: true
    column :due_date, display: :relative_date, sortable: true
  end

  show do
    section "Overview", columns: 2 do
      field :title, display: :heading
      field :status, display: :badge
    end
    section "Details" do
      field :description, display: :rich_text
      field :budget, display: :currency
    end
  end

  form do
    section "Basic Information", columns: 2 do
      field :title, placeholder: "Enter project title...", autofocus: true
      field :status, input_type: :select
    end
    section "Details" do
      field :description, input_type: :text
    end
    section "Timeline & Budget", columns: 3 do
      field :budget, input_type: :number, prefix: "$"
      field :start_date, input_type: :date_picker
      field :due_date, input_type: :date_picker
    end
  end

  search do
    searchable_fields :title, :description
    placeholder "Search projects..."
    filter :all, label: "All", default: true
    filter :active, label: "Active", scope: :active
  end

  action :create, type: :built_in, on: :collection, label: "New Project", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :archive, type: :custom, on: :single,
    label: "Archive", icon: "archive",
    confirm: true, confirm_message: "Archive this project?",
    visible_when: { field: :status, operator: :not_in, value: [ :archived, :completed ] },
    style: :danger
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
