module LcpRuby
  module SavedFilters
    module Registry
      class << self
        # Whether saved filters infrastructure is ready (model exists and validated).
        def available?
          @available == true
        end

        # Mark registry as available (called after contract validation passes).
        def mark_available!
          @available = true
        end

        # Returns the saved filter model name from the registry.
        # @return [String, nil]
        def model_name
          return nil unless available?
          "saved_filter"
        end

        # Returns the saved filter model class from the registry.
        # @return [Class, nil]
        def model_class
          return nil unless available?
          LcpRuby.registry.model_for("saved_filter")
        end

        # Full reset — called from LcpRuby.reset!
        def clear!
          @available = false
        end
      end
    end
  end
end
