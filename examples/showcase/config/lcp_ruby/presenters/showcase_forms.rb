define_presenter :showcase_forms do
  model :showcase_form
  label "Form Features"
  slug "showcase-forms"
  icon "edit"

  index do
    description "Each record demonstrates a different combination of form features."
    default_sort :created_at, :desc
    per_page 25

    column :name, link_to: :show, sortable: true
    column :form_type, renderer: :badge, options: {
      color_map: { simple: "blue", advanced: "purple", special: "orange" }
    }
    column :priority, renderer: :number
    column :is_premium, renderer: :boolean_icon
  end

  show do
    section "Overview", columns: 2 do
      field :name, renderer: :heading
      field :form_type, renderer: :badge, options: {
        color_map: { simple: "blue", advanced: "purple", special: "orange" }
      }
      field :priority, renderer: :number
      field :satisfaction, renderer: :rating, options: { max: 5 }
      field :is_premium, renderer: :boolean_icon
    end

    section "Details" do
      field :detailed_notes, renderer: :rich_text
      field :reason
      field :rejection_reason
      field :advanced_field_1
      field :advanced_field_2
      field :config_data, renderer: :code
    end
  end

  form do
    description "This form uses a tabbed layout to demonstrate all form features."
    layout :tabs

    section "Layout Features", columns: 2, description: "Collapsible sections, dividers, info blocks, and field hints." do
      info "This section demonstrates layout features. Dividers, info blocks, hints, placeholders, and col_span."
      field :name, placeholder: "Enter name...", autofocus: true, hint: "This field has a hint.", col_span: 2
      divider label: "Type Selection"
      field :form_type, input_type: :select
      field :is_premium, input_type: :toggle
    end

    section "Input Types", columns: 2, description: "Slider, rating, rich text editor, and numeric inputs." do
      info "Each field uses a specific input type to demonstrate the available form controls."
      field :priority, input_type: :slider, input_options: { min: 0, max: 100, step: 5, show_value: true }
      field :satisfaction, input_type: :slider, input_options: { min: 1, max: 5, step: 1, show_value: true }
      field :detailed_notes, input_type: :rich_text_editor, col_span: 2
      field :config_data, input_type: :textarea, input_options: { rows: 4 }, col_span: 2, hint: "Enter valid JSON"
    end

    section "Conditional Rendering", columns: 2, description: "Fields and sections that show/hide based on other field values." do
      info "Change the 'Type' field to 'advanced' to see the advanced fields appear. Set 'Premium' to true to show the reason field."
      field :reason, visible_when: { field: :is_premium, operator: :eq, value: true },
        hint: "This field only appears when Premium is true."
      field :rejection_reason, input_type: :textarea,
        visible_when: { field: :form_type, operator: :eq, value: "special" },
        hint: "This field only appears when Type is 'special'."
      field :advanced_field_1,
        visible_when: { field: :form_type, operator: :in, value: %w[advanced special] },
        hint: "Visible for 'advanced' and 'special' types."
      field :advanced_field_2,
        visible_when: { field: :form_type, operator: :eq, value: "advanced" },
        disable_when: { field: :is_premium, operator: :eq, value: true },
        hint: "Visible for 'advanced', disabled when Premium."
    end

    section "Conditional Section", columns: 1, collapsible: true,
      visible_when: { field: :form_type, operator: :not_eq, value: "simple" },
      description: "This entire section is hidden when type is 'simple'." do
      info "This section demonstrates section-level visible_when. It only appears for 'advanced' or 'special' types."
      field :config_data, input_type: :textarea, input_options: { rows: 6 }, hint: "Additional configuration for non-simple types."
    end
  end

  search do
    searchable_fields :name, :reason
    placeholder "Search form features..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Record"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
