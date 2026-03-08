define_presenter :pipeline_stages_zone do
  model :pipeline_stage
  label "Stages"

  index do
    per_page 20
    column :name
    column :color, renderer: :color_swatch
    column :position, renderer: :number
  end
end
