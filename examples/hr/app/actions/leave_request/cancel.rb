module LcpRuby
  module HostActions
    module LeaveRequest
      class Cancel < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No leave request specified")
          end

          if record.status.in?(%w[approved rejected cancelled])
            return failure(message: "Cannot cancel a leave request that is already #{record.status}")
          end

          record.update!(status: "cancelled")
          success(message: "Leave request cancelled")
        end
      end
    end
  end
end
