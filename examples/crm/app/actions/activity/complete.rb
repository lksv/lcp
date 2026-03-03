module LcpRuby
  module HostActions
    module Activity
      class Complete < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No activity specified")
          end

          if record.completed
            return failure(message: "Activity is already completed")
          end

          record.update!(completed: true, completed_at: Time.current)
          success(message: "Activity '#{record.subject}' marked as complete!")
        end
      end
    end
  end
end
