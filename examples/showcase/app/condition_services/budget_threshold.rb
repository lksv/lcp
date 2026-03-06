module LcpRuby
  module HostConditionServices
    class BudgetThreshold
      # Value service: returns a computed budget threshold based on priority.
      # Called via: value: { service: budget_threshold, params: { priority: { field_ref: priority } } }
      def self.call(record, **params)
        case params[:priority].to_s
        when "critical" then 50_000
        when "high" then 25_000
        when "medium" then 10_000
        else 5_000
        end
      end
    end
  end
end
