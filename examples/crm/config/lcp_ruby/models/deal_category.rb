define_model :deal_category do
  label "Deal Category"
  label_plural "Deal Categories"

  field :name, :string, label: "Category Name", limit: 255, null: false do
    validates :presence
  end

  belongs_to :parent, model: :deal_category, foreign_key: :parent_id, required: false
  has_many :children, model: :deal_category, foreign_key: :parent_id

  timestamps true
  label_method :name
end
