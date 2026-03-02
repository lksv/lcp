define_model :showcase_search do
  label "Search Demo"
  label_plural "Search Demos"

  # String — supports: eq, not_eq, cont, not_cont, start, end, in, not_in, present, blank, null, not_null
  field :title, :string, label: "Title", limit: 200, null: false do
    validates :presence
  end

  # Text — supports: cont, not_cont, present, blank, null, not_null
  field :description, :text, label: "Description"

  # Integer — supports: eq, not_eq, gt, gteq, lt, lteq, between, in, not_in, present, blank, null, not_null
  field :quantity, :integer, label: "Quantity", default: 0

  # Float — numeric operators
  field :rating, :float, label: "Rating"

  # Decimal — numeric operators + between
  field :price, :decimal, label: "Price", precision: 10, scale: 2

  # Boolean — supports: true, not_true, false, not_false, null, not_null
  field :published, :boolean, label: "Published", default: false

  # Date — supports: eq, gt, gteq, lt, lteq, between, last_n_days, this_week/month/quarter/year, present, blank
  field :release_date, :date, label: "Release Date"

  # Datetime — same as date + time precision
  field :last_reviewed_at, :datetime, label: "Last Reviewed At"

  # Enum — supports: eq, not_eq, in, not_in, present, blank, null, not_null
  field :status, :enum, label: "Status", default: "draft",
    values: {
      draft: "Draft",
      review: "In Review",
      approved: "Approved",
      published: "Published",
      archived: "Archived"
    }

  field :priority, :enum, label: "Priority", default: "medium",
    values: {
      low: "Low",
      medium: "Medium",
      high: "High",
      critical: "Critical"
    }

  # UUID — supports: eq, not_eq, in, not_in, present, blank, null, not_null
  field :tracking_id, :uuid, label: "Tracking ID"

  # Business types (string-like operators)
  field :contact_email, :email, label: "Contact Email"
  field :contact_phone, :phone, label: "Contact Phone"
  field :source_url, :url, label: "Source URL"

  # Associations — for cascading field picker demo
  # 1-level: department.name, department.code
  belongs_to :department, model: :department, required: false
  # 1-level: category.name; 2-level: category.parent.name (self-referential)
  belongs_to :category, model: :category, required: false
  # 1-level: author.name; 2-level: author — no further assocs beyond self
  belongs_to :author, model: :author, required: false

  scope :published_items, where: { published: true }
  scope :drafts, where: { status: "draft" }
  scope :high_priority, where: { priority: %w[high critical] }
  scope :recent, order: { created_at: :desc }, limit: 10

  timestamps true
  label_method :title
end
