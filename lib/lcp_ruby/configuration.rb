module LcpRuby
  class Configuration
    attr_accessor :metadata_path, :role_method, :user_class, :mount_path,
                  :auto_migrate, :label_method_default, :parent_controller,
                  :strict_loading, :impersonation_roles,
                  :attachment_max_size, :attachment_allowed_content_types,
                  :breadcrumb_home_path, :not_found_handler, :empty_value

    # Authentication settings
    attr_accessor :auth_allow_registration,
                  :auth_password_min_length,
                  :auth_session_timeout,
                  :auth_lock_after_attempts,
                  :auth_lock_duration,
                  :auth_mailer_sender,
                  :auth_after_login_path,
                  :auth_after_logout_path

    attr_reader :menu_mode, :authentication, :role_source, :permission_source,
                :group_source, :role_resolution_strategy, :model_extensions
    attr_accessor :role_model, :role_model_fields,
                  :permission_model, :permission_model_fields,
                  :group_method, :group_model, :group_model_fields,
                  :group_membership_model, :group_membership_fields,
                  :group_role_mapping_model, :group_role_mapping_fields,
                  :group_adapter

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

    def role_source=(value)
      value = value&.to_sym
      unless %i[implicit model].include?(value)
        raise ArgumentError, "role_source must be :implicit or :model (got #{value.inspect})"
      end
      @role_source = value
    end

    def permission_source=(value)
      value = value&.to_sym
      unless %i[yaml model].include?(value)
        raise ArgumentError, "permission_source must be :yaml or :model (got #{value.inspect})"
      end
      @permission_source = value
    end

    def group_source=(value)
      value = value&.to_sym
      unless %i[none yaml model host].include?(value)
        raise ArgumentError, "group_source must be :none, :yaml, :model, or :host (got #{value.inspect})"
      end
      @group_source = value
    end

    def role_resolution_strategy=(value)
      value = value&.to_sym
      unless %i[merged groups_only direct_only].include?(value)
        raise ArgumentError, "role_resolution_strategy must be :merged, :groups_only, or :direct_only (got #{value.inspect})"
      end
      @role_resolution_strategy = value
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
      @not_found_handler = :default
      @menu_mode = :auto
      @model_extensions = {}

      # Role source defaults
      @role_source = :implicit
      @role_model = "role"
      @role_model_fields = { name: "name", active: "active" }

      # Permission source defaults
      @permission_source = :yaml
      @permission_model = "permission_config"
      @permission_model_fields = { target_model: "target_model", definition: "definition", active: "active" }

      # Group source defaults
      @group_source = :none
      @group_method = :lcp_groups
      @group_model = "group"
      @group_model_fields = { name: "name", active: "active" }
      @group_membership_model = "group_membership"
      @group_membership_fields = { group: "group_id", user: "user_id" }
      @group_role_mapping_model = nil
      @group_role_mapping_fields = { group: "group_id", role: "role_name" }
      @group_adapter = nil
      @role_resolution_strategy = :merged

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

    def on_model_ready(model_name, &block)
      (@model_extensions[model_name.to_s] ||= []) << block
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
