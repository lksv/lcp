module LcpRuby
  module HostActions
    module Candidate
      class RejectCandidate < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No candidate specified")
          end

          if record.status.in?(%w[rejected hired])
            return failure(message: "Cannot reject a candidate who is already #{record.status}")
          end

          record.update!(status: "rejected")
          success(message: "Candidate '#{record.full_name}' rejected")
        end
      end
    end
  end
end
