define_model :showcase_positioning do
  label "Priority Item"
  label_plural "Priority List"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :description, :text, label: "Description"
  field :position, :integer, label: "Position"
  field :status, :enum, label: "Status", default: "todo",
    values: { todo: "To Do", in_progress: "In Progress", done: "Done" }
  field :priority, :enum, label: "Priority", default: "medium",
    values: { low: "Low", medium: "Medium", high: "High", critical: "Critical" }

  positioning

  timestamps true
  label_method :name
end
