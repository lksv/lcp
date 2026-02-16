module LcpRuby
  module Actions
    class ActionExecutor
      attr_reader :action_key, :context

      def initialize(action_key, context = {})
        @action_key = action_key.to_s
        @context = context
      end

      def execute
        action_class = ActionRegistry.action_for(action_key)
        raise Error, "Action '#{action_key}' not found" unless action_class

        record = context[:record]
        user = context[:current_user]

        unless action_class.authorized?(record, user)
          return Actions::Result.new(
            success: false,
            message: "Not authorized to execute this action",
            redirect_to: nil,
            data: nil,
            errors: [ "unauthorized" ]
          )
        end

        action = action_class.new(context)
        action.call
      rescue StandardError => e
        Actions::Result.new(
          success: false,
          message: "Action failed: #{e.message}",
          redirect_to: nil,
          data: nil,
          errors: [ e.message ]
        )
      end
    end
  end
end
