define_model :employee do
  label "Employee"
  label_plural "Employees"

  field :first_name, :string, null: false, transforms: [ :strip, :titlecase ] do
    validates :presence
  end

  field :last_name, :string, null: false, transforms: [ :strip, :titlecase ] do
    validates :presence
  end

  field :full_name, :string, computed: "{first_name} {last_name}"

  field :personal_email, :email
  field :work_email, :email, null: false do
    validates :presence
  end

  field :phone, :phone
  field :date_of_birth, :date
  field :hire_date, :date, null: false do
    validates :presence
  end

  field :termination_date, :date do
    validates :presence, when: { field: :status, operator: :eq, value: "terminated" }
  end

  field :status, :enum, default: "active",
    values: {
      active: "Active",
      on_leave: "On Leave",
      suspended: "Suspended",
      terminated: "Terminated"
    }

  field :employment_type, :enum,
    values: {
      full_time: "Full Time",
      part_time: "Part Time",
      contract: "Contract",
      intern: "Intern"
    }

  field :gender, :enum,
    values: {
      male: "Male",
      female: "Female",
      other: "Other",
      prefer_not_to_say: "Prefer Not to Say"
    }

  field :salary, :decimal, precision: 10, scale: 2

  field :currency, :enum, default: "CZK",
    values: {
      CZK: "CZK",
      EUR: "EUR",
      USD: "USD",
      GBP: "GBP"
    }

  field :photo, :attachment, options: {
    accept: "image/*",
    max_size: "5MB",
    variants: {
      thumbnail: { resize_to_fill: [ 80, 80 ] },
      medium: { resize_to_limit: [ 300, 300 ] }
    }
  }

  field :cv, :attachment, options: {
    max_size: "10MB",
    content_types: %w[application/pdf]
  }

  field :address, :json
  field :emergency_contact, :json
  field :notes, :rich_text

  belongs_to :organization_unit, model: :organization_unit, required: true
  belongs_to :position, model: :position, required: true
  belongs_to :manager, model: :employee, required: false, foreign_key: :manager_id

  has_many :subordinates, model: :employee, foreign_key: :manager_id, dependent: :nullify
  has_many :leave_requests, model: :leave_request, dependent: :destroy
  has_many :leave_balances, model: :leave_balance, dependent: :destroy
  has_many :performance_reviews, model: :performance_review, dependent: :destroy
  has_many :goals, model: :goal, dependent: :destroy
  has_many :employee_skills, model: :employee_skill, dependent: :destroy
  has_many :skills, model: :skill, through: :employee_skills
  has_many :asset_assignments, model: :asset_assignment, dependent: :nullify
  has_many :documents, model: :document, dependent: :destroy
  has_many :training_enrollments, model: :training_enrollment, dependent: :destroy
  has_many :expense_claims, model: :expense_claim, dependent: :destroy
  has_many :group_memberships, model: :group_membership, foreign_key: :employee_id
  has_many :interviews_as_interviewer, model: :interview, foreign_key: :interviewer_id
  has_many :managed_job_postings, model: :job_posting, foreign_key: :hiring_manager_id
  has_many :headed_organization_units, model: :organization_unit, foreign_key: :head_id

  scope :active, where: { status: "active" }
  scope :on_leave, where: { status: "on_leave" }
  scope :terminated, where: { status: "terminated" }

  scope :hired_within_days, type: :parameterized, parameters: [
    { name: :days, type: :integer, default: 90, min: 1 }
  ]

  scope :salary_above, type: :parameterized, parameters: [
    { name: :min_salary, type: :float, default: 50000, min: 0 }
  ]

  on_field_change :on_status_change, field: :status

  display_template :default,
    template: "{full_name}",
    subtitle: "position.title",
    badge: "status"

  soft_delete
  auditing expand_json_fields: [ :address, :emergency_contact ], expand_custom_fields: true, ignore: [ :full_name ]
  custom_fields true
  userstamps store_name: true

  timestamps true
  label_method :full_name
end
