define_presenter :company_archive do
  model :company
  label "Archived Companies"
  slug "companies-archive"
  icon "archive"
  scope "discarded"

  index do
    default_view :table
    default_sort :name, :asc
    per_page 25

    column :name, width: "30%", link_to: :show, sortable: true
    column :industry, width: "20%", renderer: :badge, sortable: true
    column :website, width: "25%", renderer: :url_link
    column :phone, width: "25%", renderer: :phone_link
  end

  show do
    section "Company Information", columns: 2 do
      field :name, renderer: :heading
      field :industry, renderer: :badge
      field :website, renderer: :url_link
      field :phone, renderer: :phone_link
      field :logo, renderer: :attachment_preview
      field :created_at, renderer: :relative_date
    end
  end

  search do
    searchable_fields :name
    placeholder "Search archived companies..."
  end

  action :show, type: :built_in, on: :single, icon: "eye"
  action :restore, type: :built_in, on: :single, icon: "rotate-ccw"
  action :permanently_destroy, type: :built_in, on: :single, icon: "trash-2", confirm: true, style: :danger
end
