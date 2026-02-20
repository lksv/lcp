module LcpRuby
  module Permissions
    module Setup
      # Boot-time setup for DB-backed permission source.
      # Called after models are built and roles are set up.
      #
      # @param loader [LcpRuby::Metadata::Loader] the metadata loader instance
      def self.apply!(loader)
        return unless LcpRuby.configuration.permission_source == :model

        perm_model_name = LcpRuby.configuration.permission_model

        # Verify the permission config model exists
        model_def = loader.model_definitions[perm_model_name]
        unless model_def
          raise MetadataError, "permission_source is :model but model '#{perm_model_name}' is not defined. " \
                               "Define it in your models YAML or run: rails generate lcp_ruby:permission_source"
        end

        # Validate the model meets the contract
        result = ContractValidator.validate(model_def)
        unless result.valid?
          raise MetadataError, "Permission config model '#{perm_model_name}' does not satisfy the contract:\n" \
                               "#{result.errors.map { |e| "  - #{e}" }.join("\n")}"
        end

        result.warnings.each do |warning|
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.warn("[LcpRuby::Permissions] #{warning}")
          end
        end

        # Mark registry as available and install callbacks
        Registry.mark_available!

        perm_model_class = LcpRuby.registry.model_for(perm_model_name)
        ChangeHandler.install!(perm_model_class)
        DefinitionValidator.install!(perm_model_class)
      end
    end
  end
end
