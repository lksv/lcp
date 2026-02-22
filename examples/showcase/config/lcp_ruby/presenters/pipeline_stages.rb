define_presenter :pipeline_stages do
  model :pipeline_stage
  label "Pipeline Stages"
  slug "pipeline-stages"
  icon "git-branch"

  index do
    description "Scoped positioning: stages are ordered within their pipeline. Each pipeline maintains independent position sequences."
    reorderable true
    per_page 25
    row_click :show

    column :name, link_to: :show
    column "pipeline.name", label: "Pipeline"
    column :color, renderer: :color_swatch
    column :position, sortable: false

    includes :pipeline
  end

  show do
    section "Stage Details", columns: 2 do
      field :name, renderer: :heading
      field "pipeline.name", label: "Pipeline"
      field :color, renderer: :color_swatch
      field :position, renderer: :number
    end

    includes :pipeline
  end

  form do
    section "Stage Details", columns: 2 do
      field :name, autofocus: true
      field :pipeline_id, input_type: :association_select,
        input_options: { sort: { name: :asc }, label_method: :name }
      field :color
    end
  end

  search do
    searchable_fields :name
    placeholder "Search stages..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Stage", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
