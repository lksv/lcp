module LcpRuby
  # DB-portable query helpers for array fields.
  # Uses native PG array operators (@>, &&, <@) on PostgreSQL
  # and json_each() subqueries on SQLite.
  class ArrayQuery
    class << self
      # Records where the array field contains ALL of the given values.
      def contains(scope, table_name, field_name, values, item_type: "string")
        values = Array(values)
        return scope if values.empty?

        c = connection
        col = quoted_column(c, table_name, field_name)

        condition = if LcpRuby.postgresql?
          "#{col} @> #{pg_array_literal(values, c, item_type)}"
        else
          "(SELECT COUNT(DISTINCT je.value) FROM json_each(#{col}) je " \
            "WHERE je.value IN (#{quoted_values(values, c)})) = #{values.size}"
        end

        scope.where(Arel.sql(condition))
      end

      # Records where the array field contains ANY of the given values.
      def overlaps(scope, table_name, field_name, values, item_type: "string")
        values = Array(values)
        return scope.none if values.empty?

        c = connection
        col = quoted_column(c, table_name, field_name)

        condition = if LcpRuby.postgresql?
          "#{col} && #{pg_array_literal(values, c, item_type)}"
        else
          "EXISTS (SELECT 1 FROM json_each(#{col}) je " \
            "WHERE je.value IN (#{quoted_values(values, c)}))"
        end

        scope.where(Arel.sql(condition))
      end

      # Records where the array field is a subset of the given values.
      # Empty values matches only records with empty arrays.
      def contained_by(scope, table_name, field_name, values, item_type: "string")
        values = Array(values)

        c = connection
        col = quoted_column(c, table_name, field_name)

        if values.empty?
          return scope.where(Arel.sql(
            LcpRuby.postgresql? ?
              "#{col} = '{}'" :
              "json_array_length(#{col}) = 0"
          ))
        end

        condition = if LcpRuby.postgresql?
          "#{col} <@ #{pg_array_literal(values, c, item_type)}"
        else
          "NOT EXISTS (SELECT 1 FROM json_each(#{col}) je " \
            "WHERE je.value NOT IN (#{quoted_values(values, c)}))"
        end

        scope.where(Arel.sql(condition))
      end

      # SQL expression for the size of the array.
      def array_length_expression(table_name, field_name)
        c = connection
        col = quoted_column(c, table_name, field_name)

        if LcpRuby.postgresql?
          "COALESCE(array_length(#{col}, 1), 0)"
        else
          "json_array_length(#{col})"
        end
      end

      # Text search condition for array string fields (used by QuickSearch).
      def text_search_condition(table_name, field_name, query)
        c = connection
        col = quoted_column(c, table_name, field_name)
        quoted_query = c.quote("%#{query}%")

        if LcpRuby.postgresql?
          "EXISTS (SELECT 1 FROM unnest(#{col}) item " \
            "WHERE item ILIKE #{quoted_query})"
        else
          "EXISTS (SELECT 1 FROM json_each(#{col}) je " \
            "WHERE je.value LIKE #{quoted_query})"
        end
      end

      private

      def connection
        ActiveRecord::Base.connection
      end

      def quoted_column(c, table_name, field_name)
        "#{c.quote_table_name(table_name)}.#{c.quote_column_name(field_name)}"
      end

      def quoted_values(values, c)
        values.map { |v| c.quote(v.to_s) }.join(", ")
      end

      def pg_array_literal(values, c, item_type)
        pg_type = case item_type
                  when "integer" then "integer[]"
                  when "float"   then "float8[]"
                  else "text[]"
                  end
        "ARRAY[#{quoted_values(values, c)}]::#{pg_type}"
      end
    end
  end
end
