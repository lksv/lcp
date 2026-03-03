define_presenter :showcase_searches do
  model :showcase_search
  label "Advanced Search"
  slug "showcase-search"
  icon "search"

  index do
    description "Demonstrates the advanced filter builder with all supported field types, operators, cascading field picker, OR groups, nesting, query language, and filter presets."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :title, link_to: :show, sortable: true, renderer: :truncate, options: { max: 40 }
    column :status, renderer: :badge, options: {
      color_map: { draft: "gray", review: "orange", approved: "blue", published: "green", archived: "red" }
    }, sortable: true
    column :priority, renderer: :badge, options: {
      color_map: { low: "gray", medium: "blue", high: "orange", critical: "red" }
    }, sortable: true
    column :price, renderer: :currency, options: { currency: "USD" }, sortable: true
    column :quantity, sortable: true
    column :published, renderer: :boolean
    column :release_date, renderer: :date, sortable: true
    column "department.name", label: "Department"
    column "category.name", label: "Category"
    column "author.name", label: "Author"

    includes :department, :category, :author
  end

  show do
    description "Record detail with all field types used in the advanced filter."

    section "General", columns: 2 do
      field :title, renderer: :heading
      field :description, renderer: :text
      field :status, renderer: :badge, options: {
        color_map: { draft: "gray", review: "orange", approved: "blue", published: "green", archived: "red" }
      }
      field :priority, renderer: :badge, options: {
        color_map: { low: "gray", medium: "blue", high: "orange", critical: "red" }
      }
    end

    section "Numeric Fields", columns: 2 do
      field :quantity, renderer: :number
      field :rating, renderer: :number
      field :price, renderer: :currency, options: { currency: "USD" }
    end

    section "Date & Boolean", columns: 2 do
      field :published, renderer: :boolean
      field :release_date, renderer: :date
      field :last_reviewed_at, renderer: :datetime
    end

    section "Contact & Tracking", columns: 2 do
      field :contact_email, renderer: :email_link
      field :contact_phone, renderer: :phone_link
      field :source_url, renderer: :url_link
      field :tracking_id, renderer: :code
    end

    section "Associations", columns: 2 do
      field "department.name", label: "Department"
      field "category.name", label: "Category"
      field "author.name", label: "Author"
    end

    section "Metadata", columns: 2 do
      field :created_at, renderer: :relative_date
      field :updated_at, renderer: :relative_date
    end

    includes :department, :category, :author
  end

  form do
    section "General", columns: 2 do
      field :title, placeholder: "Enter title...", autofocus: true, col_span: 2
      field :description, input_type: :textarea, input_options: { rows: 3 }
      field :status, input_type: :select
      field :priority, input_type: :select
    end

    section "Numbers", columns: 2 do
      field :quantity, input_type: :number
      field :rating, input_type: :number
      field :price, input_type: :number, prefix: "$"
    end

    section "Dates & Boolean", columns: 2 do
      field :published, input_type: :toggle
      field :release_date, input_type: :date_picker
      field :last_reviewed_at, input_type: :datetime_picker
    end

    section "Contact & Tracking", columns: 2, collapsible: true do
      field :contact_email
      field :contact_phone
      field :source_url
      field :tracking_id, hint: "UUID format"
    end

    section "Associations", columns: 2 do
      field :department_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name, include_blank: "Select department..." }
      field :category_id, input_type: :tree_select,
        input_options: { parent_field: :parent_id, label_method: :name, max_depth: 3 }
      field :author_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name, include_blank: "Select author..." }
    end
  end

  search do
    searchable_fields :title, :description, :contact_email
    placeholder "Quick search by title, description, email..."
    filter :all, label: "All", default: true
    filter :published_items, label: "Published", scope: :published_items
    filter :drafts, label: "Drafts", scope: :drafts
    filter :high_priority, label: "High Priority", scope: :high_priority

    advanced_filter do
      enabled true
      max_conditions 20
      max_nesting_depth 3
      max_association_depth 2
      allow_or_groups true
      query_language true

      # All field types + association traversal up to depth 2
      # String, Text, Integer, Float, Decimal, Boolean, Date, Datetime,
      # Enum, UUID, Business types (email/phone/url), Timestamps,
      # Association depth 1 (department, category, author),
      # Association depth 2 (category.parent)
      filterable_fields :title, :description, :quantity, :rating, :price,
        :published, :release_date, :last_reviewed_at,
        :status, :priority, :tracking_id,
        :contact_email, :contact_phone, :source_url, :created_at,
        "department.name", "department.code",
        "category.name", "category.parent.name",
        "author.name", "author.email"

      # Per-field operator overrides
      field_options :status, operators: %i[eq not_eq in not_in present blank]
      field_options :priority, operators: %i[eq not_eq in not_in]
      field_options :price, operators: %i[eq not_eq gt gteq lt lteq between present blank]
      field_options :quantity, operators: %i[eq not_eq gt gteq lt lteq between]

      # Presets demonstrating various operator combinations
      preset :expensive_published,
        label: "Expensive & published",
        conditions: [
          { field: "published", operator: "true" },
          { field: "price", operator: "gteq", value: "100" }
        ]

      preset :recent_drafts,
        label: "Recent drafts",
        conditions: [
          { field: "status", operator: "eq", value: "draft" },
          { field: "created_at", operator: "last_n_days", value: "30" }
        ]

      preset :high_priority_review,
        label: "High priority in review",
        conditions: [
          { field: "priority", operator: "in", value: %w[high critical] },
          { field: "status", operator: "eq", value: "review" }
        ]

      preset :releasing_this_month,
        label: "Releasing this month",
        conditions: [
          { field: "release_date", operator: "this_month" },
          { field: "status", operator: "not_eq", value: "archived" }
        ]

      saved_filters do
        enabled true
        display :inline
        max_visible_pinned 5
      end
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
