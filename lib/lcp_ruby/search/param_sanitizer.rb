module LcpRuby
  module Search
    class ParamSanitizer
      TRUTHY = %w[true 1 t yes].freeze
      FALSY = %w[false 0 f no].freeze

      # Removes key-value pairs where the value is a blank string.
      # Preserves nil, false, 0, and non-string blanks.
      def self.reject_blanks(params_hash)
        return {} if params_hash.blank?

        params_hash.reject { |_, v| v.is_a?(String) && v.blank? }
      end

      # Normalizes a value to boolean if it matches common truthy/falsy strings.
      # Returns the original value unchanged if it doesn't match.
      def self.normalize_boolean(value)
        str = value.to_s.downcase
        return true if TRUTHY.include?(str)
        return false if FALSY.include?(str)
        value
      end
    end
  end
end
