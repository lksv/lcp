module LcpRuby
  module VirtualColumns
    class Builder
      # Inject virtual column subqueries/expressions into a scope.
      #
      # @param scope [ActiveRecord::Relation] the base scope
      # @param model_definition [Metadata::ModelDefinition] the model definition
      # @param vc_names [Array<String>] names of virtual columns to include
      # @param current_user [Object, nil] the current user (for :current_user placeholder)
      # @return [Array(ActiveRecord::Relation, Array<String>, Boolean)] modified scope, service-only names, and whether GROUP BY was applied
      def self.apply(scope, model_definition, vc_names, current_user: nil)
        return [ scope, [], false ] if vc_names.empty?

        conn = ActiveRecord::Base.connection
        parent_table = conn.quote_table_name(model_definition.table_name)
        subqueries = []
        service_only = []
        joins_to_apply = []
        needs_group_by = false

        vc_names.each do |vc_name|
          vc_def = model_definition.virtual_column(vc_name)
          next unless vc_def

          if vc_def.join.present?
            joins_to_apply << vc_def.join
          end

          needs_group_by = true if vc_def.group

          sql = build_subquery(vc_def, model_definition, parent_table, conn, current_user: current_user)
          if sql
            subqueries << "#{sql} AS #{conn.quote_column_name(vc_name)}"
          elsif vc_def.service_type?
            service_only << vc_name
          end
        end

        applied_vc_names = vc_names - service_only

        if subqueries.any?
          scope = scope.select("#{parent_table}.*", *subqueries)
        end

        # Apply deduplicated JOINs
        if joins_to_apply.any?
          seen = Set.new
          joins_to_apply.each do |join_sql|
            normalized = join_sql.gsub("%{table}", parent_table).gsub(/\s+/, " ").strip
            dedup_key = normalized.downcase
            next if seen.include?(dedup_key)
            seen << dedup_key

            scope = scope.joins(Arel.sql(normalized))
          end
        end

        # Apply GROUP BY if any virtual column requires it
        if needs_group_by
          scope = scope.group("#{parent_table}.#{conn.quote_column_name('id')}")
        end

        # Wrap scope with extending module for loaded-tracking guard.
        # Pushes VC names onto thread-local stack around exec_queries so
        # after_initialize callbacks can capture which VCs were loaded.
        if applied_vc_names.any? && scope.klass.respond_to?(:_virtual_columns_stack)
          vc_name_set = Set.new(applied_vc_names.map(&:to_s)).freeze
          scope = scope.extending(Module.new do
            define_method(:exec_queries) do
              klass._virtual_columns_stack ||= []
              klass._virtual_columns_stack.push(vc_name_set)
              begin
                super()
              ensure
                klass._virtual_columns_stack.pop
              end
            end
          end)
        end

        [ scope, service_only, needs_group_by ]
      end

      def self.build_subquery(vc_def, model_definition, parent_table, conn, current_user: nil)
        if vc_def.declarative?
          build_declarative_subquery(vc_def, model_definition, parent_table, conn, current_user: current_user)
        elsif vc_def.expression_type?
          build_expression(vc_def, parent_table, conn)
        elsif vc_def.service_type?
          build_service_subquery(vc_def, model_definition, conn)
        end
      end

      def self.build_declarative_subquery(vc_def, model_definition, parent_table, conn, current_user: nil)
        assoc_def = model_definition.associations.find { |a| a.name == vc_def.association }
        return nil unless assoc_def

        target_model_name = assoc_def.target_model
        return nil unless target_model_name

        target_model_def = LcpRuby.loader.model_definition(target_model_name)
        return nil unless target_model_def

        target_table = conn.quote_table_name(target_model_def.table_name)

        # Determine FK: for has_many, FK is on the target table
        fk = if assoc_def.as.present?
          # Polymorphic: FK is <as>_id on target
          assoc_def.as + "_id"
        else
          assoc_def.foreign_key.presence || "#{model_definition.name}_id"
        end

        quoted_fk = "#{target_table}.#{conn.quote_column_name(fk)}"

        # Build the SELECT expression
        select_expr = build_function_expression(vc_def, target_table, conn)

        # Build WHERE clause
        conditions = [ "#{quoted_fk} = #{parent_table}.#{conn.quote_column_name('id')}" ]

        # Polymorphic type condition
        if assoc_def.as.present?
          type_col = "#{target_table}.#{conn.quote_column_name("#{assoc_def.as}_type")}"
          parent_class_name = "LcpRuby::Dynamic::#{model_definition.name.camelize}"
          conditions << "#{type_col} = #{conn.quote(parent_class_name)}"
        end

        # Soft delete filter on target
        if target_model_def.soft_delete? && !vc_def.include_discarded
          discard_col = target_model_def.soft_delete_column
          conditions << "#{target_table}.#{conn.quote_column_name(discard_col)} IS NULL"
        end

        # Where conditions from virtual column definition
        vc_def.where.each do |field, value|
          quoted_col = "#{target_table}.#{conn.quote_column_name(field)}"
          condition = build_where_condition(quoted_col, value, conn, current_user: current_user)
          conditions << condition if condition
        end

        where_clause = conditions.join(" AND ")

        # Apply COALESCE
        raw_sql = "(SELECT #{select_expr} FROM #{target_table} WHERE #{where_clause})"
        wrap_coalesce(raw_sql, vc_def, conn)
      end

      def self.build_function_expression(vc_def, target_table, conn)
        func = vc_def.function.upcase

        if vc_def.function == "count" && vc_def.source_field.blank?
          # COUNT(DISTINCT *) is not valid SQL — distinct requires a source_field
          "COUNT(*)"
        else
          source = "#{target_table}.#{conn.quote_column_name(vc_def.source_field)}"
          if vc_def.distinct
            "#{func}(DISTINCT #{source})"
          else
            "#{func}(#{source})"
          end
        end
      end

      def self.build_where_condition(quoted_col, value, conn, current_user: nil)
        # Handle :current_user placeholder
        resolved = resolve_placeholder(value, current_user: current_user)

        case resolved
        when nil
          "#{quoted_col} IS NULL"
        when Array
          if resolved.empty?
            "1 = 0" # Empty array matches nothing
          else
            quoted_values = resolved.map { |v| conn.quote(v) }.join(", ")
            "#{quoted_col} IN (#{quoted_values})"
          end
        else
          "#{quoted_col} = #{conn.quote(resolved)}"
        end
      end

      def self.resolve_placeholder(value, current_user: nil)
        if value.is_a?(String) && value == ":current_user"
          current_user&.id
        elsif value.is_a?(Symbol) && value == :current_user
          current_user&.id
        elsif value.is_a?(Array)
          value.map { |v| resolve_placeholder(v, current_user: current_user) }
        else
          value
        end
      end

      def self.build_expression(vc_def, parent_table, conn)
        # Expand %{table} placeholder
        raw_sql = vc_def.expression.gsub("%{table}", parent_table)
        wrap_coalesce("(#{raw_sql})", vc_def, conn)
      end

      def self.build_service_subquery(vc_def, model_definition, conn)
        service = Services::Registry.lookup_vc_service(vc_def.service)
        return nil unless service

        if service.respond_to?(:sql_expression)
          model_class = LcpRuby.registry.model_for(model_definition.name)
          sql_expr = service.sql_expression(model_class, options: vc_def.options)
          return nil unless sql_expr.present?

          wrap_coalesce("(#{sql_expr})", vc_def, conn)
        end
        # If no sql_expression, returns nil — value computed per-record
      end

      def self.wrap_coalesce(sql, vc_def, conn)
        default_value = vc_def.default
        # COUNT always defaults to 0
        if vc_def.declarative? && vc_def.function == "count"
          default_value = 0 if default_value.nil?
        end

        if !default_value.nil?
          "(COALESCE(#{sql}, #{conn.quote(default_value)}))"
        else
          sql
        end
      end

      private_class_method :build_subquery, :build_declarative_subquery,
                           :build_function_expression, :build_where_condition,
                           :resolve_placeholder, :build_expression,
                           :build_service_subquery, :wrap_coalesce
    end
  end
end
