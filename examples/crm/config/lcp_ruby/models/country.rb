define_model :country do
  label "Country"
  label_plural "Countries"

  field :name, :string, label: "Country Name", limit: 255, null: false do
    validates :presence
    validates :length, minimum: 1, maximum: 255
  end

  field :code, :string, label: "Code", limit: 3

  field :active, :boolean, label: "Active", default: true

  has_many :regions, model: :region, foreign_key: :country_id, dependent: :destroy

  scope :active, where: { active: true }
  scope :with_archived, order: { name: :asc }

  timestamps true
  label_method :name
end
