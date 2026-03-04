define_model :announcement do
  label "Announcement"
  label_plural "Announcements"
  label_method :title

  field :title, :string, null: false do
    validates :presence
  end

  field :body, :rich_text

  field :priority, :enum, default: "normal",
    values: {
      normal: "Normal",
      important: "Important",
      urgent: "Urgent"
    }

  field :published, :boolean, default: false
  field :published_at, :datetime
  field :expires_at, :date
  field :pinned, :boolean, default: false

  belongs_to :organization_unit, model: :organization_unit, required: false

  scope :published, where: { published: true }
  scope :active, where: { published: true }

  soft_delete
  userstamps store_name: true

  timestamps true
end
