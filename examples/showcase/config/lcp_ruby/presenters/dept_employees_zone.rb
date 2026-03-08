define_presenter :dept_employees_zone do
  model :employee
  label "Employees"

  index do
    per_page 10
    column :name, sortable: true
    column :email, renderer: :email_link
    column :role, renderer: :badge, options: {
      color_map: { admin: "red", manager: "purple", developer: "blue", designer: "cyan", intern: "gray" }
    }
    column :status, renderer: :badge, options: {
      color_map: { active: "green", on_leave: "orange", terminated: "red", archived: "gray" }
    }
  end
end
