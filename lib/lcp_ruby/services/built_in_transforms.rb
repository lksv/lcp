module LcpRuby
  module Services
    class BuiltInTransforms
      TRANSFORMS = {
        "strip" => Types::Transforms::Strip,
        "downcase" => Types::Transforms::Downcase,
        "normalize_url" => Types::Transforms::NormalizeUrl,
        "normalize_phone" => Types::Transforms::NormalizePhone
      }.freeze

      class << self
        def register_all!
          TRANSFORMS.each do |key, klass|
            Registry.register("transforms", key, klass.new)
          end
        end
      end
    end
  end
end
