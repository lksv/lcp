define_presenter :asset do
  model :asset
  label "Assets"
  slug "assets"
  icon "box"

  index do
    default_sort :name, :asc
    empty_message "No assets registered"

    column :photo, renderer: :attachment_preview, options: { variant: "small" }
    column :name, link_to: :show, sortable: true
    column :asset_tag, copyable: true
    column :category, renderer: :badge
    column :brand
    column :status, renderer: :badge, options: { color_map: { available: "green", assigned: "blue", in_repair: "yellow", retired: "red" } }
    column :purchase_price, renderer: :currency, options: { currency: "CZK" }
  end

  show do
    copy_url true

    section "Asset Details", columns: 2 do
      field :name, renderer: :heading
      field :asset_tag, copyable: true, hint: "Format: XXX-0000-0000"
      field :asset_uuid
      field :category, renderer: :badge
      field :brand
      field :product_model
      field :serial_number
      field :purchase_date, renderer: :date
      field :purchase_price, renderer: :currency, options: { currency: "CZK" }
      field :warranty_until, renderer: :date
      field :status, renderer: :status_timeline, options: { steps: %w[available assigned in_repair retired] }
      field :photo, renderer: :attachment_preview
      field :notes
    end

    association_list "Assignment History", association: :asset_assignments, sort: { assigned_at: :desc }
  end

  form do
    section "Asset Details", columns: 2 do
      field :name
      field :asset_tag, placeholder: "e.g. LAP-2024-0001", hint: "Format: XXX-0000-0000"
      field :category, input_type: :select
      field :brand
      field :product_model
      field :serial_number
      field :purchase_date, input_type: :date_picker
      field :purchase_price, input_type: :number, prefix: "CZK"
      field :warranty_until, input_type: :date_picker
      field :status, input_type: :select
      field :photo, input_options: { preview: true }
      field :notes, input_type: :textarea
    end
  end

  action :create, type: :built_in, on: :collection, label: "New Asset", icon: "plus"
  action :show, type: :built_in, on: :single, icon: "eye"
  action :edit, type: :built_in, on: :single, icon: "pencil"
  action :assign_asset, type: :custom, on: :single,
    label: "Assign",
    visible_when: { field: :status, operator: :eq, value: "available" }
  action :return_asset, type: :custom, on: :single,
    label: "Return",
    visible_when: { field: :status, operator: :eq, value: "assigned" }
  action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
end
