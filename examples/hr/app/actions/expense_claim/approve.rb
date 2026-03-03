module LcpRuby
  module HostActions
    module ExpenseClaim
      class Approve < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No expense claim specified")
          end

          unless record.status == "submitted"
            return failure(message: "Only submitted expense claims can be approved (current status: #{record.status})")
          end

          employee = current_user.respond_to?(:employee_id) ? current_user.employee_id : current_user.id
          record.update!(status: "approved", approved_by_id: employee, approved_at: Time.current)
          success(message: "Expense claim '#{record.title}' approved")
        end
      end
    end
  end
end
