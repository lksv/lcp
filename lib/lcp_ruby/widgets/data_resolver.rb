module LcpRuby
  module Widgets
    class DataResolver
      def initialize(zone, user:)
        @zone = zone
        @user = user
      end

      def resolve
        widget = @zone.widget
        return { hidden: true } unless widget

        case widget["type"]
        when "kpi_card" then resolve_kpi_card(widget)
        when "text"     then resolve_text(widget)
        when "list"     then resolve_list(widget)
        else { hidden: true }
        end
      end

      private

      def resolve_kpi_card(widget)
        model_name = widget["model"]
        return { hidden: true } unless model_name

        model_class = resolve_model_class(model_name)
        return { hidden: true } unless model_class

        evaluator = build_evaluator(model_name)
        return { hidden: true } unless evaluator&.can?(:index)

        scope = apply_policy_scope(model_class, evaluator)
        scope = apply_soft_delete_filter(scope, model_name)
        scope = apply_zone_scope(scope, model_class)

        aggregate = widget["aggregate"]&.to_sym
        aggregate_field = widget["aggregate_field"]

        value = compute_aggregate(scope, aggregate, aggregate_field)

        {
          value: value,
          label: widget_label(widget),
          icon: widget["icon"],
          link_to: widget["link_to"],
          format: widget["format"]
        }
      end

      def resolve_text(widget)
        content_key = widget["content_key"]
        {
          content: I18n.t(content_key, default: content_key)
        }
      end

      def resolve_list(widget)
        model_name = widget["model"]
        return { hidden: true } unless model_name

        model_class = resolve_model_class(model_name)
        return { hidden: true } unless model_class

        evaluator = build_evaluator(model_name)
        return { hidden: true } unless evaluator&.can?(:index)

        scope = apply_policy_scope(model_class, evaluator)
        scope = apply_soft_delete_filter(scope, model_name)
        scope = apply_zone_scope(scope, model_class)

        limit = @zone.limit || 5
        records = scope.limit(limit).to_a

        {
          records: records,
          model_name: model_name,
          link_to: widget["link_to"]
        }
      end

      def resolve_model_class(model_name)
        LcpRuby.registry.model_for(model_name)
      rescue LcpRuby::Error
        nil
      end

      def build_evaluator(model_name)
        perm_def = LcpRuby.loader.permission_definition(model_name)
        Authorization::PermissionEvaluator.new(perm_def, @user, model_name)
      rescue LcpRuby::MetadataError
        nil
      end

      def apply_policy_scope(model_class, evaluator)
        evaluator.apply_scope(model_class.all)
      end

      def apply_soft_delete_filter(scope, model_name)
        model_def = LcpRuby.loader.model_definition(model_name)
        if model_def.soft_delete? && scope.respond_to?(:kept)
          scope.kept
        else
          scope
        end
      rescue LcpRuby::MetadataError
        scope
      end

      def apply_zone_scope(scope, model_class)
        scope_name = @zone.scope
        if scope_name && model_class.respond_to?(scope_name)
          scope.send(scope_name)
        else
          scope
        end
      end

      def compute_aggregate(scope, aggregate, field)
        case aggregate
        when :count then scope.count
        when :sum   then scope.sum(field || :id)
        when :avg   then scope.average(field || :id)&.to_f
        when :min   then scope.minimum(field || :id)
        when :max   then scope.maximum(field || :id)
        else scope.count
        end
      end

      def widget_label(widget)
        label_key = widget["label_key"]
        if label_key
          I18n.t(label_key, default: label_key.split(".").last.humanize)
        else
          @zone.name.humanize
        end
      end
    end
  end
end
