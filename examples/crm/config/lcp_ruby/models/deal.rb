define_model :deal do
  label "Deal"
  label_plural "Deals"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end

  field :stage, :enum, label: "Stage", default: "lead",
    values: {
      lead: "Lead",
      qualified: "Qualified",
      proposal: "Proposal",
      negotiation: "Negotiation",
      closed_won: "Closed Won",
      closed_lost: "Closed Lost"
    }

  field :value, :decimal, label: "Value", precision: 12, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
    validates :presence, when: { field: :stage, operator: :not_in, value: %w[lead] }
  end

  field :priority, :integer, label: "Priority", default: 50

  field :progress, :integer, label: "Progress", default: 0

  field :weighted_value, :decimal, label: "Weighted Value", precision: 12, scale: 2,
    computed: { service: "weighted_deal_value" }

  field :expected_close_date, :date, label: "Expected Close",
    default: { service: "thirty_days_out" } do
    validates :comparison, operator: :gte, field_ref: :created_at,
      message: "cannot be before deal creation"
  end

  field :documents, :attachment, label: "Documents", options: {
    multiple: true,
    max_files: 20,
    max_size: "25MB",
    content_types: %w[application/pdf image/jpeg image/png application/vnd.openxmlformats-officedocument.wordprocessingml.document]
  }

  belongs_to :company, model: :company, required: true
  belongs_to :contact, model: :contact, required: false
  belongs_to :deal_category, model: :deal_category, required: false

  validates :contact_id, :presence, when: { field: :stage, operator: :in, value: %w[negotiation closed_won closed_lost] }

  validates_model :service, service: "deal_credit_limit"

  scope :open_deals, where_not: { stage: [ "closed_won", "closed_lost" ] }
  scope :won,        where: { stage: "closed_won" }
  scope :lost,       where: { stage: "closed_lost" }

  on_field_change :on_stage_change, field: :stage,
    condition: { field: :stage, operator: :not_in, value: %w[lead] }

  timestamps true
  label_method :title
end
