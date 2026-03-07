module LcpRuby
  module Presenter
    class ActionSet
      # Action names (including aliases) whose record rules should hide the button.
      # "edit" maps to "update" via alias; "show" is intentionally excluded.
      RECORD_RULE_ACTION_NAMES = %w[edit update destroy restore permanently_destroy].freeze

      attr_reader :presenter_definition, :permission_evaluator

      def initialize(presenter_definition, permission_evaluator, context: {})
        @presenter_definition = presenter_definition
        @permission_evaluator = permission_evaluator
        @context = context
      end

      def collection_actions
        filter_actions(presenter_definition.collection_actions)
      end

      def single_actions(record = nil)
        actions = filter_actions(presenter_definition.single_actions)
        actions = actions.map { |a| resolve_confirm(a) }
        return actions unless record

        actions
          .select { |a| action_permitted_for_record?(a, record) }
          .select { |a| action_visible_for_record?(a, record) }
          .map { |a| a.merge("_disabled" => action_disabled_for_record?(a, record)) }
      end

      def batch_actions
        filter_actions(presenter_definition.batch_actions)
      end

      private

      def filter_actions(actions)
        actions.select do |action|
          case action["type"]
          when "built_in"
            permission_evaluator.can?(action["name"])
          when "dialog"
            authorize_dialog_action(action)
          else
            permission_evaluator.can_execute_action?(action["name"])
          end
        end
      end

      def resolve_confirm(action)
        confirm = action["confirm"]
        resolved = case confirm
        when true, false, nil
          confirm
        when Hash
          normalized = confirm.transform_keys(&:to_s)
          user_roles = permission_evaluator.roles
          if normalized.key?("except")
            except_roles = Array(normalized["except"]).map(&:to_s)
            (user_roles & except_roles).empty?
          elsif normalized.key?("only")
            only_roles = Array(normalized["only"]).map(&:to_s)
            (user_roles & only_roles).any?
          elsif normalized.key?("title_key") || normalized.key?("message_key") || normalized.key?("style")
            # Styled confirmation modal — pass through as hash
            normalized
          elsif normalized.key?("page")
            # Full presenter-driven confirmation dialog — pass through as hash
            normalized
          else
            !!confirm
          end
        else
          !!confirm
        end

        action.merge("confirm" => resolved)
      end

      def authorize_dialog_action(action)
        dialog = action["dialog"]
        return false unless dialog

        page_name = dialog["page"]
        return false unless page_name

        @dialog_auth_cache ||= {}
        return @dialog_auth_cache[page_name] if @dialog_auth_cache.key?(page_name)

        @dialog_auth_cache[page_name] = begin
          page = Pages::Resolver.find_by_name(page_name)
          presenter_name = page.main_presenter_name
          presenter = LcpRuby.loader.presenter_definition(presenter_name)
          model_name = presenter.model

          perm_def = LcpRuby.loader.permission_definition(model_name)
          dialog_evaluator = Authorization::PermissionEvaluator.new(perm_def, permission_evaluator.user, model_name)
          dialog_evaluator.can_access_presenter?(presenter_name)
        rescue MetadataError => e
          raise unless Rails.env.production?
          Rails.logger.error("[LcpRuby] Dialog action auth failed for page '#{page_name}': #{e.message}")
          false
        end
      end

      def action_permitted_for_record?(action, record)
        return true unless action["type"] == "built_in"
        return true unless RECORD_RULE_ACTION_NAMES.include?(action["name"].to_s)

        permission_evaluator.can_for_record?(action["name"], record)
      end

      def action_visible_for_record?(action, record)
        visible_when = action["visible_when"]
        return true unless visible_when

        ConditionEvaluator.evaluate_any(record, visible_when, context: @context)
      end

      def action_disabled_for_record?(action, record)
        disable_when = action["disable_when"]
        return false unless disable_when

        ConditionEvaluator.evaluate_any(record, disable_when, context: @context)
      end
    end
  end
end
