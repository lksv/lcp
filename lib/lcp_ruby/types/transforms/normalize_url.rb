module LcpRuby
  module Types
    module Transforms
      class NormalizeUrl < BaseTransform
        def call(value)
          return value if value.nil? || value.empty?

          stripped = value.strip
          return stripped if stripped.match?(%r{\A[a-zA-Z][a-zA-Z0-9+\-.]*://})

          "https://#{stripped}"
        end
      end
    end
  end
end
