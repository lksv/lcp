require "delegate"

module LcpRuby
  class ImpersonatedUser < SimpleDelegator
    def initialize(real_user, impersonated_role)
      super(real_user)
      @impersonated_role = impersonated_role
    end

    # Override role method to return impersonated role.
    # Override group method to return [] — impersonation suppresses group-derived roles.
    # Handles both the default methods and any custom role_method/group_method.
    def method_missing(method_name, *args, &block)
      if method_name == LcpRuby.configuration.role_method
        [ @impersonated_role ]
      elsif method_name == LcpRuby.configuration.group_method
        []
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name == LcpRuby.configuration.role_method ||
        method_name == LcpRuby.configuration.group_method ||
        super
    end
  end
end
