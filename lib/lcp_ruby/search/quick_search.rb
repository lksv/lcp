module LcpRuby
  module Search
    class QuickSearch
      # Applies type-aware quick text search across searchable fields.
      # Returns a narrowed scope or the original scope if query is blank.
      #
      # @param searchable_field_names [Array<String>, nil] field names from search_config;
      #   if nil, all non-attachment, non-id model fields are used.
      def self.apply(scope, query, model_class, model_definition, searchable_field_names: nil)
        return scope if query.blank?

        # Escape hatch: model override
        if model_class.respond_to?(:default_query)
          return scope.merge(model_class.default_query(query))
        end

        searchable_fields = searchable_field_definitions(model_class, model_definition, searchable_field_names)
        conditions = build_conditions(query, model_class, model_definition, searchable_fields)

        # Include searchable custom fields
        if model_definition.custom_fields_enabled?
          cf_conditions = build_custom_field_conditions(query, model_definition)
          conditions.concat(cf_conditions)
        end

        # Non-empty query but no conditions means no fields could match
        return scope.none if conditions.empty?

        scope.where(conditions.reduce(:or))
      end

      # Returns FieldDefinition objects for searchable fields.
      def self.searchable_field_definitions(model_class, model_definition, field_names)
        fields = model_definition.fields
          .select { |f| model_class.column_names.include?(f.name) }
          .reject { |f| f.attachment? || f.name == "id" }

        if field_names.present?
          name_set = field_names.map(&:to_s).to_set
          fields = fields.select { |f| name_set.include?(f.name) }
        end

        fields
      end

      private_class_method :searchable_field_definitions

      def self.build_conditions(query, model_class, model_definition, field_definitions)
        table = model_class.arel_table
        conditions = []

        field_definitions.each do |field_def|
          condition = condition_for_field(table, field_def, query, model_class)
          conditions << condition if condition
        end

        conditions
      end

      private_class_method :build_conditions

      def self.condition_for_field(table, field_def, query, model_class)
        col = table[field_def.name]
        type = resolved_type(field_def)

        case type
        when "string", "text", "email", "phone", "url", "color", "rich_text"
          col.matches("%#{sanitize_like(query)}%")
        when "integer"
          int_val = Integer(query, exception: false)
          col.eq(int_val) if int_val
        when "float", "decimal"
          float_val = Float(query, exception: false)
          col.eq(float_val) if float_val
        when "boolean"
          bool_val = ParamSanitizer.normalize_boolean(query)
          col.eq(bool_val) if bool_val.is_a?(TrueClass) || bool_val.is_a?(FalseClass)
        when "date"
          date_val = parse_date(query)
          col.eq(date_val) if date_val
        when "datetime"
          datetime_condition(col, query)
        when "enum"
          enum_condition(col, field_def, query, model_class)
        end
      end

      private_class_method :condition_for_field

      def self.resolved_type(field_def)
        # Use the base type for typed fields (e.g., email -> string)
        field_def.type.to_s
      end

      private_class_method :resolved_type

      def self.sanitize_like(query)
        ActiveRecord::Base.sanitize_sql_like(query)
      end

      private_class_method :sanitize_like

      def self.parse_date(query)
        Date.parse(query)
      rescue Date::Error, ArgumentError
        nil
      end

      private_class_method :parse_date

      def self.datetime_condition(col, query)
        parsed = DateTime.parse(query)

        # Detect precision: does the query include time?
        if query.match?(/\d{4}-\d{2}-\d{2}[\sT]\d/)
          # Has time component - match to the minute
          minute_start = parsed.beginning_of_minute
          minute_end = minute_start + 1.minute
          col.gteq(minute_start).and(col.lt(minute_end))
        else
          # Date-only - match the whole day
          day_start = parsed.to_date.beginning_of_day
          day_end = day_start + 1.day
          col.gteq(day_start).and(col.lt(day_end))
        end
      rescue Date::Error, ArgumentError
        nil
      end

      private_class_method :datetime_condition

      def self.enum_condition(col, field_def, query, _model_class)
        return nil unless field_def.enum?

        matching_values = field_def.enum_value_names.select do |value_name|
          # Match stored value OR humanized display label (case-insensitive)
          value_name.downcase.include?(query.downcase) ||
            value_name.humanize.downcase.include?(query.downcase)
        end

        return nil if matching_values.empty?

        col.in(matching_values)
      end

      private_class_method :enum_condition

      def self.build_custom_field_conditions(query, model_definition)
        sanitized_q = sanitize_like(query)
        CustomFields::Registry.for_model(model_definition.name)
          .select { |d| d.active && d.searchable }
          .filter_map do |d|
            sql = CustomFields::Query.text_search_condition(
              model_definition.table_name, d.field_name, sanitized_q
            )
            Arel.sql("(#{sql})") if sql.present?
          end
      end

      private_class_method :build_custom_field_conditions
    end
  end
end
