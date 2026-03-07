module LcpRuby
  module Widgets
    module ScopeApplicator
      private

      def resolve_model_class(model_name)
        LcpRuby.registry.model_for(model_name)
      rescue LcpRuby::Error => e
        Rails.logger.warn("[LcpRuby::Widgets] Model not found: #{model_name} — #{e.message}")
        nil
      end

      def build_evaluator(model_name)
        perm_def = LcpRuby.loader.permission_definition(model_name)
        Authorization::PermissionEvaluator.new(perm_def, @user, model_name)
      rescue LcpRuby::MetadataError => e
        Rails.logger.warn("[LcpRuby::Widgets] Permission definition not found: #{model_name} — #{e.message}")
        nil
      end

      def apply_policy_scope(model_class, evaluator)
        evaluator.apply_scope(model_class.all)
      end

      def apply_soft_delete_filter(scope, model_def)
        if model_def.soft_delete? && scope.respond_to?(:kept)
          scope.kept
        else
          scope
        end
      end

      def apply_zone_scope(scope, model_class)
        scope_name = @zone.scope
        if scope_name && model_class.respond_to?(scope_name)
          scope.send(scope_name)
        else
          scope
        end
      end
    end
  end
end
