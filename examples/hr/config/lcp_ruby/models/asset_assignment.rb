define_model :asset_assignment do
  label "Asset Assignment"
  label_plural "Asset Assignments"

  field :assigned_at, :date, null: false do
    validates :presence
  end

  field :returned_at, :date

  field :condition_on_assign, :enum,
    values: {
      new: "New",
      good: "Good",
      fair: "Fair",
      poor: "Poor"
    }

  field :condition_on_return, :enum,
    values: {
      good: "Good",
      fair: "Fair",
      poor: "Poor",
      damaged: "Damaged"
    }

  field :notes, :text

  belongs_to :asset, model: :asset, required: true
  belongs_to :employee, model: :employee, required: true

  after_create

  auditing
  userstamps store_name: true

  timestamps true
end
