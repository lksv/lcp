define_model :document do
  label "Document"
  label_plural "Documents"

  field :title, :string, null: false do
    validates :presence
  end

  field :category, :enum,
    values: {
      contract: "Contract",
      amendment: "Amendment",
      certificate: "Certificate",
      id_document: "ID Document",
      tax_form: "Tax Form",
      review: "Review",
      other: "Other"
    }

  field :description, :text

  field :file, :attachment, options: {
    multiple: true,
    max_files: 5,
    max_size: "25MB"
  }

  field :confidential, :boolean, default: false
  field :valid_from, :date
  field :valid_until, :date

  belongs_to :employee, model: :employee, required: true

  userstamps store_name: true

  timestamps true
end
