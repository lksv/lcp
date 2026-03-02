define_presenter :showcase_soft_delete_items do
  model :showcase_soft_delete_item
  label "Soft Delete Items"
  slug "showcase-soft-delete-items"
  icon "list"

  index do
    default_sort :name, :asc
    per_page 25
    row_click :show

    column :name, link_to: :show, sortable: true
    column :notes, renderer: :truncate, options: { length: 80 }
    column :created_at, renderer: :relative_date, sortable: true
  end

  show do
    section "Item Details", columns: 2 do
      field :name, renderer: :heading
      field :notes
      field :created_at, renderer: :datetime
      field :updated_at, renderer: :datetime
    end
  end

  form do
    section "Item Details", columns: 2 do
      field :name, placeholder: "Item name...", autofocus: true
      field :showcase_soft_delete_id, input_type: :association_select,
        input_options: { label_method: :title }
    end

    section "Notes" do
      field :notes, input_type: :textarea, input_options: { rows: 4 }
    end
  end

  search do
    searchable_fields :name, :notes
    placeholder "Search items..."
  end

  action :create, type: :built_in, on: :collection, label: "New Item", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
