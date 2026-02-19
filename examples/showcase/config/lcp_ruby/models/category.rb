define_model :category do
  label "Category"
  label_plural "Categories"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :description, :text, label: "Description"

  belongs_to :parent, model: :category, required: false
  has_many :children, model: :category, foreign_key: :parent_id
  has_many :articles, model: :article

  timestamps true
  label_method :name
end
