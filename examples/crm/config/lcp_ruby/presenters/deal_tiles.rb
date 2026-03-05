define_presenter :deal_tiles, inherits: :deal do
  label "Deals (Tiles)"
  slug "deals-tiles"

  index do
    layout :tiles
    default_sort :created_at, :desc
    per_page 12
    empty_message "No deals found"

    tile do
      title_field :title
      subtitle_field :stage, renderer: :badge, options: {
        color_map: { lead: "blue", qualified: "cyan", proposal: "orange",
                     negotiation: "purple", closed_won: "green", closed_lost: "red" }
      }
      columns 3
      card_link :show
      actions :dropdown

      field :value, label: "Value", renderer: :currency, options: { currency: "EUR" }
      field "company.name", label: "Company"
      field :progress, label: "Progress", renderer: :progress_bar
      field :priority, label: "Priority"
      field :expected_close_date, label: "Close Date"
    end

    sort_field :title, label: "Title"
    sort_field :stage, label: "Stage"
    sort_field :value, label: "Value"
    sort_field :created_at, label: "Created"
    sort_field :expected_close_date, label: "Close Date"

    per_page_options 12, 24, 48

    summary do
      field :value, function: :sum, label: "Total Value", renderer: :currency, options: { currency: "EUR" }
      field :value, function: :avg, label: "Avg Value", renderer: :currency, options: { currency: "EUR" }
      field :title, function: :count, label: "Deal Count"
    end

    item_class "lcp-row-success", when: { field: :stage, operator: :eq, value: "closed_won" }
    item_class "lcp-row-muted lcp-row-strikethrough", when: { field: :stage, operator: :eq, value: "closed_lost" }
  end
end
