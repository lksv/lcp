define_presenter :document do
  model :document
  label "Documents"
  slug "documents"
  icon "file-text"

  index do
    column :title, link_to: :show
    column "employee.full_name"
    column :category, renderer: :badge
    column :confidential, renderer: :boolean_icon
    column :valid_from, renderer: :date
    column :valid_until, renderer: :date
  end

  show do
    section "Document Details", columns: 2 do
      field :title, renderer: :heading
      field "employee.full_name"
      field :category, renderer: :badge
      field :description
      field :confidential, renderer: :boolean_icon
      field :valid_from
      field :valid_until
      field :file, renderer: :attachment_list
    end
  end

  form do
    section "Document Details", columns: 2 do
      field :employee_id, input_type: :association_select
      field :title, autofocus: true
      field :category, input_type: :select
      field :description, input_type: :textarea
      field :file, input_options: { preview: true, drag_drop: true }
      field :confidential, input_type: :checkbox
      field :valid_from, input_type: :date_picker
      field :valid_until, input_type: :date_picker
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Document", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true
end
