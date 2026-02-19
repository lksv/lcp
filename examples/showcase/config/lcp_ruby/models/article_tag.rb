define_model :article_tag do
  label "Article Tag"
  label_plural "Article Tags"

  belongs_to :article, model: :article
  belongs_to :tag, model: :tag

  timestamps true
end
