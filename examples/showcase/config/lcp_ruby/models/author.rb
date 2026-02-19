define_model :author do
  label "Author"
  label_plural "Authors"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :email, :email, label: "Email"
  field :bio, :text, label: "Bio"

  has_many :articles, model: :article

  timestamps true
  label_method :name
end
