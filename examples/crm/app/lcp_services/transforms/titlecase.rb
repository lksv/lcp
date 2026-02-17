module LcpRuby
  module HostServices
    module Transforms
      class Titlecase
        def call(value)
          value.respond_to?(:titlecase) ? value.titlecase : value
        end
      end
    end
  end
end
