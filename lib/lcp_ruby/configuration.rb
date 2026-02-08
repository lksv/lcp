module LcpRuby
  class Configuration
    attr_accessor :metadata_path, :role_method, :user_class, :mount_path,
                  :auto_migrate, :label_method_default, :parent_controller

    def initialize
      @metadata_path = Rails.root.join("config", "lcp_ruby") if defined?(Rails)
      @role_method = :lcp_role
      @user_class = "User"
      @mount_path = "/admin"
      @auto_migrate = true
      @label_method_default = :to_s
      @parent_controller = "::ApplicationController"
    end
  end
end
