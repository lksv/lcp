define_model :region do
  label "Region"
  label_plural "Regions"

  field :name, :string, label: "Region Name", limit: 255, null: false do
    validates :presence
  end

  belongs_to :country, model: :country, required: true
  has_many :cities, model: :city, foreign_key: :region_id, dependent: :destroy

  timestamps true
  label_method :name
end
