LcpRuby.configure do |config|
  config.strict_loading = :development
  config.impersonation_roles = %w[admin]

  # DB-backed role management
  config.role_source = :model

  # Built-in authentication (Devise-based)
  config.authentication = :built_in
  config.auth_allow_registration = true
  config.auth_after_login_path = "/showcase/showcase-fields"
  config.auth_session_timeout = 30.minutes
  config.auth_lock_after_attempts = 5
end

Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
