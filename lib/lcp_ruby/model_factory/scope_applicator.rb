module LcpRuby
  module ModelFactory
    class ScopeApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.scopes.each do |scope_config|
          scope_config = scope_config.transform_keys(&:to_s) if scope_config.is_a?(Hash)
          apply_scope(scope_config)
        end
      end

      private

      def apply_scope(scope_config)
        name = scope_config["name"]&.to_sym
        return unless name

        if scope_config["type"] == "custom"
          # Custom scopes are defined by Ruby code in model extensions
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
