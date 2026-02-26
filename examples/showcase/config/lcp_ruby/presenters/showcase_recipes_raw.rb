define_presenter :showcase_recipes_raw, inherits: :showcase_recipes do
  label "Recipes (Raw JSON)"
  slug "showcase-recipes-raw"

  show do
    description "Raw persistence view — steps and ingredients displayed as stored JSON."

    section "Overview", columns: 2 do
      field :title, renderer: :heading
      field :cuisine, renderer: :badge, options: {
        color_map: {
          italian: "green", mexican: "orange", japanese: "red",
          indian: "yellow", french: "blue", other: "gray"
        }
      }
      field :servings, renderer: :number
    end

    section "Steps (raw JSON)", columns: 1 do
      field :steps, renderer: :code
    end

    section "Ingredients (raw JSON)", columns: 1 do
      field :ingredients, renderer: :code
    end

    section "Metadata", columns: 2 do
      field :created_at, renderer: :relative_date
      field :updated_at, renderer: :relative_date
    end
  end
end
