define_model :project do
  label "Project"
  label_plural "Projects"
  custom_fields true

  field :name, :string, label: "Name", limit: 200, null: false do
    validates :presence
  end
  field :status, :enum, label: "Status", default: "active",
    values: {
      active: "Active",
      completed: "Completed",
      archived: "Archived"
    }

  belongs_to :department, model: :department, required: true
  belongs_to :lead, model: :employee, required: false

  timestamps true
  label_method :name
end
