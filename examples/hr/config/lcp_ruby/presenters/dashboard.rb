define_presenter :dashboard do
  model :dashboard
  label "Dashboard"
  slug "dashboard"
  icon "layout-dashboard"
  read_only true

  index do
    per_page 1

    column :total_headcount
    column :active_employees
    column :open_positions
    column :pending_leave_requests
    column :pending_expense_claims
    column :avg_tenure_years, renderer: :decimal
    column :turnover_rate_ytd, renderer: :percentage
    column :upcoming_trainings
  end

  show do
    section "Overview", columns: 4 do
      field :total_headcount
      field :active_employees
      field :open_positions
      field :pending_leave_requests
      field :pending_expense_claims
      field :avg_tenure_years, renderer: :decimal
      field :turnover_rate_ytd, renderer: :percentage
      field :upcoming_trainings
    end
  end

  search enabled: false

  action :show, type: :built_in, on: :single, icon: "eye"
end
