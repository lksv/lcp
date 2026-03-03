define_model :leave_type do
  label "Leave Type"
  label_plural "Leave Types"

  field :name, :string, label: "Name", limit: 255, null: false do
    validates :presence
  end

  field :code, :string, label: "Code", limit: 50, null: false do
    validates :presence
    validates :uniqueness
  end

  field :color, :color, label: "Color"

  field :default_days, :integer, label: "Default Days", default: 0 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :requires_approval, :boolean, label: "Requires Approval", default: true
  field :requires_document, :boolean, label: "Requires Document", default: false
  field :active, :boolean, label: "Active", default: true

  field :position, :integer

  has_many :leave_requests, model: :leave_request, foreign_key: :leave_type_id
  has_many :leave_balances, model: :leave_balance, foreign_key: :leave_type_id

  scope :active, where: { active: true }

  positioning

  timestamps true
  label_method :name
end
