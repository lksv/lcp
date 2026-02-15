define_model :project do
  label "Project"
  label_plural "Projects"

  field :title, :string, label: "Title", limit: 255, null: false do
    validates :presence
    validates :length, minimum: 3, maximum: 255
  end

  field :status, :enum, label: "Status", default: "draft",
    values: { draft: "Draft", active: "Active", completed: "Completed", archived: "Archived" }

  field :description, :text, label: "Description"

  field :budget, :decimal, label: "Budget", precision: 12, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :due_date, :date, label: "Due Date"
  field :start_date, :date, label: "Start Date"
  field :priority, :integer, label: "Priority", default: 0

  has_many :tasks, model: :task, dependent: :destroy
  belongs_to :client, class_name: "Client", foreign_key: :client_id, required: false

  scope :active,       where: { status: "active" }
  scope :not_archived, where_not: { status: "archived" }
  scope :recent,       order: { created_at: :desc }, limit: 10

  after_create
  after_update
  on_field_change :on_status_change, field: :status

  timestamps true
  label_method :title
end
