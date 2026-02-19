LcpRuby.configure do |config|
  config.strict_loading = :development
  config.breadcrumb_home_path = "/crm"
end

Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
