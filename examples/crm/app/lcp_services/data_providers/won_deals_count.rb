module LcpRuby
  module HostServices
    module DataProviders
      class WonDealsCount
        def self.call(user:)
          count = LcpRuby.registry.model_for("deal")
            .where(stage: "closed_won")
            .count
          count > 0 ? { "text" => "#{count} won", "color" => "#28a745" } : nil
        end
      end
    end
  end
end
