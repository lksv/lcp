module LcpRuby
  module SavedFilters
    module Setup
      # Boot-time setup for saved filters infrastructure.
      # Called after models are built and auditing is set up.
      #
      # @param loader [LcpRuby::Metadata::Loader] the metadata loader instance
      def self.apply!(loader)
        # Saved filters are opt-in: only activate if the model is defined
        model_def = loader.model_definitions["saved_filter"]
        return unless model_def

        # Validate the model meets the contract
        result = ContractValidator.validate(model_def)
        unless result.valid?
          message = "Saved filter model 'saved_filter' does not satisfy the contract:\n" \
                    "#{result.errors.map { |e| "  - #{e}" }.join("\n")}"

          if LcpRuby.generator_context?
            Rails.logger.warn("[LcpRuby::SavedFilters] #{message}")
            return
          end

          raise MetadataError, message
        end

        result.warnings.each do |warning|
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.warn("[LcpRuby::SavedFilters] #{warning}")
          end
        end

        # Install change handler for cache invalidation
        model_class = LcpRuby.registry.model_for("saved_filter")
        ChangeHandler.install!(model_class) if model_class

        # Mark registry as available
        Registry.mark_available!
      end
    end
  end
end
