module LcpRuby
  module HostActions
    module ExpenseClaim
      class Submit < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No expense claim specified")
          end

          unless record.status == "draft"
            return failure(message: "Only draft expense claims can be submitted (current status: #{record.status})")
          end

          record.update!(status: "submitted")
          success(message: "Expense claim '#{record.title}' submitted for approval")
        end
      end
    end
  end
end
