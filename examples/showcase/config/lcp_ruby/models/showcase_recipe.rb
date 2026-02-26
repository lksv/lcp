define_model :showcase_recipe do
  label "Recipe"
  label_plural "Recipes"

  field :title, :string, label: "Title", limit: 200, null: false do
    validates :presence
  end
  field :cuisine, :enum, label: "Cuisine", default: "other",
    values: { italian: "Italian", mexican: "Mexican", japanese: "Japanese",
              indian: "Indian", french: "French", other: "Other" }
  field :servings, :integer, label: "Servings", default: 4
  field :steps, :json, label: "Steps"
  field :ingredients, :json, label: "Ingredients"

  timestamps true
  label_method :title
end
