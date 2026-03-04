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

  field :website, :url, label: "Website"
  field :phone, :phone, label: "Phone"

  field :address_type, :enum, label: "Address Type", default: "unknown",
    values: {
      unknown: "Unknown",
      known: "Known"
    }

  field :street, :string, label: "Street"

  field :logo, :attachment, label: "Logo", options: {
    accept: "image/*",
    max_size: "2MB",
    content_types: %w[image/jpeg image/png image/svg+xml image/webp],
    variants: {
      thumbnail: { resize_to_limit: [ 60, 60 ] },
      medium: { resize_to_limit: [ 200, 200 ] }
    }
  }

  field :contract_template, :attachment, label: "Contract Template", options: {
    max_size: "20MB",
    content_types: %w[application/pdf application/vnd.openxmlformats-officedocument.wordprocessingml.document]
  }

  has_many :contacts, model: :contact, foreign_key: :company_id, dependent: :discard
  has_many :deals, model: :deal, foreign_key: :company_id, dependent: :discard
  has_many :activities, model: :activity, foreign_key: :company_id, dependent: :discard

  belongs_to :country, model: :country, required: false
  belongs_to :region, model: :region, required: false
  belongs_to :city, model: :city, required: false

  aggregate :contacts_count, function: :count, association: :contacts
  aggregate :deals_count, function: :count, association: :deals
  aggregate :total_deal_value, function: :sum, association: :deals, source_field: :value, default: 0
  aggregate :won_deals_value, function: :sum, association: :deals, source_field: :value,
    where: { stage: "closed_won" }, default: 0

  custom_fields true
  soft_delete

  timestamps true
  label_method :name
end
