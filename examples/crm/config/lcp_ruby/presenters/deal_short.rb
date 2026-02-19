define_presenter :deal_short, inherits: :deal do
  label "Deals (Short)"
  slug "deals-short"

  index do
    default_view :table
    default_sort :created_at, :desc
    per_page 50
    row_click :show

    column :title, width: "40%", link_to: :show, sortable: true
    column :stage, width: "30%", renderer: :badge, sortable: true
    column :value, width: "30%", renderer: :currency, options: { currency: "EUR" }, sortable: true
  end

  show do
    section "Deal Summary", columns: 2 do
      field :title, renderer: :heading
      field :stage, renderer: :badge
      field :value, renderer: :currency, options: { currency: "EUR" }
    end
  end
end
