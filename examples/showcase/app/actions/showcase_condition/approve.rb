module LcpRuby
  module HostActions
    module ShowcaseCondition
      class Approve < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No record specified")
          end

          unless record.status == "review"
            return failure(message: "Only records in review can be approved")
          end

          record.update!(status: "approved")
          success(message: "Record '#{record.title}' has been approved.")
        end
      end
    end
  end
end
