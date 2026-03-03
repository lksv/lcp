module LcpRuby
  module HostEventHandlers
    module Candidate
      class OnStatusChange < LcpRuby::Events::HandlerBase
        def self.handles_event
          "on_status_change"
        end

        def call
          old_status = old_value("status")
          new_status = new_value("status")

          Rails.logger.info("[HR] Candidate '#{record.full_name}' moved from #{old_status} to #{new_status}")
        end
      end
    end
  end
end
