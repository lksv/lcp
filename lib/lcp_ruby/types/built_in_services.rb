module LcpRuby
  module Types
    class BuiltInServices
      TRANSFORMS = {
        "strip" => Transforms::Strip,
        "downcase" => Transforms::Downcase,
        "normalize_url" => Transforms::NormalizeUrl,
        "normalize_phone" => Transforms::NormalizePhone
      }.freeze

      class << self
        def register_all!
          TRANSFORMS.each do |key, klass|
            ServiceRegistry.register("transform", key, klass.new)
          end
        end
      end
    end
  end
end
