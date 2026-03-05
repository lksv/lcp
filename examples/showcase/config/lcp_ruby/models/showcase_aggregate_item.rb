define_model :showcase_aggregate_item do
  label "Aggregate Task"
  label_plural "Aggregate Tasks"

  field :title, :string, label: "Title", limit: 200, null: false, transforms: [ :strip ] do
    validates :presence
    validates :length, maximum: 200
  end
  field :status, :enum, label: "Status", default: "todo",
    values: { todo: "To Do", in_progress: "In Progress", done: "Done", cancelled: "Cancelled" }
  field :hours, :decimal, label: "Estimated Hours", column_options: { precision: 8, scale: 2 }
  field :cost, :decimal, label: "Cost", column_options: { precision: 10, scale: 2 }
  field :priority_score, :integer, label: "Priority Score"
  field :due_date, :date, label: "Due Date"
  field :assignee, :string, label: "Assignee", limit: 100

  belongs_to :showcase_aggregate, model: :showcase_aggregate, required: true

  timestamps true
  label_method :title
end
