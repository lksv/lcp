define_presenter :leave_type do
  model :leave_type
  label "Leave Types"
  slug "leave-types"
  icon "calendar"

  index do
    reorderable true

    column :name, width: "20%", link_to: :show, sortable: true
    column :code, width: "15%", sortable: true
    column :color, width: "10%", renderer: :color_swatch
    column :default_days, width: "10%"
    column :requires_approval, width: "15%", renderer: :boolean_icon
    column :requires_document, width: "15%", renderer: :boolean_icon
    column :active, width: "10%", renderer: :boolean_icon
  end

  show do
    section "Leave Type Details", columns: 2 do
      field :name, renderer: :heading
      field :code
      field :color, renderer: :color_swatch
      field :default_days
      field :requires_approval, renderer: :boolean_icon
      field :requires_document, renderer: :boolean_icon
      field :active, renderer: :boolean_icon
    end
  end

  form do
    section "Leave Type Details", columns: 2 do
      field :name, autofocus: true
      field :code
      field :color, input_type: :color
      field :default_days, input_type: :number
      field :requires_approval, input_type: :toggle
      field :requires_document, input_type: :toggle
      field :active, input_type: :toggle
    end
  end

  search do
    searchable_fields :name, :code
    placeholder "Search leave types..."
  end

  action :create, type: :built_in, on: :collection, label: "New Leave Type", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
