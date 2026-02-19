define_presenter :showcase_models do
  model :showcase_model
  label "Model Features"
  slug "showcase-models"
  icon "layers"

  index do
    description "Demonstrates model-level features: defaults, computed fields, validations, transforms, scopes."
    default_sort :created_at, :desc
    per_page 25
    row_click :show

    column :name, link_to: :show, sortable: true
    column :code, display: :code, sortable: true
    column :status, display: :badge, display_options: {
      color_map: { draft: "gray", active: "green", completed: "blue", cancelled: "red" }
    }, sortable: true
    column :amount, display: :currency, display_options: { currency: "USD" }, sortable: true
    column :computed_label
    column :computed_score, display: :number
    column :due_date, display: :date
  end

  show do
    description "Each section groups fields by the model feature they demonstrate."

    section "Identity & Transforms", columns: 2, description: "name uses strip transform. code uses strip + downcase." do
      field :name, display: :heading
      field :code, display: :code
      field :computed_label
    end

    section "Enums & Defaults", columns: 2, description: "status has a default of 'draft'. due_date defaults to current_date. auto_date uses a service default." do
      field :status, display: :badge, display_options: {
        color_map: { draft: "gray", active: "green", completed: "blue", cancelled: "red" }
      }
      field :due_date, display: :date
      field :auto_date, display: :date
    end

    section "Validations & Computed", columns: 2, description: "amount has conditional presence. computed_score is service-based. min/max_value demonstrate cross-field comparison." do
      field :amount, display: :currency, display_options: { currency: "USD" }
      field :computed_score, display: :number
      field :min_value, display: :number
      field :max_value, display: :number
    end

    section "Business Types", columns: 2, description: "Built-in types with automatic transforms and validations." do
      field :email, display: :email_link
      field :phone, display: :phone_link
      field :website, display: :url_link
    end

    section "Metadata", columns: 1 do
      field :tags_json, display: :code
      field :created_at, display: :relative_date
    end
  end

  form do
    description "Fields are grouped by the model feature they demonstrate."

    section "Identity & Transforms", columns: 2, description: "Demonstrates strip and downcase transforms." do
      info "The 'name' field applies strip transform. The 'code' field applies strip + downcase and validates format."
      field :name, placeholder: "Enter name...", autofocus: true
      field :code, placeholder: "e.g. my-code-123", hint: "Only lowercase letters, numbers, hyphens and underscores."
    end

    section "Status & Defaults", columns: 2, description: "Demonstrates default values and conditional validations." do
      info "Status defaults to 'draft'. Due date defaults to today. Auto date defaults via service (one_week_from_now)."
      field :status, input_type: :select
      field :amount, input_type: :number, prefix: "$", hint: "Required when status is active or completed."
      field :due_date, input_type: :date_picker
      field :auto_date, input_type: :date_picker, hint: "Defaults to one week from now if left blank."
    end

    section "Cross-Field Validation", columns: 2, description: "Demonstrates comparison validators with field_ref." do
      info "min_value must be less than max_value. This is enforced by a comparison validator."
      field :min_value, input_type: :number
      field :max_value, input_type: :number
    end

    section "Business Types", columns: 2, description: "Types with built-in transforms and validations." do
      field :email, hint: "Automatically lowercased and trimmed."
      field :phone, hint: "Automatically normalized."
      field :website, hint: "Automatically normalized with protocol."
    end

    section "Extra", columns: 1, collapsible: true, collapsed: true do
      field :tags_json, input_type: :textarea, input_options: { rows: 4 }, hint: "Enter valid JSON"
    end
  end

  search do
    searchable_fields :name, :code, :email
    placeholder "Search model features..."
    filter :all, label: "All", default: true
    filter :active, label: "Active", scope: :active
    filter :draft, label: "Draft", scope: :draft
    filter :recent, label: "Recent 10", scope: :recent
  end

  action :create, type: :built_in, on: :collection, label: "New Record", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
