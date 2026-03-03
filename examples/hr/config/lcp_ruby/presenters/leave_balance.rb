define_presenter :leave_balance do
  model :leave_balance
  label "Leave Balances"
  slug "leave-balances"
  icon "bar-chart-2"

  index do
    default_sort :year, :desc
    per_page 25
    row_click :show

    column "employee.full_name", label: "Employee", width: "25%", sortable: true
    column "leave_type.name", label: "Leave Type", width: "20%", sortable: true
    column :year, width: "10%", sortable: true
    column :total_days, width: "15%"
    column :used_days, width: "15%"
    column :remaining, width: "15%"
  end

  show do
    section "Balance Details", columns: 2 do
      field "employee.full_name", label: "Employee", renderer: :internal_link
      field "leave_type.name", label: "Leave Type"
      field :year
      field :total_days
      field :used_days
      field :remaining
    end
  end

  form do
    section "Leave Balance", columns: 2 do
      field :employee_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :leave_type_id, input_type: :association_select,
        input_options: { sort: { name: :asc } }
      field :year, input_type: :number
      field :total_days, input_type: :number
    end
  end

  search do
    placeholder "Search leave balances..."
  end

  action :create, type: :built_in, on: :collection, label: "New Balance", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
