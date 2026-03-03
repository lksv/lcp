module LcpRuby
  module HostServices
    module DataProviders
      class PendingActivitiesCount
        def self.call(user:)
          count = LcpRuby.registry.model_for("activity")
            .where(completed: false)
            .where("scheduled_at <= ?", Time.current)
            .count
          count > 0 ? count : nil
        end
      end
    end
  end
end
