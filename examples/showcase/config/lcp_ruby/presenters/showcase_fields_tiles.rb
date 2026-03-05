define_presenter :showcase_fields_tiles, inherits: :showcase_fields_table do
  label "Field Types (Tiles)"
  slug "showcase-fields-tiles"

  index do
    layout :tiles
    default_sort :created_at, :desc
    per_page 6
    empty_message "No field type records found."

    tile do
      title_field :title
      subtitle_field :status, renderer: :badge, options: {
        color_map: { draft: "gray", active: "green", archived: "orange", deleted: "red" }
      }
      description_field :description, max_lines: 2
      columns 3
      card_link :show
      actions :dropdown

      field :price, label: "Price", renderer: :currency, options: { currency: "USD" }
      field :rating_value, label: "Rating", renderer: :rating, options: { max: 5 }
      field :is_active, label: "Active", renderer: :boolean_icon
      field :email, label: "Email", renderer: :email_link
      field :brand_color, label: "Color", renderer: :color_swatch
      field :start_date, label: "Date", renderer: :date, options: { format: "%B %d, %Y" }
    end

    sort_field :title, label: "Title"
    sort_field :price, label: "Price"
    sort_field :rating_value, label: "Rating"
    sort_field :start_date, label: "Start Date"
    sort_field :count, label: "Count"

    per_page_options 6, 12, 24

    summary do
      field :price, function: :sum, label: "Total Price", renderer: :currency, options: { currency: "USD" }
      field :price, function: :avg, label: "Avg Price", renderer: :currency, options: { currency: "USD" }
      field :title, function: :count, label: "Record Count"
    end
  end
end
