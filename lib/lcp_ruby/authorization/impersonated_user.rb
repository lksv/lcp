require "delegate"

module LcpRuby
  class ImpersonatedUser < SimpleDelegator
    def initialize(real_user, impersonated_role)
      super(real_user)
      @impersonated_role = impersonated_role
    end

    # Override role method to return impersonated role.
    # Handles both the default :lcp_role and any custom role_method.
    def method_missing(method_name, *args, &block)
      if method_name == LcpRuby.configuration.role_method
        [@impersonated_role]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name == LcpRuby.configuration.role_method || super
    end
  end
end
