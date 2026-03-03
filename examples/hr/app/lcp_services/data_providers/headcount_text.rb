module LcpRuby
  module HostServices
    module DataProviders
      class HeadcountText
        def self.call(user:)
          count = LcpRuby.registry.model_for("employee")
            .where(status: "active")
            .count
          { "value" => count.to_s }
        end
      end
    end
  end
end
