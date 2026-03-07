module LcpRuby
  module Widgets
    class PresenterZoneResolver
      def initialize(zone, user:)
        @zone = zone
        @user = user
      end

      def resolve
        presenter_name = @zone.presenter
        return { hidden: true } unless presenter_name

        presenter = LcpRuby.loader.presenter_definitions[presenter_name]
        return { hidden: true } unless presenter

        model_name = presenter.model
        model_class = LcpRuby.registry.model_for(model_name)
        return { hidden: true } unless model_class

        model_def = LcpRuby.loader.model_definition(model_name)
        evaluator = build_evaluator(model_name)
        return { hidden: true } unless evaluator&.can?(:index)
        return { hidden: true } unless evaluator.can_access_presenter?(presenter_name)

        scope = apply_policy_scope(model_class, evaluator)
        scope = apply_soft_delete_filter(scope, model_def)
        scope = apply_zone_scope(scope, model_class)
        scope = apply_eager_loading(scope, presenter, model_def)

        limit = @zone.limit || 10
        records = scope.limit(limit).to_a

        column_set = Presenter::ColumnSet.new(presenter, evaluator)
        action_set = Presenter::ActionSet.new(presenter, evaluator)

        {
          records: records,
          presenter: presenter,
          model_definition: model_def,
          column_set: column_set,
          action_set: action_set,
          evaluator: evaluator,
          field_value_resolver: Presenter::FieldValueResolver.new(model_def, evaluator)
        }
      end

      private

      def build_evaluator(model_name)
        perm_def = LcpRuby.loader.permission_definition(model_name)
        Authorization::PermissionEvaluator.new(perm_def, @user, model_name)
      rescue LcpRuby::MetadataError
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

      def apply_eager_loading(scope, presenter, model_def)
        strategy = Presenter::IncludesResolver.resolve(
          presenter_def: presenter,
          model_def: model_def,
          context: :index
        )
        strategy.apply(scope)
      end
    end
  end
end
