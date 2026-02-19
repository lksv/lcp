module LcpRuby
  module HostServices
    module Computed
      class FeatureScore
        def self.call(record)
          base = record.amount.to_f
          multiplier = case record.status
          when "active" then 1.5
          when "completed" then 2.0
          when "cancelled" then 0.0
          else 1.0
          end
          (base * multiplier).round(2)
        end
      end
    end
  end
end
