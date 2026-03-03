module LcpRuby
  module HostActions
    module Candidate
      class Hire < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No candidate specified")
          end

          unless record.status == "offer"
            return failure(message: "Only candidates at the 'offer' stage can be hired (current status: #{record.status})")
          end

          record.update!(status: "hired")
          success(message: "Candidate '#{record.full_name}' hired!")
        end
      end
    end
  end
end
