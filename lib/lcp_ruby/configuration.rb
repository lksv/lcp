module LcpRuby
  class Configuration
    attr_accessor :metadata_path, :role_method, :user_class, :mount_path,
                  :auto_migrate, :label_method_default, :parent_controller,
                  :strict_loading, :impersonation_roles,
                  :attachment_max_size, :attachment_allowed_content_types,
                  :breadcrumb_home_path

    attr_reader :menu_mode

    def menu_mode=(value)
      @menu_mode = value&.to_sym
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
