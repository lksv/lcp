module LcpRuby
  module SavedFilters
    class ChangeHandler
      # Installs after_commit callbacks on the saved filter model to invalidate caches.
      # @param model_class [Class] the saved filter AR model
      def self.install!(model_class)
        model_class.after_commit do |_record|
          Resolver.clear_cache!
        end
      end
    end
  end
end
