define_model :showcase_aggregate do
  label "Aggregate Project"
  label_plural "Aggregate Projects"

  field :name, :string, label: "Name", limit: 200, null: false, transforms: [ :strip ] do
    validates :presence
    validates :length, maximum: 200
  end
  field :description, :text, label: "Description"
  field :status, :enum, label: "Status", default: "active",
    values: { planning: "Planning", active: "Active", completed: "Completed", archived: "Archived" }
  field :budget, :decimal, label: "Budget", column_options: { precision: 12, scale: 2 }
  field :company_id, :integer

  has_many :showcase_aggregate_items, model: :showcase_aggregate_item,
    foreign_key: :showcase_aggregate_id, dependent: :destroy
  belongs_to :showcase_aggregate_company, model: :showcase_aggregate_company,
    foreign_key: :company_id, required: false

  # --- Aggregate columns ---

  # Simple count — total tasks
  aggregate :tasks_count, function: :count, association: :showcase_aggregate_items

  # Filtered count — only completed tasks
  aggregate :completed_count, function: :count, association: :showcase_aggregate_items,
    where: { status: "done" }

  # Sum — total estimated hours
  aggregate :total_hours, function: :sum, association: :showcase_aggregate_items,
    source_field: :hours, default: 0

  # Sum with where — cost of completed tasks only
  aggregate :completed_cost, function: :sum, association: :showcase_aggregate_items,
    source_field: :cost, where: { status: "done" }, default: 0

  # Average — average priority score
  aggregate :avg_priority, function: :avg, association: :showcase_aggregate_items,
    source_field: :priority_score

  # Max — latest task due date
  aggregate :latest_due_date, function: :max, association: :showcase_aggregate_items,
    source_field: :due_date

  # Min — earliest task due date
  aggregate :earliest_due_date, function: :min, association: :showcase_aggregate_items,
    source_field: :due_date

  # Count with distinct
  aggregate :unique_assignees, function: :count, association: :showcase_aggregate_items,
    source_field: :assignee, distinct: true

  # --- Virtual columns (expression, JOIN, window, service) ---

  # Expression — boolean: does this project have overdue tasks?
  virtual_column :has_overdue_tasks, type: :boolean,
    expression: "EXISTS(SELECT 1 FROM showcase_aggregate_items " \
                "WHERE showcase_aggregate_items.showcase_aggregate_id = %{table}.id " \
                "AND showcase_aggregate_items.due_date < CURRENT_DATE " \
                "AND showcase_aggregate_items.status NOT IN ('done', 'cancelled'))"

  # Expression — derived decimal: budget divided by task count
  virtual_column :budget_per_task, type: :decimal, default: 0,
    expression: "CASE WHEN (SELECT COUNT(*) FROM showcase_aggregate_items " \
                "WHERE showcase_aggregate_items.showcase_aggregate_id = %{table}.id) > 0 " \
                "THEN %{table}.budget / (SELECT COUNT(*) FROM showcase_aggregate_items " \
                "WHERE showcase_aggregate_items.showcase_aggregate_id = %{table}.id) ELSE 0 END"

  # Expression — boolean with auto_include (available on every query without explicit reference)
  virtual_column :is_over_budget, type: :boolean, default: false, auto_include: true,
    expression: "(SELECT COALESCE(SUM(showcase_aggregate_items.cost), 0) " \
                "FROM showcase_aggregate_items " \
                "WHERE showcase_aggregate_items.showcase_aggregate_id = %{table}.id) > %{table}.budget"

  # JOIN-based — pull company name from joined table
  virtual_column :company_name, type: :string,
    expression: "showcase_aggregate_companies.name",
    join: "LEFT JOIN showcase_aggregate_companies ON showcase_aggregate_companies.id = %{table}.company_id"

  # JOIN-based — company country (same JOIN, demonstrates deduplication)
  virtual_column :company_country, type: :string,
    expression: "showcase_aggregate_companies.country",
    join: "LEFT JOIN showcase_aggregate_companies ON showcase_aggregate_companies.id = %{table}.company_id"

  # Window function — rank by budget within status group
  virtual_column :budget_rank, type: :integer,
    expression: "ROW_NUMBER() OVER(PARTITION BY %{table}.status ORDER BY %{table}.budget DESC)"

  # Service-based — computed health score (% of completed tasks)
  virtual_column :health_score, service: :project_health, type: :integer

  timestamps true
  label_method :name
end
