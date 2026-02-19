define_presenter :employees do
  model :employee
  label "Employees"
  slug "employees"
  icon "users"

  index do
    description "Demonstrates association_select, tree_select, multi_select, cascading selects, and search."
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, link_to: :show, sortable: true
    column :email, renderer: :email_link
    column :role, renderer: :badge, options: {
      color_map: { admin: "red", manager: "purple", developer: "blue", designer: "cyan", intern: "gray" }
    }, sortable: true
    column "department.name", label: "Department"
    column :status, renderer: :badge, options: {
      color_map: { active: "green", on_leave: "orange", terminated: "red", archived: "gray" }
    }

    includes :department
  end

  show do
    description "Employee details with associations and skills."

    section "Employee Information", columns: 2 do
      field :name, renderer: :heading
      field :email, renderer: :email_link
      field :role, renderer: :badge, options: {
        color_map: { admin: "red", manager: "purple", developer: "blue", designer: "cyan", intern: "gray" }
      }
      field :status, renderer: :badge, options: {
        color_map: { active: "green", on_leave: "orange", terminated: "red", archived: "gray" }
      }
      field "department.name", label: "Department"
      field "mentor.name", label: "Mentor"
    end

    association_list "Skills", association: :skills, link: true,
      empty_message: "No skills assigned."

    includes :department, :mentor, :skills
  end

  form do
    description "Each section demonstrates a specific select feature."

    section "Basic Association Select", columns: 2, description: "Standard association_select for belongs_to." do
      field :name, placeholder: "Employee name...", autofocus: true
      field :email
      field :department_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name, include_blank: "Select department..." }
    end

    section "Enum Select", columns: 2, description: "Select for enum fields with include_blank." do
      info "Enum selects render the model's enum values as dropdown options."
      field :role, input_type: :select
      field :status, input_type: :select
    end

    section "Cascading & Search Select", columns: 2, description: "Mentor select depends on department. Uses search for large lists." do
      info "The mentor field uses search: true and depends_on to filter by the selected department."
      field :mentor_id, input_type: :association_select,
        input_options: {
          search: true,
          sort: { name: :asc },
          label_method: :name,
          depends_on: { field: :department_id, foreign_key: :department_id }
        }
    end

    section "Multi-Select (Skills)", columns: 1, description: "Multi-select for has_many :through association." do
      info "Select skills from the available list. Maximum 5 skills."
      field :skill_ids, input_type: :multi_select,
        input_options: { sort: { name: :asc }, label_method: :name, max: 5 }
    end

    section "Tree Select (Department)", columns: 2, description: "Hierarchical tree select for self-referential models." do
      info "Tree select shows a hierarchical dropdown for departments with nested children."
      field :department_id, input_type: :tree_select,
        input_options: { parent_field: :parent_id, label_method: :name, max_depth: 3 }
    end

    includes :skills
  end

  search do
    searchable_fields :name, :email
    placeholder "Search employees..."
    filter :all, label: "All", default: true
    filter :active, label: "Active", scope: :active_employees
  end

  action :create, type: :built_in, on: :collection, label: "New Employee"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
