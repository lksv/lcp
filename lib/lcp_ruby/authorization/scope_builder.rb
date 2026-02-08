module LcpRuby
  module Authorization
    class ScopeBuilder
      attr_reader :scope_config, :user

      def initialize(scope_config, user)
        @scope_config = scope_config.is_a?(Hash) ? scope_config.transform_keys(&:to_s) : {}
        @user = user
      end

      def apply(base_relation)
        case scope_config["type"]
        when "field_match"
          apply_field_match(base_relation)
        when "association"
          apply_association_scope(base_relation)
        when "where"
          apply_where(base_relation)
        when "custom"
          apply_custom(base_relation)
        else
          base_relation
        end
      end

      private

      def apply_field_match(base_relation)
        field = scope_config["field"]
        value_ref = scope_config["value"]
        value = resolve_value(value_ref)
        base_relation.where(field => value)
      end

      def apply_association_scope(base_relation)
        field = scope_config["field"]
        method_name = scope_config["method"]
        return base_relation unless user.respond_to?(method_name)

        values = user.send(method_name)
        base_relation.where(field => values)
      end

      def apply_where(base_relation)
        conditions = scope_config["conditions"]
        base_relation.where(conditions)
      end

      def apply_custom(base_relation)
        method_name = scope_config["method"]
        if base_relation.respond_to?(method_name)
          base_relation.send(method_name, user)
        else
          base_relation
        end
      end

      def resolve_value(value_ref)
        case value_ref
        when "current_user_id"
          user&.id
        when /\Acurrent_user_(\w+)\z/
          method_name = $1
          user.respond_to?(method_name) ? user.send(method_name) : nil
        else
          value_ref
        end
      end
    end
  end
end
