define_model :dashboard do
  label "Dashboard"
  label_plural "Dashboards"

  table_name "_virtual"

  field :total_headcount, :integer
  field :active_employees, :integer
  field :open_positions, :integer
  field :pending_leave_requests, :integer
  field :pending_expense_claims, :integer
  field :avg_tenure_years, :float
  field :turnover_rate_ytd, :float
  field :upcoming_trainings, :integer
  field :headcount_by_unit, :json
  field :leave_utilization, :json
end
