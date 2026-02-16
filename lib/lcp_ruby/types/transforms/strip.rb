module LcpRuby
  module Types
    module Transforms
      class Strip < BaseTransform
        def call(value)
          value.respond_to?(:strip) ? value.strip : value
        end
      end
    end
  end
end
