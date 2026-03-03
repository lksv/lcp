define_model :candidate do
  label "Candidate"
  label_plural "Candidates"

  field :first_name, :string, null: false, transforms: [ :strip, :titlecase ] do
    validates :presence
  end

  field :last_name, :string, null: false, transforms: [ :strip, :titlecase ] do
    validates :presence
  end

  field :full_name, :string, computed: "{first_name} {last_name}"

  field :email, :email, null: false do
    validates :presence
  end

  field :phone, :phone

  field :status, :enum, default: "applied",
    values: {
      applied: "Applied",
      screening: "Screening",
      interviewing: "Interviewing",
      offer: "Offer",
      hired: "Hired",
      rejected: "Rejected",
      withdrawn: "Withdrawn"
    }

  field :source, :enum,
    values: {
      website: "Website",
      referral: "Referral",
      linkedin: "LinkedIn",
      agency: "Agency",
      job_board: "Job Board",
      other: "Other"
    }

  field :resume, :attachment, options: {
    max_size: "10MB",
    content_types: %w[application/pdf]
  }

  field :cover_letter, :text
  field :rating, :integer
  field :notes, :rich_text
  field :rejection_reason, :text

  belongs_to :job_posting, model: :job_posting, required: true

  has_many :interviews, model: :interview, dependent: :destroy

  on_field_change :on_status_change, field: :status

  display_template :default,
    template: "{full_name}",
    subtitle: "status",
    badge: "status"

  auditing
  userstamps store_name: true

  timestamps true
  label_method :full_name
end
