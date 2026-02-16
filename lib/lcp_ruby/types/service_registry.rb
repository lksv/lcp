module LcpRuby
  module Types
    class ServiceRegistry
      VALID_CATEGORIES = %w[transform validator display].freeze

      class << self
        def register(category, key, service)
          validate_category!(category)
          registries[category.to_s][key.to_s] = service
        end

        def lookup(category, key)
          validate_category!(category)
          registries[category.to_s][key.to_s]
        end

        def registered?(category, key)
          validate_category!(category)
          registries[category.to_s].key?(key.to_s)
        end

        def clear!
          @registries = nil
        end

        private

        def registries
          @registries ||= VALID_CATEGORIES.each_with_object({}) { |cat, h| h[cat] = {} }
        end

        def validate_category!(category)
          unless VALID_CATEGORIES.include?(category.to_s)
            raise ArgumentError, "Invalid service category '#{category}'. Valid: #{VALID_CATEGORIES.join(', ')}"
          end
        end
      end
    end
  end
end
