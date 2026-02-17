module LcpRuby
  module HostServices
    module Defaults
      class OneWeekFromNow
        def self.call(record, field_name)
          Date.current + 7
        end
      end
    end
  end
end
