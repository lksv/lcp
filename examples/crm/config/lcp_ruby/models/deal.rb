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
  end

  field :priority, :integer, label: "Priority", default: 50

  field :progress, :integer, label: "Progress", default: 0

  belongs_to :company, model: :company, required: true
  belongs_to :contact, model: :contact, required: false

  scope :open_deals, where_not: { stage: [ "closed_won", "closed_lost" ] }
  scope :won,        where: { stage: "closed_won" }
  scope :lost,       where: { stage: "closed_lost" }

  on_field_change :on_stage_change, field: :stage

  timestamps true
  label_method :title
end
