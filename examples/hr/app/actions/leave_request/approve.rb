module LcpRuby
  module HostActions
    module LeaveRequest
      class Approve < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No leave request specified")
          end

          unless record.status == "pending"
            return failure(message: "Only pending leave requests can be approved (current status: #{record.status})")
          end

          employee = current_user.respond_to?(:employee_id) ? current_user.employee_id : current_user.id
          record.update!(status: "approved", approved_by_id: employee, approved_at: Time.current)
          success(message: "Leave request approved")
        end
      end
    end
  end
end
