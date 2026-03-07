module LcpRuby
  module ModelFactory
    class ScopeApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.scopes.each do |scope_config|
          apply_scope(scope_config)
        end
        apply_array_scopes
      end

      private

      def apply_array_scopes
        table = @model_definition.table_name
        @model_definition.fields.select(&:array?).each do |field|
          field_name = field.name
          item_type = field.item_type

          @model_class.scope :"with_#{field_name}", ->(values) {
            ArrayQuery.contains(all, table, field_name, values, item_type: item_type)
          }

          @model_class.scope :"with_any_#{field_name}", ->(values) {
            ArrayQuery.overlaps(all, table, field_name, values, item_type: item_type)
          }
        end
      end

      def apply_scope(scope_config)
        name = scope_config["name"]&.to_sym
        return unless name

        if scope_config["type"].in?(%w[custom parameterized])
          # Custom and parameterized scopes are defined by Ruby code in model extensions
          return
        end

        conditions = scope_config["where"]
        not_conditions = scope_config["where_not"]
        order = scope_config["order"]
        limit_val = scope_config["limit"]

        @model_class.scope name, -> {
          rel = all
          rel = rel.where(conditions) if conditions
          rel = rel.where.not(not_conditions) if not_conditions
          if order.is_a?(Hash)
            order.each { |col, dir| rel = rel.order(col => dir) }
          end
          rel = rel.limit(limit_val) if limit_val
          rel
        }
      end
    end
  end
end
