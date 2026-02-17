module LcpRuby
  module HostConditionServices
    class PersistedCheck
      def self.call(record)
        record.persisted?
      end
    end
  end
end
