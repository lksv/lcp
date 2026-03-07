module LcpRuby
  module HostServices
    module VirtualColumns
      class ProjectHealth
        def self.call(record, options: {})
          total = record.tasks_count.to_i
          return 0 if total.zero?

          completed = record.completed_count.to_i
          ((completed.to_f / total) * 100).round
        end

        def self.sql_expression(model_class, options: {})
          t = model_class.table_name
          "(CASE WHEN (SELECT COUNT(*) FROM showcase_aggregate_items " \
          "WHERE showcase_aggregate_items.showcase_aggregate_id = #{t}.id) = 0 THEN 0 " \
          "ELSE (SELECT COUNT(*) FROM showcase_aggregate_items " \
          "WHERE showcase_aggregate_items.showcase_aggregate_id = #{t}.id " \
          "AND showcase_aggregate_items.status = 'done') * 100 / " \
          "(SELECT COUNT(*) FROM showcase_aggregate_items " \
          "WHERE showcase_aggregate_items.showcase_aggregate_id = #{t}.id) END)"
        end
      end
    end
  end
end
