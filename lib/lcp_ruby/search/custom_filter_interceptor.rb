module LcpRuby
  module Search
    class CustomFilterInterceptor
      # Detects and calls filter_* class methods on the model class.
      # Returns [updated_scope, remaining_params] where remaining_params
      # has the intercepted keys removed.
      def self.apply(scope, filter_params, model_class, evaluator)
        return [ scope, filter_params ] if filter_params.blank?

        remaining = filter_params.dup

        filter_params.each do |key, value|
          method_name = "filter_#{key}"
          next unless own_filter_method?(model_class, method_name)

          result = model_class.send(method_name, scope, value, evaluator)

          if result.is_a?(ActiveRecord::Relation)
            scope = result
            remaining.delete(key)
          else
            Rails.logger.warn(
              "[LcpRuby::Search] filter_#{key} on #{model_class.name} did not return " \
              "ActiveRecord::Relation (got #{result.class}), skipping"
            )
          end
        end

        [ scope, remaining ]
      end

      # Returns true if the method is defined on the model's singleton class
      # (not inherited from ActiveRecord::Base or other ancestors).
      def self.own_filter_method?(model_class, method_name)
        model_class.respond_to?(method_name) &&
          !ActiveRecord::Base.respond_to?(method_name)
      end
    end
  end
end
