module LcpRuby
  module Events
    class AsyncHandlerJob < ActiveJob::Base
      queue_as :default

      def perform(handler_class_name, args)
        handler_class = handler_class_name.constantize
        record_class = args["record_class"].constantize
        record = record_class.find(args["record_id"])

        context = {
          record: record,
          changes: args["changes"] || {},
          event_name: args["event_name"]
        }

        handler_class.new(context).call
      end
    end
  end
end
