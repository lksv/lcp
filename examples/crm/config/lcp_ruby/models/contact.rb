define_model :contact do
  label "Contact"
  label_plural "Contacts"

  field :first_name, :string, label: "First Name", limit: 100, null: false do
    validates :presence
  end

  field :last_name, :string, label: "Last Name", limit: 100, null: false do
    validates :presence
  end

  field :email, :email, label: "Email"
  field :phone, :phone, label: "Phone"
  field :position, :string, label: "Position"
  field :active, :boolean, label: "Active", default: true

  belongs_to :company, model: :company, required: true

  timestamps true
  label_method :first_name
end
