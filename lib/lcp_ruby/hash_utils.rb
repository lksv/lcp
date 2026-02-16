module LcpRuby
  module HashUtils
    # Recursively stringify Hash keys and Symbol values.
    # Recurses into Arrays. Passes through primitives unchanged.
    def self.stringify_deep(value)
      case value
      when Hash
        value.transform_keys(&:to_s).transform_values { |v| stringify_deep(v) }
      when Symbol
        value.to_s
      when Array
        value.map { |v| stringify_deep(v) }
      else
        value
      end
    end
  end
end
