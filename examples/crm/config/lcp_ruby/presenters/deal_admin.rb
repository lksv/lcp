define_presenter :deal_admin do
  model :deal
  label "Deals"
  slug "deals"
  icon "dollar-sign"

  index do
    default_view :table
    default_sort :created_at, :desc
    per_page 25
    row_click :show
    empty_message "No deals found"
    actions_position :dropdown

    column :title, width: "25%", link_to: :show, sortable: true, display: :truncate, display_options: { max: 40 }
    column "company.name", label: "Company", width: "15%", sortable: true
    column :stage, width: "10%", display: :badge, display_options: { color_map: { lead: "blue", qualified: "cyan", proposal: "orange", negotiation: "purple", closed_won: "green", closed_lost: "red" } }, sortable: true
    column :value, width: "15%", display: :currency, display_options: { currency: "EUR" }, sortable: true, summary: "sum"
    column :weighted_value, width: "10%", display: :currency, display_options: { currency: "EUR" }
    column :progress, width: "10%", display: :progress_bar
    column :priority, width: "10%", sortable: true
  end

  show do
    section "Deal Information", columns: 2, responsive: { mobile: { columns: 1 } } do
      field :title, display: :heading
      field :stage, display: :conditional_badge, display_options: {
        rules: [
          { match: { in: %w[closed_won] }, display: "badge", display_options: { "color_map" => { "closed_won" => "green" } } },
          { match: { in: %w[closed_lost] }, display: "badge", display_options: { "color_map" => { "closed_lost" => "red" } } },
          { match: { in: %w[negotiation] }, display: "badge", display_options: { "color_map" => { "negotiation" => "purple" } } },
          { "default" => { display: "badge", display_options: { "color_map" => {} } } }
        ]
      }
      field :value, display: :currency, display_options: { currency: "EUR" }
      field :weighted_value, display: :currency, display_options: { currency: "EUR" }
      field :progress, display: :progress_bar
      field :priority, display: :rating, display_options: { max: 5 }
      field :expected_close_date
      field :created_at, display: :relative_date
      field "company.name", label: "Company"
    end
  end

  form do
    layout :tabs

    section "Deal Details", columns: 2 do
      field :title, placeholder: "Deal title...", autofocus: true, col_span: 2
      field :stage, input_type: :select,
        input_options: { exclude_values: { viewer: [ "lead" ] } }
      field :value, input_type: :number, prefix: "EUR", hint: "Deal value without VAT",
        disable_when: { field: :stage, operator: :in, value: [ :closed_won, :closed_lost ] }
      field :expected_close_date, input_type: :date_picker
      field :company_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name }
      field :contact_id, input_type: :association_select,
        input_options: {
          depends_on: { field: :company_id, foreign_key: :company_id },
          sort: { last_name: :asc },
          label_method: :full_name
        },
        visible_when: { field: :stage, operator: :not_in, value: [ :lead ] }
      field :deal_category_id, input_type: :tree_select,
        input_options: {
          parent_field: :parent_id,
          label_method: :name,
          max_depth: 5
        }
    end

    section "Advanced", columns: 2, collapsible: true, collapsed: true,
      visible_when: { field: :stage, operator: :not_eq, value: "lead" } do
      field :priority, input_type: :slider, input_options: { min: 0, max: 100, step: 5, show_value: true }
      field :progress, input_type: :slider, input_options: { min: 0, max: 100, step: 10, show_value: true }
      field :created_at, readonly: true
    end
  end

  search do
    searchable_fields :title
    placeholder "Search deals..."
    filter :all, label: "All", default: true
    filter :open, label: "Open", scope: :open_deals
    filter :won, label: "Won", scope: :won
    filter :lost, label: "Lost", scope: :lost
  end

  action :create, type: :built_in, on: :collection, label: "New Deal", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :close_won, type: :custom, on: :single,
    label: "Close as Won", icon: "check-circle",
    confirm: true, confirm_message: "Mark this deal as won?",
    visible_when: { field: :stage, operator: :not_in, value: [ :closed_won, :closed_lost ] },
    disable_when: { field: :value, operator: :blank }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
