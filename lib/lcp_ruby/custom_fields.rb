module LcpRuby
  module CustomFields
    RESERVED_NAMES = %w[id type created_at updated_at custom_data].freeze

    def self.reserved_name?(name)
      RESERVED_NAMES.include?(name.to_s)
    end
  end
end
