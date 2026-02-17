module LcpRuby
  module Services
    class BuiltInTransforms
      class << self
        def register_all!
          Types::BuiltInServices::TRANSFORMS.each do |key, klass|
            Registry.register("transforms", key, klass.new)
          end
        end
      end
    end
  end
end
