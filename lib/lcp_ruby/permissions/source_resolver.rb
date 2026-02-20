module LcpRuby
  module Permissions
    class SourceResolver
      # Resolves a PermissionDefinition for the given model name.
      #
      # In :yaml mode, delegates directly to the loader's YAML-based lookup.
      #
      # In :model mode, uses first-found-wins resolution (no merging):
      #   1. DB record for this specific model
      #   2. DB record for "_default"
      #   3. YAML fallback for this specific model
      #
      # @param model_name [String] the model name
      # @param loader [Metadata::Loader] the metadata loader
      # @return [Metadata::PermissionDefinition, nil]
      def self.for(model_name, loader)
        if LcpRuby.configuration.permission_source == :model && Registry.available?
          # Try DB for this specific model
          perm_def = Registry.for_model(model_name)
          return perm_def if perm_def

          # Try DB _default
          perm_def = Registry.for_model("_default")
          return perm_def if perm_def
        end

        # YAML fallback (also used when permission_source is :yaml)
        loader.yaml_permission_definition(model_name)
      end
    end
  end
end
