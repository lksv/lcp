module LcpRuby
  module HostServices
    module DataProviders
      class ActiveContactsCount
        def self.call(user:)
          count = LcpRuby.registry.model_for("contact")
            .where(active: true)
            .count
          count > 0 ? count : nil
        end
      end
    end
  end
end
