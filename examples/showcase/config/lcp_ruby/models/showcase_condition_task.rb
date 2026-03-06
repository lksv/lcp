define_model :showcase_condition_task do
  label "Condition Task"
  label_plural "Condition Tasks"

  field :title, :string, label: "Title", limit: 200, null: false do
    validates :presence
  end
  field :status, :enum, label: "Status", default: "pending",
    values: { pending: "Pending", approved: "Approved", rejected: "Rejected" }
  field :reviewer_name, :string, label: "Reviewer", limit: 100

  belongs_to :showcase_condition, model: :showcase_condition

  timestamps true
  label_method :title
end
