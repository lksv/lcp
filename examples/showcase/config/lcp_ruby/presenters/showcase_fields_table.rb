define_presenter :showcase_fields_table do
  model :showcase_field
  label "Field Types (Table)"
  slug "showcase-fields"
  icon "grid"

  index do
    description "Every column uses a different display type to demonstrate the full range of display renderers."
    default_view :table
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :title, width: "15%", link_to: :show, sortable: true, renderer: :heading
    column :description, width: "15%", renderer: :truncate, options: { max: 50 }
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", active: "green", archived: "orange", deleted: "red" }
    }, sortable: true
    column :priority, renderer: :badge, options: {
      color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
    }
    column :is_active, renderer: :boolean_icon
    column :count, renderer: :number
    column :rating_value, renderer: :rating, options: { max: 5 }
    column :price, renderer: :currency, options: { currency: "USD" }, sortable: true, summary: "sum"
    column :email, renderer: :email_link
    column :website, renderer: :url_link
    column :brand_color, renderer: :color_swatch
    column :start_date, renderer: :date, options: { format: "%B %d, %Y" }
    column :event_time, renderer: :relative_date
  end

  show do
    description "Organized by display category. Each field uses a specific display renderer."

    section "Text Displays", columns: 2, description: "Heading, truncate, code, and rich text renderers." do
      field :title, renderer: :heading
      field :description, renderer: :truncate, options: { max: 100 }
      field :external_id, renderer: :code
      field :notes, renderer: :rich_text
    end

    section "Visual Displays", columns: 2, description: "Badges, icons, progress bars, and color swatches." do
      field :status, renderer: :badge, options: {
        color_map: { draft: "gray", active: "green", archived: "orange", deleted: "red" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "blue", medium: "cyan", high: "orange", critical: "red" }
      }
      field :is_active, renderer: :boolean_icon
      field :brand_color, renderer: :color_swatch
      field :rating_value, renderer: :rating, options: { max: 5 }
    end

    section "Numeric Displays", columns: 2, description: "Currency, percentage, number, and file size renderers." do
      field :count, renderer: :number
      field :price, renderer: :currency, options: { currency: "USD" }
      field :metadata, renderer: :code
    end

    section "Link Displays", columns: 2, description: "Email, phone, URL, and generic link renderers." do
      field :email, renderer: :email_link
      field :phone, renderer: :phone_link
      field :website, renderer: :url_link
    end

    section "Temporal Displays", columns: 2, description: "Date, datetime, and relative date renderers." do
      field :start_date, renderer: :date, options: { format: "%B %d, %Y" }
      field :event_time, renderer: :datetime, options: { format: "%Y-%m-%d %H:%M" }
      field :created_at, renderer: :relative_date
    end
  end

  form do
    description "All field types with their default input controls."

    section "Text Fields", columns: 2, description: "String, text, and rich text inputs." do
      field :title, placeholder: "Enter a title...", autofocus: true
      field :description, input_type: :textarea, input_options: { rows: 3 }
      field :notes, input_type: :rich_text_editor, col_span: 2
    end

    section "Numeric Fields", columns: 3, description: "Integer, float, and decimal inputs." do
      field :count, input_type: :number
      field :rating_value, input_type: :number, input_options: { min: 0, max: 5, step: 0.5 }
      field :price, input_type: :number, prefix: "$"
    end

    section "Boolean & Enum Fields", columns: 2, description: "Toggle switches and select dropdowns." do
      field :is_active, input_type: :toggle
      field :status, input_type: :select
      field :priority, input_type: :select
    end

    section "Date & Time Fields", columns: 2, description: "Date picker and datetime inputs." do
      field :start_date, input_type: :date_picker
      field :event_time, input_type: :datetime
    end

    section "Business Type Fields", columns: 2, description: "Email, phone, URL, and color inputs with built-in validation and transforms." do
      info "Business types apply automatic validation and normalization. For example, email is lowercased and phone numbers are cleaned."
      field :email
      field :phone
      field :website
      field :brand_color
    end

    section "Special Fields", columns: 2, description: "JSON, UUID, and metadata inputs." do
      field :metadata, input_type: :textarea, input_options: { rows: 4 }, hint: "Enter valid JSON"
      field :external_id, hint: "UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    end
  end

  search do
    searchable_fields :title, :description, :email
    placeholder "Search field types..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
