define_model :employee_skill do
  label "Employee Skill"
  label_plural "Employee Skills"

  belongs_to :employee, model: :employee
  belongs_to :skill, model: :skill

  timestamps true
end
