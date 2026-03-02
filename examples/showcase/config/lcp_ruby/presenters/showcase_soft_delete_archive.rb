define_presenter :showcase_soft_delete_archive do
  model :showcase_soft_delete
  label "Archived Documents"
  slug "showcase-soft-delete-archive"
  icon "archive"
  scope "discarded"

  index do
    description "Discarded documents. Use Restore to bring them back or Permanently Destroy to remove them forever."
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
    column :updated_at, renderer: :relative_date, sortable: true
  end

  show do
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
  end

  search do
    searchable_fields :title
    placeholder "Search archived documents..."
  end

  action :show, type: :built_in, on: :single, icon: "eye"
  action :restore, type: :built_in, on: :single, icon: "rotate-ccw"
  action :permanently_destroy, type: :built_in, on: :single, icon: "trash-2", confirm: true, style: :danger
end
