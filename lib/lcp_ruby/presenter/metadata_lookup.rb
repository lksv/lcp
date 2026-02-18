module LcpRuby
  module Presenter
    # Shared helpers for resolving metadata and building permission evaluators
    # across the dot-path association chain.
    #
    # Including class must provide:
    #   - #permission_evaluator  → root PermissionEvaluator
    #   - #root_model_name       → String (name of the root model)
    module MetadataLookup
      private

      def build_evaluator_for(model_name)
        return permission_evaluator if model_name.to_s == root_model_name

        perm_def = LcpRuby.loader.permission_definition(model_name)
        Authorization::PermissionEvaluator.new(perm_def, permission_evaluator.user, model_name)
      rescue MetadataError
        permission_evaluator
      end

      def load_model_definition(model_name)
        LcpRuby.loader.model_definition(model_name)
      rescue MetadataError
        nil
      end
    end
  end
end
