module LcpRuby
  module HostConditionServices
    class OverdueCheck
      def self.call(record)
        return false unless record.respond_to?(:due_date) && record.due_date.present?

        record.due_date < Date.current
      end
    end
  end
end
