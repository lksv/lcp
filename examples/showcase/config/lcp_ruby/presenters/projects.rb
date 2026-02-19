define_presenter :projects do
  model :project
  label "Projects"
  slug "projects"
  icon "briefcase"

  index do
    description "Demonstrates cascading selects: department -> lead (employee in that department)."
    default_sort :name, :asc
    per_page 25

    column :name, link_to: :show, sortable: true
    column :status, display: :badge, display_options: {
      color_map: { active: "green", completed: "blue", archived: "gray" }
    }, sortable: true
    column "department.name", label: "Department"
    column "lead.name", label: "Lead"

    includes :department, :lead
  end

  show do
    section "Project Details", columns: 2 do
      field :name, display: :heading
      field :status, display: :badge, display_options: {
        color_map: { active: "green", completed: "blue", archived: "gray" }
      }
      field "department.name", label: "Department"
      field "lead.name", label: "Project Lead"
    end

    includes :department, :lead
  end

  form do
    description "Cascading selects: select a department first, then choose a lead from that department."

    section "Project Information", columns: 2 do
      info "Select a department first. The lead dropdown will update to show only employees from the selected department."
      field :name, placeholder: "Project name...", autofocus: true
      field :status, input_type: :select
      field :department_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name }
      field :lead_id, input_type: :association_select,
        input_options: {
          search: true,
          sort: { name: :asc },
          label_method: :name,
          depends_on: { field: :department_id, foreign_key: :department_id }
        }
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Project"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
