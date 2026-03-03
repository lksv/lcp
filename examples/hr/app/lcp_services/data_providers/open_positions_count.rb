module LcpRuby
  module HostServices
    module DataProviders
      class OpenPositionsCount
        def self.call(user:)
          count = LcpRuby.registry.model_for("job_posting")
            .where(status: "open")
            .count
          count > 0 ? count : nil
        end
      end
    end
  end
end
