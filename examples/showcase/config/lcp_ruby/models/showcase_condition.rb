define_model :showcase_condition do
  label "Advanced Condition"
  label_plural "Advanced Conditions"

  field :title, :string, label: "Title", limit: 200, null: false do
    validates :presence
  end
  field :status, :enum, label: "Status", default: "draft",
    values: { draft: "Draft", active: "Active", review: "In Review", approved: "Approved", closed: "Closed" }
  field :priority, :enum, label: "Priority", default: "medium",
    values: { low: "Low", medium: "Medium", high: "High", critical: "Critical" }
  field :amount, :decimal, label: "Amount", precision: 10, scale: 2, default: 0
  field :budget_limit, :decimal, label: "Budget Limit", precision: 10, scale: 2, default: 10000
  field :author_id, :integer, label: "Author ID", default: 1
  field :due_date, :date, label: "Due Date"
  field :code, :string, label: "Code", limit: 50
  field :description, :text, label: "Description"

  belongs_to :showcase_condition_category, model: :showcase_condition_category, required: false
  has_many :showcase_condition_tasks, model: :showcase_condition_task

  timestamps true
  label_method :title
end
