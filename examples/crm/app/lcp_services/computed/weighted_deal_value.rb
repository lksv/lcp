module LcpRuby
  module HostServices
    module Computed
      class WeightedDealValue
        def self.call(record)
          value = record.value.to_f
          progress = record.progress.to_f
          (value * progress / 100.0).round(2)
        end
      end
    end
  end
end
