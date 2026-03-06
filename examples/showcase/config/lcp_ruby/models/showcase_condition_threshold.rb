define_model :showcase_condition_threshold do
  label "Condition Threshold"
  label_plural "Condition Thresholds"

  field :key, :string, label: "Key", limit: 50, null: false do
    validates :presence
  end
  field :threshold, :decimal, label: "Threshold", precision: 10, scale: 2, null: false
  field :label, :string, label: "Label", limit: 100

  timestamps true
  label_method :key
end
