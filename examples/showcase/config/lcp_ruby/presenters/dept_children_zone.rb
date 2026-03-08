define_presenter :dept_children_zone do
  model :department
  label "Sub-departments"

  index do
    per_page 10
    column :name
    column :code
  end
end
