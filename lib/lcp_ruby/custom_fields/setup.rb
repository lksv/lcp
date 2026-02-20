module LcpRuby
  module CustomFields
    module Setup
      # Shared setup logic called after the custom_field_definition model is built and registered.
      # Used by both Engine.load_metadata! and IntegrationHelper.load_integration_metadata!.
      #
      # @param loader [LcpRuby::Metadata::Loader] the metadata loader instance
      def self.apply!(loader)
        Registry.mark_available!

        # Install cache invalidation on custom_field_definition model
        cfd_class = LcpRuby.registry.model_for("custom_field_definition")
        DefinitionChangeHandler.install!(cfd_class)

        # Apply custom field accessors and scopes for enabled models
        loader.model_definitions.each_value do |model_def|
          next unless model_def.custom_fields_enabled?

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
