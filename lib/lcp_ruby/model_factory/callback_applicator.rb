module LcpRuby
  module ModelFactory
    class CallbackApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.events.each do |event|
          apply_event(event)
        end
      end

      private

      def apply_event(event)
        if event.lifecycle?
          apply_lifecycle_event(event)
        elsif event.field_change?
          apply_field_change_event(event)
        end
      end

      def apply_lifecycle_event(event)
        callback_name = event.name.to_sym
        event_name = event.name

        @model_class.send(callback_name) do |record|
          LcpRuby::Events::Dispatcher.dispatch(
            event_name: event_name,
            record: record,
            changes: record.respond_to?(:saved_changes) ? record.saved_changes : {}
          )
        end
      end

      def apply_field_change_event(event)
        event_name = event.name
        field = event.field
        condition = event.condition

        @model_class.after_update do |record|
          if record.saved_change_to_attribute?(field)
            should_fire = if condition.is_a?(Hash)
              ConditionEvaluator.evaluate_any(record, condition)
            else
              true
            end

            if should_fire
              LcpRuby::Events::Dispatcher.dispatch(
                event_name: event_name,
                record: record,
                changes: record.saved_changes
              )
            end
          end
        end
      end
    end
  end
end
