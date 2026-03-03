define_presenter :employee_archive do
  model :employee
  label "Employee Archive"
  slug "employee-archive"
  icon "archive"
  scope "discarded"

  index do
    default_sort :termination_date, :desc
    per_page 25

    column :full_name, width: "30%", link_to: :show, sortable: true
    column :status, width: "15%", renderer: :badge, options: { color_map: { active: "green", on_leave: "yellow", suspended: "orange", terminated: "red" } }, sortable: true
    column :termination_date, width: "20%", renderer: :date, sortable: true
    column :updated_at, width: "20%", renderer: :relative_date, sortable: true
  end

  show do
    section "Employee Information", columns: 2 do
      field :full_name, renderer: :heading
      field :status, renderer: :badge, options: { color_map: { active: "green", on_leave: "yellow", suspended: "orange", terminated: "red" } }
      field :work_email, renderer: :email_link
      field :hire_date, renderer: :date
      field :termination_date, renderer: :date
    end
  end

  search do
    searchable_fields :full_name
    placeholder "Search archived employees..."
  end

  action :show, type: :built_in, on: :single, icon: "eye"
  action :restore, type: :built_in, on: :single, icon: "rotate-ccw"
  action :permanently_destroy, type: :built_in, on: :single, icon: "trash-2", confirm: true,
    confirm_message: "This will permanently remove all employee data. This cannot be undone.",
    style: :danger
end
