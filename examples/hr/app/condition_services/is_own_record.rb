module LcpRuby
  module HostConditionServices
    class IsOwnRecord
      def self.call(record)
        user = LcpRuby::Current.user
        return false unless user

        employee_id = user.respond_to?(:employee_id) ? user.employee_id : user.id

        if record.class.table_name == "employees" || record.class.name&.demodulize == "Employee"
          record.id == employee_id
        elsif record.respond_to?(:employee_id)
          record.employee_id == employee_id
        else
          false
        end
      end
    end
  end
end
