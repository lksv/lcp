module LcpRuby
  module HostEventHandlers
    module LeaveRequest
      class OnStatusChange < LcpRuby::Events::HandlerBase
        def self.handles_event
          "on_status_change"
        end

        def call
          old_status = old_value("status")
          new_status = new_value("status")

          Rails.logger.info("[HR] Leave request ##{record.id} status changed: #{old_status} -> #{new_status}")

          if new_status == "approved"
            adjust_leave_balance(record.days_count.to_f)
          elsif old_status == "approved" && new_status == "cancelled"
            adjust_leave_balance(-record.days_count.to_f)
          end
        end

        private

        def adjust_leave_balance(days_delta)
          balance_model = LcpRuby.registry.model_for("leave_balance")
          balance = balance_model.find_by(
            employee_id: record.employee_id,
            leave_type_id: record.leave_type_id,
            year: Date.current.year
          )

          unless balance
            Rails.logger.warn("[HR] No leave balance found for employee #{record.employee_id}, " \
                              "leave type #{record.leave_type_id}, year #{Date.current.year}")
            return
          end

          new_used = balance.used_days.to_f + days_delta
          balance.update!(used_days: new_used)
          Rails.logger.info("[HR] Leave balance updated: used_days = #{new_used} (delta: #{days_delta > 0 ? '+' : ''}#{days_delta})")
        end
      end
    end
  end
end
