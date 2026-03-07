define_presenter :dashboard_employees do
  model :employee
  label "Recent Employees"

  index do
    per_page 5
    column :name, sortable: true
    column :email, renderer: :email_link
    column :role, renderer: :badge, options: {
      color_map: { admin: "red", manager: "purple", developer: "blue", designer: "cyan", intern: "gray" }
    }
    column "department.name", label: "Department"

    includes :department
  end
end
