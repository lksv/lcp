define_presenter :features_tiles, inherits: :features_card do
  label "Feature Catalog (Tiles)"
  slug "features-tiles"

  index do
    layout :tiles
    default_sort :category, :asc
    per_page 12
    empty_message "No features found."

    tile do
      title_field :name
      subtitle_field :category, renderer: :badge, options: {
        color_map: {
          field_types: "blue", display_types: "purple", input_types: "teal",
          model_features: "green", presenter: "orange", form: "cyan",
          permissions: "red", permission_source: "orange", role_source: "teal",
          groups: "violet", extensibility: "pink",
          navigation: "gray", attachments: "yellow", authentication: "indigo",
          custom_fields: "cyan", virtual_fields: "emerald",
          positioning: "lime", search: "sky", tiles: "amber"
        }
      }
      description_field :description, max_lines: 2
      columns 3
      card_link :show
      actions :dropdown

      field :status, label: "Status", renderer: :badge, options: {
        color_map: { stable: "green", beta: "orange", planned: "gray" }
      }
    end

    sort_field :name, label: "Name"
    sort_field :category, label: "Category"
    sort_field :status, label: "Status"

    per_page_options 12, 24, 48
  end
end
