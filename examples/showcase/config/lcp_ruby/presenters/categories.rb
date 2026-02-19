define_presenter :categories do
  model :category
  label "Categories"
  slug "categories"
  icon "folder"

  index do
    description "Self-referential tree model with parent/children associations."
    default_sort :name, :asc
    per_page 25

    column :name, link_to: :show, sortable: true
    column :description, renderer: :truncate, options: { max: 80 }
  end

  show do
    section "Category Details", columns: 2 do
      field :name, renderer: :heading
      field :description
    end

    association_list "Articles", association: :articles, display_template: :default, link: true,
      sort: { title: :asc }, empty_message: "No articles in this category."

    association_list "Subcategories", association: :children, link: true,
      empty_message: "No subcategories."
  end

  form do
    section "Category Information", columns: 2, description: "Categories can be nested via the parent field." do
      field :name, placeholder: "Category name...", autofocus: true
      field :parent_id, input_type: :tree_select,
        input_options: { parent_field: :parent_id, label_method: :name, max_depth: 3 }
      field :description, input_type: :textarea, col_span: 2
    end
  end

  action :create, type: :built_in, on: :collection
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
