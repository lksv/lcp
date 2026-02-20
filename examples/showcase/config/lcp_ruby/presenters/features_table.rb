define_presenter :features_table, inherits: :features_card do
  label "Feature Catalog (Table)"
  slug "features-table"

  index do
    description "Compact table view of all platform features."
    default_view :table
    per_page 100

    column :name, width: "20%", link_to: :show, display: :heading, sortable: true
    column :category, display: :badge, display_options: {
      color_map: {
        field_types: "blue", display_types: "purple", input_types: "teal",
        model_features: "green", presenter: "orange", form: "cyan",
        permissions: "red", extensibility: "pink", navigation: "gray",
        attachments: "yellow", authentication: "indigo",
        custom_fields: "cyan"
      }
    }, sortable: true
    column :description, display: :truncate, display_options: { max: 80 }
    column :status, display: :badge, display_options: {
      color_map: { stable: "green", beta: "orange", planned: "gray" }
    }
    column :demo_path, display: :internal_link, display_options: { label: "Demo" }
  end
end
