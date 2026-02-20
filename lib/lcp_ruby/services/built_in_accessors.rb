module LcpRuby
  module Services
    class BuiltInAccessors
      ACCESSORS = {
        "json_field" => Accessors::JsonField
      }.freeze

      class << self
        def register_all!
          ACCESSORS.each do |key, service|
            Registry.register("accessors", key, service)
          end
        end
      end
    end
  end
end
