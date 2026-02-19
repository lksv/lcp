module LcpRuby
  module HostServices
    module Computed
      class ShowcaseTotal
        def self.call(record)
          amount = record.amount.to_f
          multiplier = record.currency == "EUR" ? 1.1 : 1.0
          (amount * multiplier).round(0).to_i
        end
      end
    end
  end
end
