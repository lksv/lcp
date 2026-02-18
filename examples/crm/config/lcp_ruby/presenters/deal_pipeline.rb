define_presenter :deal_pipeline, inherits: :deal_admin do
  label "Deal Pipeline"
  slug "pipeline"
  icon "bar-chart"
  read_only true

  index do
    default_view :table
    default_sort :created_at, :desc
    per_page 50
    column :title, width: "30%", link_to: :show, sortable: true
    column :stage, width: "20%", display: :badge, sortable: true
    column :value, width: "20%", display: :currency, sortable: true
  end

  search enabled: false

  action :show, type: :built_in, on: :single, icon: "eye"

end
