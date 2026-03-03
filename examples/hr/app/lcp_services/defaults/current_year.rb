module LcpRuby
  module HostServices
    module Defaults
      class CurrentYear
        def self.call(record, field_name)
          Date.current.year
        end
      end
    end
  end
end
