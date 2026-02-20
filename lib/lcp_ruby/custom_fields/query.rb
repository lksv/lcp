module LcpRuby
  module CustomFields
    class Query
      VALID_FIELD_NAME = /\A[a-z][a-z0-9_]*\z/

      class << self
        # Generate a text search condition for a custom field stored in custom_data JSONB/JSON column.
        # @param table_name [String] the database table name
        # @param field_name [String] the custom field name (key within custom_data)
        # @param query [String] the search query (already sanitized with sanitize_sql_like)
        # @return [String] SQL condition fragment
        def text_search_condition(table_name, field_name, query)
          validate_field_name!(field_name)
          conn = ActiveRecord::Base.connection
          quoted_table = conn.quote_table_name(table_name)

          if LcpRuby.postgresql?
            "#{quoted_table}.custom_data ->> #{conn.quote(field_name)} ILIKE #{conn.quote("%#{query}%")}"
          else
            "JSON_EXTRACT(#{quoted_table}.custom_data, #{conn.quote("$.#{field_name}")}) LIKE #{conn.quote("%#{query}%")}"
          end
        end

        # Apply a text search on a scope for a custom field.
        # @param scope [ActiveRecord::Relation] the current scope
        # @param table_name [String] the database table name
        # @param field_name [String] the custom field name
        # @param query [String] the search term (already sanitized)
        # @return [ActiveRecord::Relation] filtered scope
        def text_search(scope, table_name, field_name, query)
          condition = text_search_condition(table_name, field_name, query)
          scope.where(Arel.sql(condition))
        end

        # Exact match condition for a custom field value.
        # @param scope [ActiveRecord::Relation] the current scope
        # @param table_name [String] the database table name
        # @param field_name [String] the custom field name
        # @param value [Object] the value to match
        # @return [ActiveRecord::Relation] filtered scope
        def exact_match(scope, table_name, field_name, value)
          validate_field_name!(field_name)
          conn = ActiveRecord::Base.connection
          quoted_table = conn.quote_table_name(table_name)

          condition = if LcpRuby.postgresql?
            "#{quoted_table}.custom_data ->> #{conn.quote(field_name)} = #{conn.quote(value.to_s)}"
          else
            "JSON_EXTRACT(#{quoted_table}.custom_data, #{conn.quote("$.#{field_name}")}) = #{conn.quote(value.to_s)}"
          end

          scope.where(Arel.sql(condition))
        end

        # Build a sort expression for ordering by a custom field value.
        # @param table_name [String] the database table name
        # @param field_name [String] the custom field name
        # @param direction [String] "asc" or "desc"
        # @param cast [Symbol, nil] optional type cast (:integer, :decimal, :date)
        # @return [Arel::Nodes::SqlLiteral] SQL sort expression
        def sort_expression(table_name, field_name, direction, cast: nil)
          validate_field_name!(field_name)
          conn = ActiveRecord::Base.connection
          quoted_table = conn.quote_table_name(table_name)
          dir = direction.to_s.downcase == "desc" ? "DESC" : "ASC"

          expr = if LcpRuby.postgresql?
            "#{quoted_table}.custom_data ->> #{conn.quote(field_name)}"
          else
            "JSON_EXTRACT(#{quoted_table}.custom_data, #{conn.quote("$.#{field_name}")})"
          end

          expr = apply_cast(expr, cast) if cast

          Arel.sql("#{expr} #{dir}")
        end

        private

        def validate_field_name!(field_name)
          unless field_name.to_s.match?(VALID_FIELD_NAME)
            raise ArgumentError, "Invalid custom field name: #{field_name.inspect}"
          end
        end

        def apply_cast(expr, cast)
          case cast
          when :integer
            LcpRuby.postgresql? ? "(#{expr})::integer" : "CAST(#{expr} AS INTEGER)"
          when :decimal, :float
            LcpRuby.postgresql? ? "(#{expr})::numeric" : "CAST(#{expr} AS REAL)"
          when :date
            LcpRuby.postgresql? ? "(#{expr})::date" : "DATE(#{expr})"
          else
            expr
          end
        end
      end
    end
  end
end
