define_model :tag do
  label "Tag"
  label_plural "Tags"

  field :name, :string, label: "Name", limit: 50, null: false do
    validates :presence
    validates :uniqueness
  end
  field :color, :color, label: "Color"

  has_many :article_tags, model: :article_tag, dependent: :destroy
  has_many :articles, through: :article_tags

  timestamps true
  label_method :name
end
