define_presenter :company_short, inherits: :company do
  label "Companies (Short)"
  slug "companies-short"

  index do
    default_view :table
    default_sort :name, :asc
    per_page 50
    row_click :show

    column :name, width: "50%", link_to: :show, sortable: true
    column :industry, width: "50%", renderer: :badge, sortable: true
  end

  show do
    section "Company Summary" do
      field :name, renderer: :heading
      field :industry, renderer: :badge
    end
  end
end
