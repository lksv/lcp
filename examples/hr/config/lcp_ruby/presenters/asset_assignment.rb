define_presenter :asset_assignment do
  model :asset_assignment
  label "Asset Assignments"
  slug "asset-assignments"
  icon "link"

  index do
    column "asset.name"
    column "employee.full_name"
    column :assigned_at, renderer: :date
    column :returned_at, renderer: :date
    column :condition_on_assign, renderer: :badge
    column :condition_on_return, renderer: :badge,
      visible_when: { field: :returned_at, operator: :present }
  end

  show do
    section "Assignment Details", columns: 2 do
      field "asset.name"
      field "employee.full_name"
      field :assigned_at
      field :returned_at,
        visible_when: { field: :returned_at, operator: :present }
      field :condition_on_assign, renderer: :badge
      field :condition_on_return, renderer: :badge,
        visible_when: { field: :returned_at, operator: :present }
      field :notes
    end
  end

  form do
    section "Assignment Details", columns: 2 do
      field :asset_id, input_type: :association_select
      field :employee_id, input_type: :association_select
      field :assigned_at, input_type: :date_picker
      field :returned_at, input_type: :date_picker
      field :condition_on_assign, input_type: :select
      field :condition_on_return, input_type: :select,
        visible_when: { field: :returned_at, operator: :present }
      field :notes, input_type: :textarea
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Assignment", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
end
