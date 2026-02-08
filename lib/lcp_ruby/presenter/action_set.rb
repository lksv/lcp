module LcpRuby
  module Presenter
    class ActionSet
      attr_reader :presenter_definition, :permission_evaluator

      def initialize(presenter_definition, permission_evaluator)
        @presenter_definition = presenter_definition
        @permission_evaluator = permission_evaluator
      end

      def collection_actions
        filter_actions(presenter_definition.collection_actions)
      end

      def single_actions(record = nil)
        actions = filter_actions(presenter_definition.single_actions)
        return actions unless record

        actions.select { |a| action_visible_for_record?(a, record) }
      end

      def batch_actions
        filter_actions(presenter_definition.batch_actions)
      end

      private

      def filter_actions(actions)
        actions.select do |action|
          action = action.transform_keys(&:to_s) if action.is_a?(Hash)
          action_name = action["name"]

          if action["type"] == "built_in"
            permission_evaluator.can?(action_name)
          else
            permission_evaluator.can_execute_action?(action_name)
          end
        end
      end

      def action_visible_for_record?(action, record)
        action = action.transform_keys(&:to_s) if action.is_a?(Hash)
        visible_when = action["visible_when"]
        return true unless visible_when

        ConditionEvaluator.evaluate(record, visible_when)
      end
    end
  end
end
