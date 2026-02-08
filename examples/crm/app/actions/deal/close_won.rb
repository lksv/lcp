module LcpRuby
  module HostActions
    module Deal
      class CloseWon < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No deal specified")
          end

          if record.stage.in?(["closed_won", "closed_lost"])
            return failure(message: "Deal is already closed")
          end

          record.update!(stage: "closed_won")
          success(message: "Deal '#{record.title}' marked as won!")
        end
      end
    end
  end
end
