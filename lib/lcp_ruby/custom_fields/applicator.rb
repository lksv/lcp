module LcpRuby
  module CustomFields
    class Applicator
      attr_reader :model_class, :model_definition

      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless model_definition.custom_fields_enabled?

        install_custom_data_accessors!
        install_class_method!
        install_validation!
        install_defaults!
      end

      private

      # Define read/write helpers for the custom_data JSONB/JSON column.
      def install_custom_data_accessors!
        mn = model_definition.name

        model_class.define_method(:read_custom_field) do |name|
          data = read_custom_data_hash
          data[name.to_s]
        end

        model_class.define_method(:write_custom_field) do |name, value|
          data = read_custom_data_hash
          data[name.to_s] = value
          self[:custom_data] = data
        end

        # Parse custom_data from JSON string (SQLite returns String, PG returns Hash).
        model_class.define_method(:read_custom_data_hash) do
          raw = self[:custom_data]
          case raw
          when Hash then raw
          when String
            Utils.safe_parse_json(raw, context: "#{mn}#custom_data (id: #{id.inspect})")
          else
            {}
          end
        end

        model_class.send(:private, :read_custom_data_hash)
      end

      # Define a class method that queries the Registry and defines
      # getter/setter methods for each active custom field.
      # Tracks defined accessors so stale ones can be removed on re-apply.
      def install_class_method!
        model_name = model_definition.name

        model_class.define_singleton_method(:apply_custom_field_accessors!) do
          # Remove previously defined custom field accessors
          Array(@_custom_field_accessors).each do |old_name|
            remove_method(old_name) if method_defined?(old_name, false)
            remove_method(:"#{old_name}=") if method_defined?(:"#{old_name}=", false)
          end

          definitions = Registry.for_model(model_name)
          @_custom_field_accessors = []

          definitions.each do |defn|
            field_name = defn.field_name
            next if field_name.blank?
            next if BuiltInModel.reserved_name?(field_name)

            # Skip if a real column or method already exists (conflict avoidance)
            next if column_names.include?(field_name)

            # Define getter
            define_method(field_name) do
              read_custom_field(field_name)
            end

            # Define setter
            define_method("#{field_name}=") do |value|
              write_custom_field(field_name, value)
            end

            @_custom_field_accessors << field_name.to_sym
          end
        end
      end

      # Validate custom fields based on their definition metadata.
      def install_validation!
        model_name = model_definition.name

        model_class.validate do
          definitions = Registry.for_model(model_name)
          data = read_custom_data_hash

          definitions.each do |defn|
            field_name = defn.field_name
            value = data[field_name]

            # Required check
            if defn.required && (value.nil? || value.to_s.strip.empty?)
              errors.add(field_name.to_sym, :blank)
              next
            end

            next if value.nil? || value.to_s.strip.empty?

            validate_custom_field_constraints(defn, field_name, value)
          end
        end

        model_class.define_method(:validate_custom_field_constraints) do |defn, field_name, value|
          sym = field_name.to_sym

          # String/text length constraints (only for string-like types)
          if %w[string text].include?(defn.custom_type)
            if defn.min_length.present? && defn.min_length > 0 && value.to_s.length < defn.min_length
              errors.add(sym, :too_short, count: defn.min_length)
            end

            if defn.max_length.present? && defn.max_length > 0 && value.to_s.length > defn.max_length
              errors.add(sym, :too_long, count: defn.max_length)
            end
          end

          # Numeric range constraints
          if %w[integer float decimal].include?(defn.custom_type)
            # Invalid numeric input is expected user error, not data corruption —
            # always add validation error rather than raising in dev.
            numeric_value = begin
              BigDecimal(value.to_s)
            rescue ArgumentError, TypeError
              nil
            end
            if numeric_value.nil?
              errors.add(sym, :not_a_number)
            else
              if defn.min_value.present? && numeric_value < BigDecimal(defn.min_value.to_s)
                errors.add(sym, :greater_than_or_equal_to, count: defn.min_value)
              end
              if defn.max_value.present? && numeric_value > BigDecimal(defn.max_value.to_s)
                errors.add(sym, :less_than_or_equal_to, count: defn.max_value)
              end
            end
          end

          # Enum validation
          if defn.custom_type == "enum" && defn.enum_values.present?
            allowed = parse_enum_allowed_values(defn.enum_values, defn)
            unless allowed.include?(value.to_s)
              errors.add(sym, :inclusion)
            end
          end
        end

        model_class.define_method(:parse_enum_allowed_values) do |enum_values, defn|
          raw = case enum_values
          when String
            Utils.safe_parse_json(
              enum_values, fallback: [],
              context: "#{model_name}.#{defn.field_name} enum_values (id: #{id.inspect})"
            )
          when Array then enum_values
          else []
          end

          raw.map { |v| v.is_a?(Hash) ? (v["value"] || v[:value]).to_s : v.to_s }
        end

        model_class.send(:private, :validate_custom_field_constraints, :parse_enum_allowed_values)
      end

      # Apply default_value from custom field definitions to new records.
      def install_defaults!
        mn = model_definition.name

        model_class.after_initialize do |record|
          next unless record.new_record?

          definitions = Registry.for_model(mn)
          definitions.each do |defn|
            next if defn.default_value.blank?

            current = record.read_custom_field(defn.field_name)
            record.write_custom_field(defn.field_name, defn.default_value) if current.nil?
          end
        end
      end
    end
  end
end
