define_model :showcase_aggregate_company do
  label "Aggregate Company"
  label_plural "Aggregate Companies"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :country, :string, label: "Country", limit: 100

  has_many :showcase_aggregates, model: :showcase_aggregate, foreign_key: :company_id

  timestamps true
  label_method :name
end
