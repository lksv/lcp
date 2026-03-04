module LcpRuby
  module Metadata
    class AggregateDefinition
      VALID_FUNCTIONS = %w[count sum min max avg].freeze

      attr_reader :name, :function, :association, :source_field, :where,
                  :distinct, :default, :include_discarded, :sql, :service,
                  :type, :options

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @function = attrs[:function]&.to_s
        @association = attrs[:association]&.to_s
        @source_field = attrs[:source_field]&.to_s.presence
        @where = attrs[:where] || {}
        @distinct = attrs[:distinct] || false
        @default = attrs[:default]
        @include_discarded = attrs[:include_discarded] || false
        @sql = attrs[:sql]&.to_s.presence
        @service = attrs[:service]&.to_s.presence
        @type = attrs[:type]&.to_s.presence
        @options = attrs[:options] || {}

        validate!
      end

      def self.from_hash(name, hash)
        new(
          name: name,
          function: hash["function"],
          association: hash["association"],
          source_field: hash["source_field"],
          where: hash["where"] || {},
          distinct: hash["distinct"],
          default: hash["default"],
          include_discarded: hash["include_discarded"],
          sql: hash["sql"],
          service: hash["service"],
          type: hash["type"],
          options: hash["options"]
        )
      end

      def declarative?
        function.present? && sql.nil? && service.nil?
      end

      def sql_type?
        sql.present?
      end

      def service_type?
        service.present?
      end

      # Infer the result type based on function and source field type.
      # For sql and service types, the explicit `type` attribute is used.
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
        raise MetadataError, "Aggregate name is required" if @name.blank?

        if declarative?
          unless VALID_FUNCTIONS.include?(@function)
            raise MetadataError, "Aggregate '#{@name}': invalid function '#{@function}'. " \
                                 "Valid: #{VALID_FUNCTIONS.join(', ')}"
          end
          if @association.blank?
            raise MetadataError, "Aggregate '#{@name}': declarative aggregate requires 'association'"
          end
          if @function != "count" && @source_field.blank?
            raise MetadataError, "Aggregate '#{@name}': function '#{@function}' requires 'source_field'"
          end
        elsif sql_type?
          if @type.blank?
            raise MetadataError, "Aggregate '#{@name}': SQL aggregate requires 'type'"
          end
        elsif service_type?
          if @type.blank?
            raise MetadataError, "Aggregate '#{@name}': service aggregate requires 'type'"
          end
        else
          raise MetadataError, "Aggregate '#{@name}': must specify function+association, sql, or service"
        end
      end
    end
  end
end
