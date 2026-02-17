module LcpRuby
  module Services
    class BuiltInDefaults
      DEFAULTS = {
        "current_date" => ->(record, field_name) { Date.today },
        "current_datetime" => ->(record, field_name) { Time.current },
        "current_user_id" => ->(record, field_name) { LcpRuby::Current.user&.id }
      }.freeze

      class << self
        def register_all!
          DEFAULTS.each do |key, callable|
            Registry.register("defaults", key, callable)
          end
        end
      end
    end
  end
end
