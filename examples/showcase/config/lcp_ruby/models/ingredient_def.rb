define_model :ingredient_def do
  table_name "_virtual"

  field :name, :string do
    validates :presence
  end
  field :quantity, :string
  field :unit, :enum, values: %w[g kg ml l pcs tbsp tsp]
  field :notes, :text
  field :optional, :boolean
end
