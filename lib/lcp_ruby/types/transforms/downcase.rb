module LcpRuby
  module Types
    module Transforms
      class Downcase < BaseTransform
        def call(value)
          value&.downcase
        end
      end
    end
  end
end
