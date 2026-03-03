LcpRuby.configure do |config|
  config.strict_loading = :development
  config.breadcrumb_home_path = "/hr"
  config.menu_mode = :strict
  config.impersonation_roles = %w[admin hr_manager]
  config.group_source = :model
  config.group_membership_fields = { group: "group_id", user: "employee_id" }
end

Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
  LcpRuby::ConditionServiceRegistry.discover!(app_path.to_s)
  LcpRuby::Display::RendererRegistry.discover!(app_path.to_s)
  LcpRuby::Services::Registry.discover!(app_path.to_s)
end
