module LcpRuby
  module Roles
    module Setup
      # Boot-time setup for DB-backed role source.
      # Called after models are built and custom fields are set up.
      #
      # @param loader [LcpRuby::Metadata::Loader] the metadata loader instance
      def self.apply!(loader)
        return unless LcpRuby.configuration.role_source == :model

        role_model_name = LcpRuby.configuration.role_model

        # Verify the role model exists
        model_def = loader.model_definitions[role_model_name]
        unless model_def
          raise MetadataError, "role_source is :model but model '#{role_model_name}' is not defined. " \
                               "Define it in your models YAML or run: rails generate lcp_ruby:role_model"
        end

        # Validate the model meets the contract
        result = ContractValidator.validate(model_def)
        unless result.valid?
          raise MetadataError, "Role model '#{role_model_name}' does not satisfy the contract:\n" \
                               "#{result.errors.map { |e| "  - #{e}" }.join("\n")}"
        end

        result.warnings.each do |warning|
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.warn("[LcpRuby::Roles] #{warning}")
          end
        end

        # Mark registry as available and install cache invalidation
        Registry.mark_available!

        role_model_class = LcpRuby.registry.model_for(role_model_name)
        ChangeHandler.install!(role_model_class)
      end
    end
  end
end
