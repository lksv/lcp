module LcpRuby
  module HostServices
    module Computed
      class LeaveRemaining
        def self.call(record)
          total = record.total_days.to_f
          used = record.used_days.to_f
          (total - used).round(1)
        end
      end
    end
  end
end
