define_model :organization_unit do
  label "Organization Unit"
  label_plural "Organization Units"

  field :name, :string, label: "Name", limit: 255, null: false, transforms: [:strip] do
    validates :presence
  end

  field :code, :string, label: "Code", limit: 50, null: false do
    validates :presence
    validates :uniqueness
  end

  field :description, :text, label: "Description"

  field :budget, :decimal, label: "Budget", precision: 12, scale: 2 do
    validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
  end

  field :active, :boolean, label: "Active", default: true

  field :parent_id, :integer

  belongs_to :head, model: :employee, required: false, foreign_key: :head_id

  has_many :employees, model: :employee, foreign_key: :organization_unit_id
  has_many :announcements, model: :announcement, foreign_key: :organization_unit_id
  has_many :job_postings, model: :job_posting, foreign_key: :organization_unit_id

  scope :active, where: { active: true }

  display_template :default, template: "{name}", subtitle: "{code}"

  tree max_depth: 4, dependent: :discard
  soft_delete
  auditing
  custom_fields true
  userstamps store_name: true

  timestamps true
  label_method :name
end
