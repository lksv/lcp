module LcpRuby
  module HostActions
    module Interview
      class CompleteInterview < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No interview specified")
          end

          unless record.status == "scheduled"
            return failure(message: "Only scheduled interviews can be completed (current status: #{record.status})")
          end

          record.update!(status: "completed")
          success(message: "Interview marked as completed")
        end
      end
    end
  end
end
