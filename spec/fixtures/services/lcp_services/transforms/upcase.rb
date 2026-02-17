module LcpRuby
  module HostServices
    module Transforms
      class Upcase
        def call(value)
          value.respond_to?(:upcase) ? value.upcase : value
        end
      end
    end
  end
end
