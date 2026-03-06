define_model :gapfree_sequence do
  table_name "lcp_gapfree_sequences"

  field :seq_model, :string
  field :seq_field, :string
  field :scope_key, :string
  field :current_value, :integer, default: 0

  validates :seq_model, :presence
  validates :seq_field, :presence
  validates :scope_key, :presence

  index %i[seq_model seq_field scope_key], unique: true

  timestamps true
  label_method :seq_model
end
