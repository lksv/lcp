define_model :pipeline_stage do
  label "Pipeline Stage"
  label_plural "Pipeline Stages"

  field :name, :string, label: "Name", limit: 100, null: false do
    validates :presence
  end
  field :position, :integer, label: "Position"
  field :color, :color, label: "Color"
  field :pipeline_id, :integer, label: "Pipeline"

  belongs_to :pipeline, model: :pipeline

  positioning scope: :pipeline_id

  timestamps true
  label_method :name
end
