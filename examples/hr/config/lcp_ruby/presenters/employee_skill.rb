define_presenter :employee_skill do
  model :employee_skill
  label "Employee Skills"
  slug "employee-skills"
  icon "star"

  index do
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column "employee.full_name", label: "Employee", width: "22%", sortable: true
    column "skill.name", label: "Skill", width: "20%", sortable: true
    column :proficiency, width: "15%", renderer: :enum, sortable: true
    column :certified, width: "10%", renderer: :boolean_icon
    column :certified_at, width: "12%", renderer: :date, visible_when: { field: :certified, operator: :eq, value: true }
    column :expires_at, width: "12%", renderer: :date
  end

  show do
    section "Skill Assignment", columns: 2 do
      field "employee.full_name", label: "Employee", renderer: :internal_link
      field "skill.name", label: "Skill", renderer: :internal_link
      field :proficiency, renderer: :enum
      field :certified, renderer: :boolean_icon
      field :certified_at, renderer: :date, visible_when: { field: :certified, operator: :eq, value: true }
      field :expires_at, renderer: :date, visible_when: { field: :certified, operator: :eq, value: true }
      field :certificate, renderer: :attachment_preview, visible_when: { field: :certified, operator: :eq, value: true }
    end
  end

  form do
    section "Skill Assignment", columns: 2 do
      field :employee_id, input_type: :association_select,
        input_options: { sort: { full_name: :asc } }
      field :skill_id, input_type: :association_select,
        input_options: { sort: { name: :asc } }
      field :proficiency, input_type: :select
      field :certified, input_type: :checkbox
      field :certified_at, input_type: :date,
        visible_when: { field: :certified, operator: :eq, value: true }
      field :expires_at, input_type: :date,
        visible_when: { field: :certified, operator: :eq, value: true }
      field :certificate,
        visible_when: { field: :certified, operator: :eq, value: true }
    end
  end

  search do
    placeholder "Search employee skills..."
  end

  action :create, type: :built_in, on: :collection, label: "New Skill Assignment", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
