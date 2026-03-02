define_model :category do
  label "Category"
  label_plural "Categories"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :description, :text, label: "Description"
<<<<<<< HEAD
  field :parent_id, :integer

  tree true
=======
  field :parent_id, :integer, label: "Parent"
>>>>>>> ddb43eb (feat: implement tree structures with tree index view, filtered search, and drag-and-drop reparenting)

  has_many :articles, model: :article

  tree true

  timestamps true
  label_method :name
end
