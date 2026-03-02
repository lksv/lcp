module LcpRuby
  module Search
    class CustomFieldFilter
      VALID_OPERATORS = OperatorRegistry::OPERATORS_BY_TYPE.values.flatten.uniq.freeze

      CAST_MAP = {
        "integer" => :integer,
        "float" => :decimal,
        "decimal" => :decimal,
        "date" => :date,
        "datetime" => :date
      }.freeze

      class << self
        # Apply a single custom field condition to a scope.
        #
        # @param scope [ActiveRecord::Relation]
        # @param table_name [String]
        # @param field_name [String] custom field name (validated)
        # @param operator [Symbol] one of VALID_OPERATORS
        # @param value [String, Array] the filter value
        # @param cast [Symbol, nil] type cast (:integer, :decimal, :date)
        # @return [ActiveRecord::Relation]
        def apply(scope, table_name, field_name, operator, value, cast: nil)
          CustomFields::Query.validate_field_name!(field_name)
          operator = operator.to_sym

          unless VALID_OPERATORS.include?(operator)
            Rails.logger.warn(
              "[LcpRuby::CustomFieldFilter] Unknown operator: #{operator.inspect} for field #{field_name}"
            )
            return scope
          end

          expr = json_extract_expr(table_name, field_name)
          cast_expr = cast ? apply_cast(expr, cast) : expr

          condition = build_condition(cast_expr, expr, operator, value)
          return scope unless condition

          scope.where(Arel.sql(condition))
        end

        # Determine the cast type for a custom field type.
        def cast_for_type(custom_type)
          CAST_MAP[custom_type.to_s]
        end

        # Parse a composite cf key into [field_name, operator].
        # Keys arrive as "field_name_operator" (e.g., "priority_eq").
        # @param key [String] the composite key
        # @param sorted_field_names [Array<String>] field names sorted by length desc
        # @return [Array(String, String), nil] [field_name, operator] or nil
        def parse_cf_key(key, sorted_field_names)
          key = key.to_s
          sorted_field_names.each do |name|
            prefix = "#{name}_"
            if key.start_with?(prefix)
              operator = key[prefix.length..]
              return [ name, operator ] if operator.present?
            end
          end
          nil
        end

        private

        def json_extract_expr(table_name, field_name)
          CustomFields::Query.json_extract_expr(table_name, field_name)
        end

        def apply_cast(expr, cast)
          CustomFields::Query.apply_cast(expr, cast)
        end

        def build_condition(cast_expr, raw_expr, operator, value)
          conn = ActiveRecord::Base.connection

          case operator
          when :eq
            "#{cast_expr} = #{quote_value(conn, value)}"
          when :not_eq
            "(#{cast_expr} != #{quote_value(conn, value)} OR #{raw_expr} IS NULL)"
          when :cont
            like_condition(cast_expr, "%#{sanitize_like(value)}%")
          when :not_cont
            "(#{not_like_condition(cast_expr, "%#{sanitize_like(value)}%")} OR #{raw_expr} IS NULL)"
          when :start
            like_condition(cast_expr, "#{sanitize_like(value)}%")
          when :not_start
            "(#{not_like_condition(cast_expr, "#{sanitize_like(value)}%")} OR #{raw_expr} IS NULL)"
          when :end
            like_condition(cast_expr, "%#{sanitize_like(value)}")
          when :not_end
            "(#{not_like_condition(cast_expr, "%#{sanitize_like(value)}")} OR #{raw_expr} IS NULL)"
          when :gt
            "#{cast_expr} > #{quote_value(conn, value)}"
          when :gteq
            "#{cast_expr} >= #{quote_value(conn, value)}"
          when :lt
            "#{cast_expr} < #{quote_value(conn, value)}"
          when :lteq
            "#{cast_expr} <= #{quote_value(conn, value)}"
          when :between
            build_between(cast_expr, value, conn)
          when :in
            build_in(cast_expr, value, conn)
          when :not_in
            "(#{build_not_in(cast_expr, value, conn)} OR #{raw_expr} IS NULL)"
          when :present
            "#{raw_expr} IS NOT NULL AND #{raw_expr} != #{conn.quote('')}"
          when :blank
            "(#{raw_expr} IS NULL OR #{raw_expr} = #{conn.quote('')})"
          when :null
            "#{raw_expr} IS NULL"
          when :not_null
            "#{raw_expr} IS NOT NULL"
          when :true
            "#{cast_expr} = #{conn.quote('true')}"
          when :false
            "(#{cast_expr} = #{conn.quote('false')} OR #{raw_expr} IS NULL)"
          end
        end

        def like_condition(expr, pattern)
          conn = ActiveRecord::Base.connection
          if LcpRuby.postgresql?
            "#{expr} ILIKE #{conn.quote(pattern)}"
          else
            "#{expr} LIKE #{conn.quote(pattern)} ESCAPE '\\'"
          end
        end

        def not_like_condition(expr, pattern)
          conn = ActiveRecord::Base.connection
          if LcpRuby.postgresql?
            "#{expr} NOT ILIKE #{conn.quote(pattern)}"
          else
            "#{expr} NOT LIKE #{conn.quote(pattern)} ESCAPE '\\'"
          end
        end

        def build_between(expr, value, conn)
          values = Array(value)
          return nil unless values.size == 2

          "#{expr} >= #{quote_value(conn, values[0])} AND #{expr} <= #{quote_value(conn, values[1])}"
        end

        def build_in(expr, value, conn)
          values = Array(value).map { |v| quote_value(conn, v) }
          return nil if values.empty?

          "#{expr} IN (#{values.join(', ')})"
        end

        def build_not_in(expr, value, conn)
          values = Array(value).map { |v| quote_value(conn, v) }
          return nil if values.empty?

          "#{expr} NOT IN (#{values.join(', ')})"
        end

        def quote_value(conn, value)
          conn.quote(value.to_s)
        end

        def sanitize_like(value)
          ActiveRecord::Base.sanitize_sql_like(value.to_s)
        end
      end
    end
  end
end
