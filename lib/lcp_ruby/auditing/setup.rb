module LcpRuby
  module Auditing
    module Setup
      # Boot-time setup for auditing infrastructure.
      # Called after models are built and groups are set up.
      #
      # @param loader [LcpRuby::Metadata::Loader] the metadata loader instance
      def self.apply!(loader)
        # Only activate if at least one model has auditing: true
        any_audited = loader.model_definitions.values.any?(&:auditing?)
        return unless any_audited

        audit_model_name = LcpRuby.configuration.audit_model

        # Verify the audit model exists
        model_def = loader.model_definitions[audit_model_name]
        unless model_def
          message = "Model has auditing: true but audit model '#{audit_model_name}' is not defined. " \
                    "Run: rails generate lcp_ruby:auditing"

          # When running inside a generator, skip the hard error so the generator
          # can boot the app and create the missing files (chicken-and-egg).
          if LcpRuby.generator_context?
            Rails.logger.warn("[LcpRuby::Auditing] #{message}")
            return
          end

          raise MetadataError, message
        end

        # Validate the model meets the contract
        result = ContractValidator.validate(model_def)
        unless result.valid?
          raise MetadataError, "Audit model '#{audit_model_name}' does not satisfy the contract:\n" \
                               "#{result.errors.map { |e| "  - #{e}" }.join("\n")}"
        end

        result.warnings.each do |warning|
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.warn("[LcpRuby::Auditing] #{warning}")
          end
        end

        # Mark registry as available
        Registry.mark_available!
      end
    end
  end
end
