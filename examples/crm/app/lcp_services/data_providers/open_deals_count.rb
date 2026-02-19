module LcpRuby
  module HostServices
    module DataProviders
      class OpenDealsCount
        def self.call(user:)
          count = LcpRuby.registry.model_for("deal")
            .where.not(stage: %w[closed_won closed_lost])
            .count
          count > 0 ? count : nil
        end
      end
    end
  end
end
