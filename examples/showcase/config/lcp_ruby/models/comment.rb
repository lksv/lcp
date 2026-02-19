define_model :comment do
  label "Comment"
  label_plural "Comments"

  field :body, :text, label: "Body", null: false do
    validates :presence
  end
  field :author_name, :string, label: "Author Name", limit: 100, null: false do
    validates :presence
  end
  field :position, :integer, label: "Position", default: 0

  belongs_to :article, model: :article

  display_template :default,
    template: "{author_name}",
    subtitle: "body"

  timestamps true
  label_method :author_name
end
