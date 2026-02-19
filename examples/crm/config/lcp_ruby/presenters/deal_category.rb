define_presenter :deal_category do
  model :deal_category
  label "Deal Categories"
  slug "deal-categories"
  icon "folder"

  index do
    default_view :table
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, width: "50%", link_to: :show, sortable: true
    column "parent.name", label: "Parent Category", width: "50%", sortable: true
  end

  show do
    section "Category Information", columns: 2 do
      field :name, display: :heading
      field "parent.name", label: "Parent Category"
      field :created_at, display: :relative_date
    end
    association_list "Subcategories", association: :children
  end

  form do
    section "Category Details", columns: 2 do
      field :name, placeholder: "Category name...", autofocus: true
      field :parent_id, input_type: :tree_select,
        input_options: {
          parent_field: :parent_id,
          label_method: :name,
          max_depth: 5
        }
    end
  end

  search do
    searchable_fields :name
    placeholder "Search categories..."
  end

  action :create, type: :built_in, on: :collection, label: "New Category", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
