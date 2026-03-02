define_presenter :showcase_soft_delete do
  model :showcase_soft_delete
  label "Soft Delete"
  slug "showcase-soft-delete"
  icon "trash-2"

  index do
    description "Demonstrates soft delete (discard/restore) with cascade to child items. Deleted records move to the Archive view and can be restored or permanently destroyed."
    default_sort :updated_at, :desc
    per_page 25
    row_click :show

    column :title, link_to: :show, sortable: true
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", active: "green", archived: "orange" }
    }, sortable: true
    column :priority, renderer: :badge, options: {
      color_map: { low: "gray", normal: "blue", high: "red" }
    }
    column :updated_by_name, label: "Last modified by"
    column :updated_at, renderer: :relative_date, sortable: true

    includes :showcase_soft_delete_items
  end

  show do
    description "Discarding this document will also discard all its child items (cascade via dependent: :discard)."

    section "Document", columns: 2 do
      field :title, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { draft: "gray", active: "green", archived: "orange" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "gray", normal: "blue", high: "red" }
      }
    end

    section "Content" do
      field :content
    end

    association_list "Items", association: :showcase_soft_delete_items,
      display_template: :default, link: false,
      empty_message: "No items yet."

    section "Audit Trail", columns: 2, description: "Userstamps and timestamps are tracked automatically." do
      field :created_by_name, label: "Created by"
      field :created_at, renderer: :datetime
      field :updated_by_name, label: "Last modified by"
      field :updated_at, renderer: :datetime
    end

    includes :showcase_soft_delete_items
  end

  form do
    section "Document", columns: 2 do
      field :title, placeholder: "Document title...", autofocus: true, col_span: 2
      field :status, input_type: :select
      field :priority, input_type: :select
    end

    section "Content" do
      field :content, input_type: :textarea, input_options: { rows: 8 }
    end
  end

  search do
    searchable_fields :title, :content
    placeholder "Search documents..."
    filter :all, label: "All", default: true
    filter :active_docs, label: "Active", scope: :active_docs
    filter :drafts, label: "Drafts", scope: :drafts
  end

  action :create, type: :built_in, on: :collection, label: "New Document", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
