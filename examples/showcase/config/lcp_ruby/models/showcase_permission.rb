define_model :showcase_permission do
  label "Permission Demo"
  label_plural "Permission Demos"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end
  field :status, :enum, label: "Status", default: "open",
    values: {
      open: "Open",
      in_progress: "In Progress",
      locked: "Locked",
      archived: "Archived"
    }
  field :owner_id, :integer, label: "Owner ID", default: 1
  field :assignee_id, :integer, label: "Assignee ID"
  field :priority, :enum, label: "Priority", default: "medium",
    values: { low: "Low", medium: "Medium", high: "High", critical: "Critical" }
  field :confidential, :boolean, label: "Confidential", default: false
  field :internal_notes, :text, label: "Internal Notes"
  field :public_notes, :text, label: "Public Notes"

  scope :open_items, where: { status: "open" }
  scope :in_progress_items, where: { status: "in_progress" }

  on_field_change :on_status_change, field: :status

  timestamps true
  label_method :title
end
