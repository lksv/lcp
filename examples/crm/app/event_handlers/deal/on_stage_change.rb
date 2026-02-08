module LcpRuby
  module HostEventHandlers
    module Deal
      class OnStageChange < LcpRuby::Events::HandlerBase
        def self.handles_event
          "on_stage_change"
        end

        def call
          old_stage = old_value("stage")
          new_stage = new_value("stage")
          Rails.logger.info("[CRM] Deal '#{record.title}' stage changed: #{old_stage} -> #{new_stage}")
        end
      end
    end
  end
end
