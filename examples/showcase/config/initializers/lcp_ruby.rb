LcpRuby.configure do |config|
  config.strict_loading = :development
  config.impersonation_roles = %w[admin]

  # DB-backed role management
  config.role_source = :model

  # DB-backed permission management
  config.permission_source = :model

  # Built-in authentication (Devise-based)
  config.authentication = :built_in
  config.auth_allow_registration = true
  config.auth_after_login_path = "/showcase/showcase-fields"
  config.auth_session_timeout = 30.minutes
  config.auth_lock_after_attempts = 5

  # Virtual field implementations for showcase_virtual_field
  config.on_model_ready("showcase_virtual_field") do |klass|
    # full_location: concatenates city + country
    klass.define_method(:full_location) do
      parts = [ city, country ].compact_blank
      parts.any? ? parts.join(", ") : nil
    end
    klass.define_method(:full_location=) { |_value| } # read-only, no-op setter

    # priority_label: maps priority integer to human label
    klass.define_method(:priority_label) do
      val = priority.to_i
      { 1 => "Lowest", 2 => "Low", 3 => "Medium", 4 => "High", 5 => "Critical" }[val] if val > 0
    end
    klass.define_method(:priority_label=) { |_value| } # read-only, no-op setter
  end
end

Rails.application.config.after_initialize do
  app_path = Rails.root.join("app")
  LcpRuby::Actions::ActionRegistry.discover!(app_path.to_s)
  LcpRuby::Events::HandlerRegistry.discover!(app_path.to_s)
end
