module LcpRuby
  module Auditing
    module Registry
      class << self
        # Whether auditing infrastructure is ready (audit model exists and validated).
        def available?
          @available == true
        end

        # Mark registry as available (called after contract validation passes).
        def mark_available!
          @available = true
        end

        # Full reset — called from LcpRuby.reset!
        def clear!
          @available = false
        end

        # Returns the audit model class from the registry.
        # @return [Class, nil] the ActiveRecord model class for audit logs
        def audit_model_class
          return nil unless available?
          LcpRuby.registry.model_for(LcpRuby.configuration.audit_model)
        end
      end
    end
  end
end
