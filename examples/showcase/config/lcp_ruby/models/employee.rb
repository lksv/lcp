define_model :employee do
  label "Employee"
  label_plural "Employees"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :email, :email, label: "Email"
  field :role, :enum, label: "Role", default: "developer",
    values: {
      admin: "Admin",
      manager: "Manager",
      developer: "Developer",
      designer: "Designer",
      intern: "Intern"
    }
  field :status, :enum, label: "Status", default: "active",
    values: {
      active: "Active",
      on_leave: "On Leave",
      terminated: "Terminated",
      archived: "Archived"
    }

  belongs_to :department, model: :department, required: true
  belongs_to :mentor, model: :employee, required: false
  has_many :employee_skills, model: :employee_skill, dependent: :destroy
  has_many :skills, through: :employee_skills

  scope :active_employees, where: { status: "active" }

  timestamps true
  label_method :name
end
