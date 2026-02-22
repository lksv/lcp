define_presenter :pipelines do
  model :pipeline
  label "Pipelines"
  slug "pipelines"
  icon "layers"

  index do
    description "Parent model for scoped positioning. Each pipeline has its own set of stages with independent ordering."
    per_page 25
    row_click :show

    column :name, link_to: :show
    column :description, renderer: :truncate, options: { max: 80 }
  end

  show do
    section "Pipeline Details", columns: 2 do
      field :name, renderer: :heading
      field :description
    end
  end

  form do
    section "Pipeline Details", columns: 2 do
      field :name, autofocus: true
      field :description, input_type: :textarea, input_options: { rows: 3 }
    end
  end

  search do
    searchable_fields :name, :description
    placeholder "Search pipelines..."
    filter :all, label: "All", default: true
  end

  action :create, type: :built_in, on: :collection, label: "New Pipeline", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
