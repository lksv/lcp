module LcpRuby
  module HostServices
    module Validators
      class LeaveBalanceCheck
        def self.call(record, **opts)
          return unless record.respond_to?(:employee_id) && record.employee_id
          return unless record.respond_to?(:leave_type_id) && record.leave_type_id
          return unless record.respond_to?(:days_count) && record.days_count.to_f > 0

          balance_model = LcpRuby.registry.model_for("leave_balance")
          balance = balance_model.find_by(
            employee_id: record.employee_id,
            leave_type_id: record.leave_type_id,
            year: Date.current.year
          )

          unless balance
            record.errors.add(:base, "No leave balance found for this leave type in the current year")
            return
          end

          remaining = balance.total_days.to_f - balance.used_days.to_f

          # Exclude current record's days if it was previously approved (re-edit scenario)
          if record.persisted?
            old_days = record.class.find(record.id).days_count.to_f
            remaining += old_days if record.class.find(record.id).status == "approved"
          end

          if record.days_count.to_f > remaining
            record.errors.add(:days_count, "exceeds remaining leave balance (#{remaining} days available)")
          end
        end
      end
    end
  end
end
