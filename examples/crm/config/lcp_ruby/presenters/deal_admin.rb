define_presenter :deal_admin do
  model :deal
  label "Deals"
  slug "deals"
  icon "dollar-sign"

  index do
    default_view :table
    default_sort :created_at, :desc
    per_page 25
    column :title, width: "30%", link_to: :show, sortable: true
    column :stage, width: "20%", display: :badge, sortable: true
    column :value, width: "20%", display: :currency, sortable: true
  end

  show do
    section "Deal Information", columns: 2 do
      field :title, display: :heading
      field :stage, display: :badge
      field :value, display: :currency
    end
  end

  form do
    section "Deal Details", columns: 2 do
      field :title, placeholder: "Deal title...", autofocus: true
      field :stage, input_type: :select
      field :value, input_type: :number
      field :company_id, input_type: :association_select
      field :contact_id, input_type: :association_select
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
    visible_when: { field: :stage, operator: :not_in, value: [:closed_won, :closed_lost] }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger

  navigation menu: :main, position: 3
end
