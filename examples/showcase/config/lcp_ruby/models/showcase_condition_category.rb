define_model :showcase_condition_category do
  label "Condition Category"
  label_plural "Condition Categories"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :industry, :string, label: "Industry", limit: 100
  field :country_code, :string, label: "Country Code", limit: 10
  field :verified, :boolean, label: "Verified", default: false

  timestamps true
  label_method :name
end
