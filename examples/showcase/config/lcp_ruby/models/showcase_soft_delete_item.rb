define_model :showcase_soft_delete_item do
  label "Soft Delete Item"
  label_plural "Soft Delete Items"

  field :name, :string, label: "Name", limit: 150, null: false, transforms: [:strip] do
    validates :presence
    validates :length, maximum: 150
  end
  field :notes, :text, label: "Notes"

  belongs_to :showcase_soft_delete, model: :showcase_soft_delete, required: true

  soft_delete

  timestamps true
  label_method :name
end
