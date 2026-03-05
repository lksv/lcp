define_model :showcase_item_class do
  label "Row Styling Record"
  label_plural "Row Styling (item_classes)"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end

  field :status, :enum, label: "Status",
    values: { active: "Active", completed: "Completed", cancelled: "Cancelled", on_hold: "On Hold", draft: "Draft" },
    default: "draft"

  field :priority, :enum, label: "Priority",
    values: { low: "Low", medium: "Medium", high: "High", critical: "Critical" },
    default: "medium"

  field :score, :integer, label: "Score", default: 50

  field :amount, :decimal, label: "Amount", precision: 10, scale: 2

  field :code, :string, label: "Code", limit: 50

  field :email, :email, label: "Email"

  field :notes, :text, label: "Notes"

  field :due_date, :date, label: "Due Date"

  timestamps true
  label_method :name
end
