module LcpRuby
  module HostActions
    module Candidate
      class Advance < LcpRuby::Actions::BaseAction
        PIPELINE = %w[applied screening interviewing offer].freeze

        def call
          unless record
            return failure(message: "No candidate specified")
          end

          if record.status.in?(%w[hired rejected withdrawn])
            return failure(message: "Cannot advance a candidate with status '#{record.status}'")
          end

          current_index = PIPELINE.index(record.status)
          unless current_index
            return failure(message: "Candidate status '#{record.status}' is not part of the advancement pipeline")
          end

          next_status = PIPELINE[current_index + 1]
          unless next_status
            return failure(message: "Candidate is already at the final pipeline stage ('#{record.status}')")
          end

          record.update!(status: next_status)
          success(message: "Candidate '#{record.full_name}' advanced to #{next_status}")
        end
      end
    end
  end
end
