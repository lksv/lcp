define_model :showcase_soft_delete do
  label "Soft Delete Document"
  label_plural "Soft Delete Documents"

  field :title, :string, label: "Title", limit: 200, null: false, transforms: [:strip] do
    validates :presence
    validates :length, maximum: 200
  end
  field :content, :text, label: "Content"
  field :status, :enum, label: "Status", default: "draft",
    values: {
      draft: "Draft",
      active: "Active",
      archived: "Archived"
    }
  field :priority, :enum, label: "Priority", default: "normal",
    values: { low: "Low", normal: "Normal", high: "High" }

  has_many :showcase_soft_delete_items, model: :showcase_soft_delete_item,
    foreign_key: :showcase_soft_delete_id, dependent: :discard

  soft_delete
  userstamps store_name: true

  scope :active_docs, where: { status: "active" }
  scope :drafts, where: { status: "draft" }

  timestamps true
  label_method :title
end
