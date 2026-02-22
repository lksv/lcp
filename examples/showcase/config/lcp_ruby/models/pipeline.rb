define_model :pipeline do
  label "Pipeline"
  label_plural "Pipelines"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :description, :text, label: "Description"

  has_many :pipeline_stages, model: :pipeline_stage, dependent: :destroy

  timestamps true
  label_method :name
end
