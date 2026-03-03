module LcpRuby
  module HostConditionServices
    class IsOwnOrgUnit
      def self.call(record)
        return false unless record.respond_to?(:organization_unit_id) && record.organization_unit_id

        user = LcpRuby::Current.user
        return false unless user&.respond_to?(:organization_unit_id) && user.organization_unit_id

        record.organization_unit_id == user.organization_unit_id
      end
    end
  end
end
