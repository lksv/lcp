define_presenter :showcase_fields_card, inherits: :showcase_fields_table do
  label "Field Types (Card)"
  slug "showcase-fields-card"
  read_only true

  index do
    description "Alternative card layout showing a subset of fields."
    default_view :table
    per_page 12

    column :title, link_to: :show, sortable: true, display: :heading
    column :status, display: :badge, display_options: {
      color_map: { draft: "gray", active: "green", archived: "orange", deleted: "red" }
    }
    column :price, display: :currency, display_options: { currency: "USD" }
    column :is_active, display: :boolean_icon
    column :start_date, display: :relative_date
  end

  show do
    description "Compact view with fewer sections."

    section "Overview", columns: 3 do
      field :title, display: :heading
      field :status, display: :badge, display_options: {
        color_map: { draft: "gray", active: "green", archived: "orange", deleted: "red" }
      }
      field :is_active, display: :boolean_icon
      field :price, display: :currency, display_options: { currency: "USD" }
      field :start_date, display: :date
      field :email, display: :email_link
    end
  end
end
