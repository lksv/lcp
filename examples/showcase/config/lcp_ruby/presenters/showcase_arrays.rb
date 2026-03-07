define_presenter :showcase_arrays do
  model :showcase_array
  label "Array Fields"
  slug "showcase-arrays"
  icon "list"

  index do
    description "Demonstrates array fields with string, integer, and float item types. Each record uses different array configurations."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :title, link_to: :show, sortable: true, renderer: :heading
    column :record_type, renderer: :badge, options: {
      color_map: { basic: "blue", advanced: "purple", special: "orange" }
    }, sortable: true
    column :tags, renderer: :collection, options: {
      item_renderer: :badge, separator: " ", limit: 5, overflow: "..."
    }
    column :categories, renderer: :collection, options: {
      item_renderer: :badge, separator: " "
    }
    column :scores, renderer: :collection, options: {
      separator: ", "
    }
    column :featured, renderer: :boolean_icon
  end

  show do
    description "Array fields displayed with collection renderer. Sections use visible_when with array-aware operators."

    section "Overview", columns: 2 do
      field :title, renderer: :heading
      field :description
      field :record_type, renderer: :badge, options: {
        color_map: { basic: "blue", advanced: "purple", special: "orange" }
      }
      field :featured, renderer: :boolean_icon
    end

    section "String Arrays", columns: 2,
      description: "Tags (free-form) and categories (inclusion-validated)." do
      field :tags, renderer: :collection, options: {
        item_renderer: :badge, separator: " "
      }
      field :categories, renderer: :collection, options: {
        item_renderer: :badge, separator: " "
      }
      field :default_labels, renderer: :collection, options: {
        item_renderer: :badge, separator: " "
      }
    end

    section "Numeric Arrays", columns: 2,
      description: "Integer scores and float measurements." do
      field :scores, renderer: :collection, options: { separator: ", " }
      field :measurements, renderer: :collection, options: { separator: ", " }
    end

    # Conditional section: visible only when tags contain "urgent"
    section "Urgent Details", columns: 1,
      visible_when: { field: :tags, operator: :contains, value: "urgent" },
      description: "This section appears only when tags contain 'urgent'." do
      field :description
    end

    # Conditional section: visible only when scores is not empty
    section "Score Analysis", columns: 1,
      visible_when: { field: :scores, operator: :not_empty },
      description: "This section appears only when scores array is not empty." do
      field :scores, renderer: :collection, options: { separator: ", " }
    end

    section "Metadata", columns: 2 do
      field :created_at, renderer: :relative_date
      field :updated_at, renderer: :relative_date
    end
  end

  form do
    description "Array inputs with tag-style chips. Supports suggestions, max items, and placeholder text."

    section "General", columns: 2 do
      field :title, placeholder: "Enter title...", autofocus: true, col_span: 2
      field :description, input_type: :textarea, input_options: { rows: 3 }, col_span: 2
      field :record_type, input_type: :select
      field :featured, input_type: :toggle
    end

    section "String Arrays", columns: 1,
      description: "Free-form tags and constrained categories." do
      info "Tags accept any value. Categories are restricted to a predefined set."
      field :tags, input_type: :array_input, input_options: {
        placeholder: "Add a tag...",
        max: 10,
        suggestions: %w[ruby rails javascript python devops tutorial review urgent]
      }
      field :categories, input_type: :array_input, input_options: {
        placeholder: "Add category...",
        max: 3,
        suggestions: %w[frontend backend devops design qa management]
      }
    end

    section "Numeric Arrays", columns: 1,
      description: "Integer scores (1-5 only) and float measurements." do
      info "Scores are validated against allowed values [1, 2, 3, 4, 5]. Measurements accept any float."
      field :scores, input_type: :array_input, input_options: {
        placeholder: "Add score (1-5)...",
        max: 5,
        suggestions: %w[1 2 3 4 5]
      }
      field :measurements, input_type: :array_input, input_options: {
        placeholder: "Add measurement..."
      }
    end

    # Conditional section: visible only for advanced/special types
    section "Default Labels (Advanced)", columns: 1, collapsible: true,
      visible_when: { field: :record_type, operator: :not_eq, value: "basic" },
      description: "This section is hidden when type is 'basic'. Demonstrates visible_when on array form sections." do
      field :default_labels, input_type: :array_input, input_options: {
        placeholder: "Add label...",
        suggestions: %w[priority-high priority-low needs-review approved]
      }
    end
  end

  search do
    searchable_fields :title, :description, :tags
    placeholder "Search array demos..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
