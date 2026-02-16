module LcpRuby
  module Types
    module Transforms
      class NormalizePhone < BaseTransform
        def call(value)
          return value if value.nil? || value.empty?

          stripped = value.strip
          # Preserve leading + then strip all non-digit characters
          if stripped.start_with?("+")
            "+#{stripped[1..].gsub(/\D/, '')}"
          else
            stripped.gsub(/\D/, "")
          end
        end
      end
    end
  end
end
