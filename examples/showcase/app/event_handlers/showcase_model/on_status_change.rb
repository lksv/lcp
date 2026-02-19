module LcpRuby
  module HostEventHandlers
    module ShowcaseModel
      class OnStatusChange < LcpRuby::Events::HandlerBase
        def self.handles_event
          "on_status_change"
        end

        def call
          old_status = old_value("status")
          new_status = new_value("status")
          Rails.logger.info("[Showcase] Model '#{record.name}' status changed: #{old_status} -> #{new_status}")
        end
      end
    end
  end
end
