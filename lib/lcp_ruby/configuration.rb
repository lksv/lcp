module LcpRuby
  class Configuration
    attr_accessor :metadata_path, :role_method, :user_class, :mount_path,
                  :auto_migrate, :label_method_default, :parent_controller,
                  :strict_loading, :impersonation_roles,
                  :attachment_max_size, :attachment_allowed_content_types,
                  :breadcrumb_home_path

    # Authentication settings
    attr_accessor :auth_allow_registration,
                  :auth_password_min_length,
                  :auth_session_timeout,
                  :auth_lock_after_attempts,
                  :auth_lock_duration,
                  :auth_mailer_sender,
                  :auth_after_login_path,
                  :auth_after_logout_path

    attr_reader :menu_mode, :authentication

    def menu_mode=(value)
      @menu_mode = value&.to_sym
    end

    def authentication=(value)
      value = value&.to_sym
      unless %i[none built_in external].include?(value)
        raise ArgumentError, "authentication must be :none, :built_in, or :external (got #{value.inspect})"
      end
      @authentication = value
    end

    def initialize
      @metadata_path = Rails.root.join("config", "lcp_ruby") if defined?(Rails)
      @role_method = :lcp_role
      @user_class = "User"
      @mount_path = "/"
      @auto_migrate = true
      @label_method_default = :to_s
      @parent_controller = "::ApplicationController"
      @strict_loading = :never
      @impersonation_roles = []
      @attachment_max_size = "50MB"
      @attachment_allowed_content_types = nil
      @breadcrumb_home_path = "/"
      @menu_mode = :auto

      # Authentication defaults
      @authentication = :external
      @auth_allow_registration = false
      @auth_password_min_length = 8
      @auth_session_timeout = nil
      @auth_lock_after_attempts = 0
      @auth_lock_duration = 30.minutes if defined?(ActiveSupport)
      @auth_mailer_sender = "noreply@example.com"
      @auth_after_login_path = "/"
      @auth_after_logout_path = nil
    end

    # Returns true when strict_loading should be enabled on AR scopes.
    # Raises ActiveRecord::StrictLoadingViolationError on lazy association access.
    #
    # Options:
    #   :always      — enabled in all environments
    #   :development — enabled in development and test environments
    #   :never       — disabled (default)
    def strict_loading_enabled?
      case strict_loading
      when :always then true
      when :development then defined?(Rails) && (Rails.env.development? || Rails.env.test?)
      else false
      end
    end
  end
end
