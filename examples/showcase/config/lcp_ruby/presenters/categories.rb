define_presenter :categories do
  model :category
  label "Categories"
  slug "categories"
  icon "folder"

  index do
<<<<<<< HEAD
    description "Self-referential tree model with parent/children associations."
    default_sort :name, :asc
    per_page 25
    tree_view true
    default_expanded "all"
=======
    description "Hierarchical tree view with drag-and-drop reparenting."
    tree_view true
    default_expanded 1
>>>>>>> ddb43eb (feat: implement tree structures with tree index view, filtered search, and drag-and-drop reparenting)
    reparentable true

    column :name, link_to: :show
    column :description, renderer: :truncate, options: { max: 80 }
  end

  search do
    searchable_fields :name
    placeholder "Search categories..."
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

    includes :articles, :children
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
