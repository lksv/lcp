define_model :showcase_aggregate do
  label "Aggregate Project"
  label_plural "Aggregate Projects"

  field :name, :string, label: "Name", limit: 200, null: false, transforms: [:strip] do
    validates :presence
    validates :length, maximum: 200
  end
  field :description, :text, label: "Description"
  field :status, :enum, label: "Status", default: "active",
    values: { planning: "Planning", active: "Active", completed: "Completed", archived: "Archived" }
  field :budget, :decimal, label: "Budget", column_options: { precision: 12, scale: 2 }

  has_many :showcase_aggregate_items, model: :showcase_aggregate_item,
    foreign_key: :showcase_aggregate_id, dependent: :destroy

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

  timestamps true
  label_method :name
end
