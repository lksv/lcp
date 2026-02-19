define_presenter :showcase_fields_card, inherits: :showcase_fields_table do
  label "Field Types (Card)"
  slug "showcase-fields-card"
  read_only true

  index do
    description "Alternative card layout showing a subset of fields."
    default_view :table
    per_page 12

    column :title, link_to: :show, sortable: true, renderer: :heading
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", active: "green", archived: "orange", deleted: "red" }
    }
    column :price, renderer: :currency, options: { currency: "USD" }
    column :is_active, renderer: :boolean_icon
    column :start_date, renderer: :relative_date
  end

  show do
    description "Compact view with fewer sections."

    section "Overview", columns: 3 do
      field :title, renderer: :heading
      field :status, renderer: :badge, options: {
        color_map: { draft: "gray", active: "green", archived: "orange", deleted: "red" }
      }
      field :is_active, renderer: :boolean_icon
      field :price, renderer: :currency, options: { currency: "USD" }
      field :start_date, renderer: :date
      field :email, renderer: :email_link
    end
  end
end
