define_presenter :features_card do
  model :feature
  label "Feature Catalog"
  slug "features"
  icon "book"

  index do
    description "Browse all LCP Ruby platform features. Click any feature to see details and a link to its live demo."
    default_view :table
    default_sort :category, :asc
    per_page 50
    row_click :show

    column :name, link_to: :show, display: :heading, sortable: true
    column :category, display: :badge, display_options: {
      color_map: {
        field_types: "blue", display_types: "purple", input_types: "teal",
        model_features: "green", presenter: "orange", form: "cyan",
        permissions: "red", extensibility: "pink", navigation: "gray",
        attachments: "yellow",
        authentication: "indigo"
      }
    }, sortable: true
    column :status, display: :badge, display_options: {
      color_map: { stable: "green", beta: "orange", planned: "gray" }
    }
    column :demo_path, display: :internal_link, display_options: { label: "View Demo" }
  end

  show do
    description "Feature documentation with configuration example and link to live demo."

    section "Overview", columns: 2 do
      field :name, display: :heading
      field :category, display: :badge, display_options: {
        color_map: {
          field_types: "blue", display_types: "purple", input_types: "teal",
          model_features: "green", presenter: "orange", form: "cyan",
          permissions: "red", extensibility: "pink", navigation: "gray",
          attachments: "yellow",
        authentication: "indigo"
        }
      }
      field :status, display: :badge, display_options: {
        color_map: { stable: "green", beta: "orange", planned: "gray" }
      }
      field :demo_path, display: :internal_link, display_options: { label: "Open Demo →" }
    end

    section "Description" do
      field :description, display: :markdown
    end

    section "Configuration Example", description: "YAML/DSL snippet showing how to use this feature." do
      field :config_example, display: :markdown
    end

    section "Demo Hint", description: "What to look for when viewing the live demo." do
      field :demo_hint, display: :markdown
    end
  end

  form do
    section "Basic Info", columns: 2 do
      field :name, autofocus: true
      field :category, input_type: :select
      field :status, input_type: :select
      field :demo_path, hint: "Internal path, e.g. /showcase/showcase-fields/1"
    end

    section "Documentation" do
      field :description, input_type: :textarea, input_options: { rows: 6 },
        hint: "Supports Markdown: **bold**, `code`, lists, tables"
      field :config_example, input_type: :textarea, input_options: { rows: 8 },
        hint: "YAML or Ruby DSL snippet wrapped in markdown code fence"
      field :demo_hint, input_type: :textarea, input_options: { rows: 4 },
        hint: "Guide the user: what field/section/action to look at"
    end
  end

  search do
    searchable_fields :name, :description, :demo_hint
    placeholder "Search features..."
    filter :all, label: "All", default: true
    filter :field_types, label: "Field Types", scope: :by_category_field_types
    filter :display_types, label: "Display", scope: :by_category_display_types
    filter :input_types, label: "Input", scope: :by_category_input_types
    filter :model_features, label: "Model", scope: :by_category_model_features
    filter :presenter, label: "Presenter", scope: :by_category_presenter
    filter :form, label: "Form", scope: :by_category_form
    filter :permissions, label: "Permissions", scope: :by_category_permissions
    filter :extensibility, label: "Extensibility", scope: :by_category_extensibility
    filter :navigation, label: "Navigation", scope: :by_category_navigation
    filter :attachments, label: "Attachments", scope: :by_category_attachments
    filter :authentication, label: "Authentication", scope: :by_category_authentication
  end

  action :create, type: :built_in, on: :collection, label: "New Feature", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
