# frozen_string_literal: true

define_presenter :permission_configs do
  model :permission_config
  label "Permission Configs"
  slug "permission-configs"
  icon "key"

  index do
    description "DB-backed permission definitions. Each record overrides the YAML permission file for its target model."
    default_sort :target_model, :asc
    per_page 25

    column :target_model, label: "Target Model", link_to: :show, sortable: true
    column :active, label: "Active", renderer: :boolean_icon
    column :notes, label: "Notes", renderer: :truncate, options: { max: 60 }
    column :updated_at, label: "Updated", sortable: true
  end

  show do
    description "DB-stored permission definition. Changes take effect immediately after save."

    section "General", columns: 2 do
      field :target_model, renderer: :heading
      field :active, renderer: :boolean_icon
      field :notes, col_span: 2
    end

    section "Permission Definition" do
      field :definition, renderer: :code, options: { language: "json" }
    end
  end

  form do
    layout :sections

    section "General", columns: 2 do
      field :target_model, placeholder: "e.g. project, task, _default"
      field :active, input_type: :toggle
      field :notes, col_span: 2, input_type: :textarea, input_options: { rows: 2 }
    end

    section "Permission Definition" do
      field :definition, input_type: :textarea, input_options: { rows: 20 },
        hint: "JSON with roles, default_role, field_overrides, record_rules. See docs for schema."
    end
  end

  search do
    searchable_fields :target_model, :notes
    placeholder "Search permission configs..."
  end

  action :create, type: :built_in, on: :collection, label: "New Permission Config", icon: "plus"
  action :show, type: :built_in, on: :single
  action :edit, type: :built_in, on: :single
  action :destroy, type: :built_in, on: :single, confirm: true, style: :danger
end
