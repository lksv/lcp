define_presenter :showcase_userstamps do
  model :showcase_userstamps
  label "Userstamps"
  slug "showcase-userstamps"
  icon "user-check"

  index do
    description "Demonstrates automatic user tracking. Created by / Updated by are set automatically via before_save callback from LcpRuby::Current.user."
    default_sort :updated_at, :desc
    per_page 25
    row_click :show

    column :title, link_to: :show, sortable: true
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", review: "blue", published: "green", archived: "orange" }
    }, sortable: true
    column :priority, renderer: :badge, options: {
      color_map: { low: "gray", normal: "blue", high: "red" }
    }
    column :created_by_name, label: "Created by"
    column :updated_by_name, label: "Last modified by"
    column :updated_at, renderer: :relative_date, sortable: true
  end

  show do
    description "The Metadata section shows userstamp fields — created_by_name and updated_by_name are denormalized snapshots (store_name: true)."

    section "Document", columns: 2 do
      field :title, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { draft: "gray", review: "blue", published: "green", archived: "orange" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "gray", normal: "blue", high: "red" }
      }
    end

    section "Content" do
      field :content
    end

    section "Audit Trail", columns: 2, description: "Automatically tracked by the userstamps feature. Name snapshots are stored at the time of create/update." do
      field :created_by_name, label: "Created by"
      field :created_at, renderer: :datetime
      field :updated_by_name, label: "Last modified by"
      field :updated_at, renderer: :datetime
    end
  end

  form do
    description "Userstamp fields are not in the form — they are set automatically by the platform."

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
    filter :published, label: "Published", scope: :published
    filter :drafts, label: "Drafts", scope: :drafts
  end

  action :create, type: :built_in, on: :collection, label: "New Document", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
