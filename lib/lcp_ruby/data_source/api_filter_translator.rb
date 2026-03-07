module LcpRuby
  module DataSource
    # Translates Ransack-style filter params to a portable filter format
    # that data source adapters can process.
    class ApiFilterTranslator
      # Maps Ransack predicate suffixes to portable operator names
      PREDICATE_MAP = {
        "eq"      => "eq",
        "not_eq"  => "not_eq",
        "cont"    => "cont",
        "not_cont" => "not_cont",
        "lt"      => "lt",
        "lteq"    => "lteq",
        "gt"      => "gt",
        "gteq"    => "gteq",
        "in"      => "in",
        "null"    => "null",
        "not_null" => "not_null",
        "start"   => "start",
        "end"     => "end",
        "present" => "present",
        "blank"   => "blank",
        "true"    => "true",
        "false"   => "false"
      }.freeze

      # Translate Ransack-style params into portable filter array.
      # @param ransack_params [Hash] e.g. { "name_cont" => "tower", "status_eq" => "active" }
      # @param field_names [Array<String>] known field names for this model
      # @param supported_operators [Array<String>] operators the data source supports
      # @return [Array<Hash>] e.g. [{ field: "name", operator: "cont", value: "tower" }]
      def self.translate(ransack_params, field_names:, supported_operators: nil)
        return [] if ransack_params.blank?

        # Sort field names longest first to match greedily
        sorted_fields = field_names.sort_by { |n| -n.length }

        filters = []
        ransack_params.each do |key, value|
          field, operator = parse_ransack_key(key.to_s, sorted_fields)
          next unless field && operator

          if supported_operators && !supported_operators.include?(operator)
            Rails.logger.warn(
              "[LcpRuby::ApiFilterTranslator] Dropping unsupported operator '#{operator}' " \
              "for field '#{field}' (supported: #{supported_operators.join(', ')})"
            )
            next
          end

          filters << { field: field, operator: operator, value: value }
        end

        filters
      end

      # Parse a Ransack key into [field_name, operator].
      # @param key [String] e.g. "name_cont", "status_eq"
      # @param field_names [Array<String>] sorted by length desc
      # @return [Array(String, String), nil] [field_name, operator] or nil
      def self.parse_ransack_key(key, field_names)
        field_names.each do |field_name|
          next unless key.start_with?("#{field_name}_")
          suffix = key[(field_name.length + 1)..]
          operator = PREDICATE_MAP[suffix]
          return [ field_name, operator ] if operator
        end
        nil
      end
    end
  end
end
