module LcpRuby
  module HostServices
    module DataProviders
      class PendingLeavesCount
        def self.call(user:)
          count = LcpRuby.registry.model_for("leave_request")
            .where(status: "pending")
            .count
          count > 0 ? count : nil
        end
      end
    end
  end
end
