define_model :showcase_extensibility do
  label "Extensibility"
  label_plural "Extensibility"

  field :name, :string, label: "Name", limit: 100, null: false, transforms: [ :strip ] do
    validates :presence
  end

  field :currency, :string, label: "Currency Code", limit: 3, transforms: [ :strip ] do
    validates :format, with: /\A[A-Z]{3}\z/, message: "must be a 3-letter ISO currency code", allow_blank: true
  end

  field :amount, :decimal, label: "Amount", precision: 12, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :score, :integer, label: "Score",
    computed: { service: "showcase_total" }

  field :normalized_name, :string, label: "Normalized Name",
    computed: { template: "{name} [{currency}]" }

  timestamps true
  label_method :name
end
