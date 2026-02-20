# frozen_string_literal: true

define_presenter :permission_configs do
  model :permission_config
  label "Permission Configs"
  slug "permission-configs"

  index do
    default_sort :target_model, :asc
    empty_message "No permission configs defined yet."

    column :target_model, label: "Target Model", sortable: true
    column :active, label: "Active", renderer: "boolean"
    column :updated_at, label: "Updated At", sortable: true
  end

  show do
    section "General", columns: 2 do
      field :target_model
      field :active
      field :notes, col_span: 2
    end

    section "Definition" do
      field :definition, renderer: :code, options: { language: "json" }
    end
  end

  form do
    layout :sections

    section "General", columns: 2 do
      field :target_model
      field :active
      field :notes, col_span: 2
    end

    section "Definition" do
      field :definition, input_type: "textarea"
    end
  end

  search do
    searchable_fields :target_model
  end

  action :create, type: :built_in, on: :collection, label: "New Permission Config"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: "Are you sure?"
end
