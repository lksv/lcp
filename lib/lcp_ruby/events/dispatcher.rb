module LcpRuby
  module Events
    class Dispatcher
      class << self
        def dispatch(event_name:, record:, changes: {})
          model_name = infer_model_name(record)
          handlers = HandlerRegistry.handlers_for(model_name, event_name)

          handlers.each do |handler_class|
            context = {
              record: record,
              changes: changes,
              current_user: Current.user,
              event_name: event_name
            }

            if handler_class.async?
              AsyncHandlerJob.perform_later(handler_class.name, context_to_args(context, record))
            else
              handler_class.new(context).call
            end
          end
        end

        private

        def infer_model_name(record)
          class_name = record.class.name
          # LcpRuby::Dynamic::Project -> "project"
          class_name.demodulize.underscore
        end

        def context_to_args(context, record)
          {
            "record_class" => record.class.name,
            "record_id" => record.id,
            "changes" => context[:changes],
            "event_name" => context[:event_name]
          }
        end
      end
    end
  end
end
