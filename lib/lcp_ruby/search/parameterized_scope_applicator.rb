module LcpRuby
  module Search
    class ParameterizedScopeApplicator
      # Applies parameterized scopes from request params to a query scope.
      #
      # @param scope [ActiveRecord::Relation] the current query scope
      # @param scope_params [Hash] raw params hash, e.g. { "created_recently" => { "days" => "30" } }
      # @param model_class [Class] the AR model class
      # @param model_definition [Metadata::ModelDefinition]
      # @param evaluator [Authorization::PermissionEvaluator]
      # @return [ActiveRecord::Relation]
      def self.apply(scope, scope_params, model_class, model_definition, evaluator:)
        return scope if scope_params.blank?

        scope_params.each do |scope_name, raw_params|
          scope_config = model_definition.parameterized_scope(scope_name)
          next unless scope_config

          raw_params = raw_params.to_unsafe_h if raw_params.respond_to?(:to_unsafe_h)
          raw_params = {} unless raw_params.is_a?(Hash)

          parameters = scope_config["parameters"] || []
          cast_params = cast_parameters(parameters, raw_params)

          # Skip if required params are missing
          next if missing_required?(parameters, cast_params)

          # Try filter_* interceptor first, then direct scope
          interceptor = "filter_#{scope_name}"
          if model_class.respond_to?(interceptor)
            scope = model_class.send(interceptor, scope, cast_params, evaluator)
          elsif model_class.respond_to?(scope_name)
            scope = invoke_scope(scope, scope_name, cast_params)
          else
            Rails.logger.warn(
              "[LcpRuby::ParameterizedScopeApplicator] Scope '#{scope_name}' " \
              "not found on model #{model_class.name}"
            )
          end
        end

        scope
      end

      # Casts raw string params according to parameter type definitions.
      # @param parameters [Array<Hash>] parameter definitions from YAML
      # @param raw_params [Hash] raw string params from request
      # @return [Hash] cast params with symbolized keys
      def self.cast_parameters(parameters, raw_params)
        result = {}

        parameters.each do |param_def|
          param_def = param_def.transform_keys(&:to_s) if param_def.is_a?(Hash)
          name = param_def["name"]
          type = param_def["type"]
          raw_value = raw_params[name] || raw_params[name.to_sym]

          if raw_value.nil?
            default = param_def["default"]
            result[name.to_sym] = default unless default.nil?
            next
          end

          cast = cast_value(raw_value, type, param_def)
          result[name.to_sym] = cast unless cast.nil?
        end

        result
      end
      private_class_method :cast_parameters

      def self.cast_value(raw, type, param_def)
        case type
        when "integer"
          val = raw.to_i
          val = clamp_numeric(val, param_def)
          val
        when "float"
          val = raw.to_f
          val = clamp_numeric(val, param_def)
          val
        when "string"
          raw.to_s
        when "boolean"
          %w[true 1 yes].include?(raw.to_s.downcase)
        when "date"
          Date.parse(raw.to_s)
        when "datetime"
          DateTime.parse(raw.to_s)
        when "enum"
          values = Array(param_def["values"]).map(&:to_s)
          raw_str = raw.to_s
          values.include?(raw_str) ? raw_str : nil
        when "model_select"
          raw.to_i
        end
      rescue ArgumentError, TypeError
        nil
      end
      private_class_method :cast_value

      def self.clamp_numeric(val, param_def)
        min = param_def["min"]
        max = param_def["max"]
        val = [ val, min ].max if min
        val = [ val, max ].min if max
        val
      end
      private_class_method :clamp_numeric

      def self.missing_required?(parameters, cast_params)
        parameters.any? do |param_def|
          param_def = param_def.transform_keys(&:to_s) if param_def.is_a?(Hash)
          param_def["required"] == true && !cast_params.key?(param_def["name"].to_sym)
        end
      end
      private_class_method :missing_required?

      def self.invoke_scope(scope, scope_name, cast_params)
        if cast_params.any?
          scope.send(scope_name, **cast_params)
        else
          scope.send(scope_name)
        end
      end
      private_class_method :invoke_scope
    end
  end
end
