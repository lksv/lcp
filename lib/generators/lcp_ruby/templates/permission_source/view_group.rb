# frozen_string_literal: true

define_view_group :permission_configs do
  model :permission_config
  primary :permission_configs

  navigation menu: "main", position: 95

  view :permission_configs, label: "Permission Configs"
end
