module LcpRuby
  module CustomFields
    module Setup
      # Shared setup logic called after models are built and registered.
      # Used by both Engine.load_metadata! and IntegrationHelper.load_integration_metadata!.
      #
      # @param loader [LcpRuby::Metadata::Loader] the metadata loader instance
      def self.apply!(loader)
        # Check if any model uses custom fields
        cf_models = loader.model_definitions.values.select(&:custom_fields_enabled?)
        return if cf_models.empty?

        # Validate that custom_field_definition model exists
        unless loader.model_definitions.key?("custom_field_definition")
          message = "One or more models have custom_fields enabled (#{cf_models.map(&:name).join(', ')}), " \
            "but the 'custom_field_definition' model is not defined. " \
            "Run `rails generate lcp_ruby:custom_fields` to generate the required metadata files."

          # When running inside a generator, skip the hard error so the generator
          # can boot the app and create the missing files (chicken-and-egg).
          if LcpRuby.generator_context?
            Rails.logger.warn("[LcpRuby::CustomFields] #{message}")
            return
          end

          raise MetadataError, message
        end

        # Validate the custom_field_definition model contract
        cfd_def = loader.model_definitions["custom_field_definition"]
        result = ContractValidator.validate(cfd_def)
        unless result.valid?
          raise MetadataError,
            "Custom field definition model contract validation failed:\n  #{result.errors.join("\n  ")}"
        end
        result.warnings.each do |warning|
          Rails.logger.warn("[LcpRuby::CustomFields] #{warning}")
        end

        Registry.mark_available!

        # Install cache invalidation on custom_field_definition model
        cfd_class = LcpRuby.registry.model_for("custom_field_definition")
        DefinitionChangeHandler.install!(cfd_class)

        # Apply custom field accessors and scopes for enabled models
        cf_models.each do |model_def|
          model_class = LcpRuby.registry.model_for(model_def.name)
          model_class.apply_custom_field_accessors!

          # Add a scope on custom_field_definition for this target model
          target = model_def.name
          cfd_class.scope("for_#{target}", -> { where(target_model: target) })
        end
      end
    end
  end
end
