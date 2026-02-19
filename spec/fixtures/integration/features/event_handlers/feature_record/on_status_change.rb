module LcpRuby
  module HostEventHandlers
    module FeatureRecord
      class OnStatusChange < LcpRuby::Events::HandlerBase
        # Class-level flag for test assertions
        class << self
          attr_accessor :last_change
        end

        def self.handles_event
          "on_status_change"
        end

        def call
          old_status = old_value("status")
          new_status = new_value("status")

          self.class.last_change = {
            record_name: record.name,
            old_status: old_status,
            new_status: new_status
          }
        end
      end
    end
  end
end
