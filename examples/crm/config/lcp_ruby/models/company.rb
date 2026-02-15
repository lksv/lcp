define_model :company do
  label "Company"
  label_plural "Companies"

  field :name, :string, label: "Company Name", limit: 255, null: false do
    validates :presence
    validates :length, minimum: 1, maximum: 255
  end

  field :industry, :enum, label: "Industry",
    values: {
      technology: "Technology",
      finance: "Finance",
      healthcare: "Healthcare",
      manufacturing: "Manufacturing",
      retail: "Retail",
      other: "Other"
    }

  field :website, :string, label: "Website"
  field :phone, :string, label: "Phone"

  has_many :contacts, model: :contact, foreign_key: :company_id, dependent: :destroy
  has_many :deals, model: :deal, foreign_key: :company_id, dependent: :destroy

  timestamps true
  label_method :name
end
