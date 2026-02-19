define_model :contact do
  label "Contact"
  label_plural "Contacts"

  field :first_name, :string, label: "First Name", limit: 100, null: false,
    transforms: [ :strip, :titlecase ] do
    validates :presence
  end

  field :last_name, :string, label: "Last Name", limit: 100, null: false,
    transforms: [ :strip, :titlecase ] do
    validates :presence
  end

  field :full_name, :string, label: "Full Name",
    computed: "{first_name} {last_name}"

  field :email, :email, label: "Email"
  field :phone, :phone, label: "Phone"
  field :position, :string, label: "Position"
  field :active, :boolean, label: "Active", default: true

  field :avatar, :attachment, label: "Avatar", options: {
    accept: "image/*",
    max_size: "5MB",
    content_types: %w[image/jpeg image/png image/webp],
    variants: {
      thumbnail: { resize_to_fill: [40, 40] },
      medium: { resize_to_limit: [200, 200] }
    }
  }

  belongs_to :company, model: :company, required: true

  scope :active_contacts, where: { active: true }

  timestamps true
  label_method :full_name
end
