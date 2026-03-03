module LcpRuby
  module HostActions
    module LeaveRequest
      class Reject < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No leave request specified")
          end

          unless record.status == "pending"
            return failure(message: "Only pending leave requests can be rejected (current status: #{record.status})")
          end

          employee = current_user.respond_to?(:employee_id) ? current_user.employee_id : current_user.id
          record.update!(status: "rejected", approved_by_id: employee, approved_at: Time.current)
          success(message: "Leave request rejected")
        end
      end
    end
  end
end
