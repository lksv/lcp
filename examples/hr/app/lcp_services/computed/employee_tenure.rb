module LcpRuby
  module HostServices
    module Computed
      class EmployeeTenure
        def self.call(record)
          return nil unless record.respond_to?(:hire_date) && record.hire_date.present?

          today = Date.current
          total_months = (today.year * 12 + today.month) - (record.hire_date.year * 12 + record.hire_date.month)
          total_months -= 1 if today.day < record.hire_date.day

          years = total_months / 12
          months = total_months % 12

          if years > 0 && months > 0
            "#{years} #{years == 1 ? 'year' : 'years'}, #{months} #{months == 1 ? 'month' : 'months'}"
          elsif years > 0
            "#{years} #{years == 1 ? 'year' : 'years'}"
          elsif months > 0
            "#{months} #{months == 1 ? 'month' : 'months'}"
          else
            "Less than a month"
          end
        end
      end
    end
  end
end
