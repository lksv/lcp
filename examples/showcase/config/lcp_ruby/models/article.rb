define_model :article do
  label "Article"
  label_plural "Articles"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end
  field :body, :rich_text, label: "Body"
  field :status, :enum, label: "Status", default: "draft",
    values: {
      draft: "Draft",
      published: "Published",
      archived: "Archived"
    }
  field :word_count, :integer, label: "Word Count", default: 0

  belongs_to :category, model: :category, required: true
  belongs_to :author, model: :author, required: true
  has_many :comments, model: :comment, dependent: :destroy
  has_many :article_tags, model: :article_tag, dependent: :destroy
  has_many :tags, through: :article_tags

  display_template :default,
    template: "{title}",
    subtitle: "status",
    badge: "status"

  scope :published, where: { status: "published" }
  scope :drafts, where: { status: "draft" }

  timestamps true
  label_method :title
end
