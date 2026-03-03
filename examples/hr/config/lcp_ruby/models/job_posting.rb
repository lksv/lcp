define_model :job_posting do
  label "Job Posting"
  label_plural "Job Postings"

  field :title, :string, null: false do
    validates :presence
  end

  field :description, :rich_text

  field :status, :enum, default: "draft",
    values: {
      draft: "Draft",
      open: "Open",
      on_hold: "On Hold",
      closed: "Closed",
      filled: "Filled"
    }

  field :employment_type, :enum,
    values: {
      full_time: "Full Time",
      part_time: "Part Time",
      contract: "Contract",
      intern: "Intern"
    }

  field :location, :string

  field :remote_option, :enum,
    values: {
      on_site: "On Site",
      hybrid: "Hybrid",
      remote: "Remote"
    }

  field :salary_min, :decimal, precision: 10, scale: 2
  field :salary_max, :decimal, precision: 10, scale: 2

  field :currency, :enum, default: "CZK",
    values: {
      CZK: "CZK",
      EUR: "EUR",
      USD: "USD",
      GBP: "GBP"
    }

  field :headcount, :integer, default: 1
  field :published_at, :datetime
  field :closes_at, :date

  belongs_to :organization_unit, model: :organization_unit, required: true
  belongs_to :position, model: :position, required: true
  belongs_to :hiring_manager, model: :employee, required: true, foreign_key: :hiring_manager_id

  has_many :candidates, model: :candidate, dependent: :destroy

  scope :open, where: { status: "open" }
  scope :draft, where: { status: "draft" }

  soft_delete
  auditing
  userstamps store_name: true

  timestamps true
  label_method :title
end
