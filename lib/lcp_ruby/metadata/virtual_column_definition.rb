module LcpRuby
  module Metadata
    class VirtualColumnDefinition
      VALID_FUNCTIONS = %w[count sum min max avg].freeze

      attr_reader :name, :function, :association, :source_field, :where,
                  :distinct, :default, :include_discarded, :expression, :service,
                  :type, :options, :join, :group, :auto_include

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @function = attrs[:function]&.to_s
        @association = attrs[:association]&.to_s
        @source_field = attrs[:source_field]&.to_s.presence
        @where = attrs[:where] || {}
        @distinct = attrs[:distinct] || false
        @default = attrs[:default]
        @include_discarded = attrs[:include_discarded] || false
        # Accept both :expression and legacy :sql kwarg
        @expression = attrs[:expression]&.to_s.presence || attrs[:sql]&.to_s.presence
        @service = attrs[:service]&.to_s.presence
        @type = attrs[:type]&.to_s.presence
        @options = attrs[:options] || {}
        @join = attrs[:join]&.to_s.presence
        @group = attrs[:group] || false
        @auto_include = attrs[:auto_include] || false

        validate!
      end

      def self.from_hash(name, hash)
        # Reject both keys present (including explicit nil values)
        if hash.key?("sql") && hash.key?("expression")
          raise MetadataError, "Virtual column '#{name}': cannot specify both 'sql' and 'expression'"
        end

        # Map legacy "sql" key to expression
        expression_value = hash["expression"] || hash["sql"]

        new(
          name: name,
          function: hash["function"],
          association: hash["association"],
          source_field: hash["source_field"],
          where: hash["where"] || {},
          distinct: hash["distinct"],
          default: hash["default"],
          include_discarded: hash["include_discarded"],
          expression: expression_value,
          service: hash["service"],
          type: hash["type"],
          options: hash["options"],
          join: hash["join"],
          group: hash["group"],
          auto_include: hash["auto_include"]
        )
      end

      def declarative?
        function.present? && expression.nil? && service.nil?
      end

      def expression_type?
        expression.present?
      end

      # Legacy alias
      alias_method :sql_type?, :expression_type?

      # Legacy accessor for backward compatibility
      def sql
        expression
      end

      def service_type?
        service.present?
      end

      # Infer the result type based on function and source field type.
      # For expression and service types, the explicit `type` attribute is used.
      def inferred_type(model_definition = nil)
        return type if type.present?
        return "integer" if function == "count"

        if model_definition && source_field.present? && association.present?
          assoc_def = model_definition.associations.find { |a| a.name == association }
          if assoc_def&.target_model
            target_def = LcpRuby.loader.model_definition(assoc_def.target_model)
            if target_def
              field_def = target_def.field(source_field)
              if field_def
                return "float" if function == "avg" && field_def.resolved_base_type != "decimal"
                return "decimal" if function == "avg" && field_def.resolved_base_type == "decimal"
                return field_def.resolved_base_type
              end
            end
          end
        end

        # Fallback when source field type cannot be resolved
        case function
        when "avg" then "float"
        when "sum", "min", "max" then "decimal"
        else "string"
        end
      end

      private

      def validate!
        raise MetadataError, "Virtual column name is required" if @name.blank?

        if @auto_include && @group
          raise MetadataError, "Virtual column '#{@name}': auto_include and group cannot both be true"
        end

        if @function.present? && @expression.present?
          raise MetadataError, "Virtual column '#{@name}': cannot specify both 'function' and 'expression'"
        end

        if @function.present? && @service.present?
          raise MetadataError, "Virtual column '#{@name}': cannot specify both 'function' and 'service'"
        end

        if @expression.present? && @service.present?
          raise MetadataError, "Virtual column '#{@name}': cannot specify both 'expression' and 'service'"
        end

        if declarative?
          unless VALID_FUNCTIONS.include?(@function)
            raise MetadataError, "Virtual column '#{@name}': invalid function '#{@function}'. " \
                                 "Valid: #{VALID_FUNCTIONS.join(', ')}"
          end
          if @association.blank?
            raise MetadataError, "Virtual column '#{@name}': declarative aggregate requires 'association'"
          end
          if @function != "count" && @source_field.blank?
            raise MetadataError, "Virtual column '#{@name}': function '#{@function}' requires 'source_field'"
          end
        elsif expression_type?
          if @type.blank?
            raise MetadataError, "Virtual column '#{@name}': expression type requires 'type'"
          end
        elsif service_type?
          if @type.blank?
            raise MetadataError, "Virtual column '#{@name}': service type requires 'type'"
          end
        else
          raise MetadataError, "Virtual column '#{@name}': must specify function+association, expression, or service"
        end
      end
    end
  end
end
