define_model :department do
  label "Department"
  label_plural "Departments"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :code, :string, label: "Code", limit: 20, transforms: [ :strip, :downcase ] do
    validates :presence
    validates :uniqueness
  end
<<<<<<< HEAD
  field :parent_id, :integer

  tree true
=======
  field :parent_id, :integer, label: "Parent"
>>>>>>> ddb43eb (feat: implement tree structures with tree index view, filtered search, and drag-and-drop reparenting)

  has_many :employees, model: :employee

  tree true

  timestamps true
  label_method :name
end
