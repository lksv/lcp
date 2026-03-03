module LcpRuby
  module HostServices
    module DataProviders
      class PendingExpensesCount
        def self.call(user:)
          count = LcpRuby.registry.model_for("expense_claim")
            .where(status: "submitted")
            .count
          count > 0 ? count : nil
        end
      end
    end
  end
end
