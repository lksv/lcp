module LcpRuby
  module ModelFactory
    # Custom ActiveRecord::Type for array fields on non-PostgreSQL databases.
    # Transparently serializes Ruby Arrays to JSON strings and deserializes
    # back, with item-level type casting based on the configured item_type.
    class ArrayType < ActiveRecord::Type::Value
      def initialize(item_type = "string")
        @item_type = item_type
        super()
      end

      def type
        :lcp_array
      end

      # Deserialize from DB (JSON string -> Ruby Array)
      def deserialize(value)
        case value
        when String
          parsed = parse_json_array(value)
          parsed ? cast_items(parsed) : []
        when Array
          cast_items(value)
        else
          []
        end
      end

      # Cast from user input (form params, assignment)
      def cast(value)
        case value
        when Array then cast_items(value.reject { |v| v.respond_to?(:blank?) && v.blank? })
        when String
          if value.start_with?("[")
            parsed = parse_json_array(value)
            return cast_items(parsed) if parsed
          end
          cast_items(value.split(",").map(&:strip).reject(&:blank?))
        when nil then []
        else [ cast_item(value) ]
        end
      end

      # Serialize to DB (Ruby Array -> JSON string)
      def serialize(value)
        arr = value.is_a?(Array) ? value : []
        arr.to_json
      end

      def changed_in_place?(raw_old_value, new_value)
        deserialize(raw_old_value) != new_value
      end

      private

      def parse_json_array(str)
        parsed = JSON.parse(str)
        parsed.is_a?(Array) ? parsed : nil
      rescue JSON::ParserError => e
        raise unless defined?(Rails) && Rails.env.production?
        Rails.logger.error("[LcpRuby] ArrayType JSON parse error: #{e.message}")
        nil
      end

      def cast_items(items)
        items.map { |item| cast_item(item) }
      end

      def cast_item(item)
        case @item_type
        when "integer" then item.to_i
        when "float"   then item.to_f
        else item.to_s
        end
      end
    end
  end
end
