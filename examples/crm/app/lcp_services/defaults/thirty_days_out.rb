module LcpRuby
  module HostServices
    module Defaults
      class ThirtyDaysOut
        def self.call(record, field_name)
          Date.current + 30
        end
      end
    end
  end
end
