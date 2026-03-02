define_model :showcase_userstamps do
  label "Tracked Document"
  label_plural "Tracked Documents"

  field :title, :string, label: "Title", limit: 200, null: false do
    validates :presence
  end
  field :content, :text, label: "Content"
  field :status, :enum, label: "Status", default: "draft",
    values: {
      draft: "Draft",
      review: "In Review",
      published: "Published",
      archived: "Archived"
    }
  field :priority, :enum, label: "Priority", default: "normal",
    values: { low: "Low", normal: "Normal", high: "High" }

  userstamps store_name: true

  scope :published, where: { status: "published" }
  scope :drafts, where: { status: "draft" }

  timestamps true
  label_method :title
end
