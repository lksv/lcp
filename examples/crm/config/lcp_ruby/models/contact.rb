define_model :contact do
  label "Contact"
  label_plural "Contacts"

  field :first_name, :string, label: "First Name", limit: 100, null: false do
    validates :presence
  end

  field :last_name, :string, label: "Last Name", limit: 100, null: false do
    validates :presence
  end

  field :email, :string, label: "Email" do
    validates :format, with: '\A[^@\s]+@[^@\s]+\z', allow_blank: true
  end

  field :phone, :string, label: "Phone"
  field :position, :string, label: "Position"

  belongs_to :company, model: :company, required: true

  timestamps true
  label_method :first_name
end
