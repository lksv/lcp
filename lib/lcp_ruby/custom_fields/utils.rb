module LcpRuby
  module CustomFields
    module Utils
      # Parse a JSON string with environment-aware error handling.
      # In dev/test: raises on parse error so bad data is immediately visible.
      # In production: logs the error and returns the fallback.
      #
      # @param raw [String] JSON string to parse
      # @param fallback [Object] value to return on failure in production
      # @param context [String, nil] description for log message (e.g., "project#custom_data (id: 42)")
      # @return [Object] parsed JSON or fallback
      def self.safe_parse_json(raw, fallback: {}, context: nil)
        return fallback if raw.blank?

        JSON.parse(raw)
      rescue JSON::ParserError => e
        raise if Rails.env.local?

        Rails.logger.error(
          "[LcpRuby::CustomFields] #{context} — JSON parse failed: #{e.message}"
        )
        fallback
      end

      # Convert a value to BigDecimal with environment-aware error handling.
      # In dev/test: raises on invalid input.
      # In production: logs the error and returns nil.
      #
      # @param value [Object] value to convert
      # @param context [String, nil] description for log message
      # @return [BigDecimal, nil]
      def self.safe_to_decimal(value, context: nil)
        BigDecimal(value.to_s)
      rescue ArgumentError, TypeError => e
        raise if Rails.env.local?

        Rails.logger.error(
          "[LcpRuby::CustomFields] #{context} — invalid numeric value #{value.inspect}: #{e.message}"
        )
        nil
      end
    end
  end
end
