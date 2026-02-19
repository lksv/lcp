define_model :feature_dsl do
  label "DSL Record"
  label_plural "DSL Records"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
  end

  field :body, :text, label: "Body"

  field :active, :boolean, label: "Active", default: true

  timestamps true
  label_method :title
end
