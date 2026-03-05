define_presenter :company_tiles, inherits: :company do
  label "Companies (Tiles)"
  slug "companies-tiles"

  index do
    layout :tiles
    default_sort :name, :asc
    per_page 12

    tile do
      title_field :name
      subtitle_field :industry, renderer: :badge
      columns 3
      card_link :show
      actions :dropdown

      field :phone, renderer: :phone_link
      field :website, renderer: :url_link
      field :contacts_count, label: "Contacts"
      field :deals_count, label: "Deals"
      field :total_deal_value, label: "Deal Value", renderer: :currency, options: { currency: "EUR" }
    end

    sort_field :name, label: "Name"
    sort_field :industry, label: "Industry"
    sort_field :contacts_count, label: "Contacts"
    sort_field :total_deal_value, label: "Deal Value"

    per_page_options 12, 24, 48

    summary do
      field :total_deal_value, function: :sum, label: "Total Deal Value", renderer: :currency, options: { currency: "EUR" }
      field :contacts_count, function: :sum, label: "Total Contacts"
    end
  end
end
