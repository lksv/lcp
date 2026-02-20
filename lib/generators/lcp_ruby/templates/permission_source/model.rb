# frozen_string_literal: true

define_model :permission_config do
  table_name "permission_configs"
  label "Permission Config"
  label_plural "Permission Configs"
  timestamps true
  label_method :target_model

  field :target_model, :string do
    validates :presence
    validates :uniqueness
  end

  field :definition, :json do
    validates :presence
  end

  field :active, :boolean, default: true
  field :notes, :text
end
