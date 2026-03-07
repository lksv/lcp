define_model :showcase_quick_note do
  label "Quick Note"
  table_name "_virtual"

  field :title, :string, label: "Title", limit: 100, null: false do
    validates :presence
  end

  field :body, :text, label: "Note"

  field :priority, :enum, label: "Priority",
    values: %w[low normal high urgent], default: "normal"
end
