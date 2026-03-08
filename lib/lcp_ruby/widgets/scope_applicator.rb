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

      def apply_scope_context(scope, model_class)
        return scope if @scope_context.blank?

        @scope_context.each do |key, value|
          next if value.nil?

          filter_method = "filter_#{key}"
          if model_class.respond_to?(filter_method)
            method_obj = model_class.method(filter_method)
            if method_obj.arity == 3 || method_obj.parameters.size >= 3
              scope = model_class.public_send(filter_method, scope, value, nil)
            else
              scope = model_class.public_send(filter_method, scope, value)
            end
          elsif model_class.column_names.include?(key.to_s)
            scope = scope.where(key => value)
          else
            Rails.logger.warn("[LcpRuby::Widgets] scope_context key '#{key}' not found as column on #{model_class.name}")
          end
        end

        scope
      end
    end
  end
end
