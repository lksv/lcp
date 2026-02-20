define_presenter :features_table, inherits: :features_card do
  label "Feature Catalog (Table)"
  slug "features-table"

  index do
    description "Compact table view of all platform features."
    default_view :table
    per_page 100

    column :name, width: "20%", link_to: :show, renderer: :heading, sortable: true
    column :category, renderer: :badge, options: {
      color_map: {
        field_types: "blue", display_types: "purple", input_types: "teal",
        model_features: "green", presenter: "orange", form: "cyan",
        permissions: "red", permission_source: "orange", role_source: "teal",
        extensibility: "pink", navigation: "gray", attachments: "yellow",
        authentication: "indigo", custom_fields: "cyan", virtual_fields: "emerald"
      }
    }, sortable: true
    column :description, renderer: :truncate, options: { max: 80 }
    column :status, renderer: :badge, options: {
      color_map: { stable: "green", beta: "orange", planned: "gray" }
    }
    column :demo_path, renderer: :internal_link, options: { label: "Demo" }
  end
end
