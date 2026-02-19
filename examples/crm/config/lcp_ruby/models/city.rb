define_model :city do
  label "City"
  label_plural "Cities"

  field :name, :string, label: "City Name", limit: 255, null: false do
    validates :presence
  end

  field :population, :integer, label: "Population"

  belongs_to :region, model: :region, required: true

  scope :large_cities, where: { population: (10000..) }
  scope :small_cities, where: { population: (...10000) }

  timestamps true
  label_method :name
end
