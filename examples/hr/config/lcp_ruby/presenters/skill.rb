define_presenter :skill do
  model :skill
  label "Skills"
  slug "skills"
  icon "award"

  index do
    tree_view true

    column :name, width: "30%", link_to: :show, sortable: true
    column :category, width: "20%", renderer: :badge, options: { color_map: { technical: "blue", soft: "green", language: "purple", certification: "orange" } }, sortable: true
    column :description, width: "40%", renderer: :truncate, options: { max: 80 }
  end

  show do
    section "Skill Details", columns: 2 do
      field :name, renderer: :heading
      field :category, renderer: :badge, options: { color_map: { technical: "blue", soft: "green", language: "purple", certification: "orange" } }
      field :description
      field "parent.name", label: "Parent Skill", renderer: :internal_link
    end

    association_list "Sub-Skills", association: :children
    association_list "Employee Skills", association: :employee_skills
  end

  form do
    section "Skill Details", columns: 2 do
      field :name, autofocus: true
      field :category, input_type: :select
      field :description, input_type: :textarea, col_span: 2
      field :parent_id, input_type: :tree_select
    end
  end

  search do
    searchable_fields :name
    placeholder "Search skills..."
  end

  action :create, type: :built_in, on: :collection, label: "New Skill", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
