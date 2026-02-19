module LcpRuby
  module Services
    class Registry
      VALID_CATEGORIES = %w[transforms validators conditions defaults computed data_providers].freeze

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

        def discover!(base_path)
          services_path = File.join(base_path.to_s, "lcp_services")
          return unless File.directory?(services_path)

          VALID_CATEGORIES.each do |category|
            category_path = File.join(services_path, category)
            next unless File.directory?(category_path)

            Dir[File.join(category_path, "**", "*.rb")].sort.each do |file|
              # Files under app/lcp_services/ are developer-authored application code,
              # the same trust level as any other code in app/.
              require file

              relative = file.sub("#{category_path}/", "").sub(/\.rb$/, "")
              class_name = "LcpRuby::HostServices::#{category.camelize}::#{relative.split('/').map(&:camelize).join('::')}"

              begin
                service_class = class_name.constantize
                # Transforms use instance methods (def call), others use class methods (def self.call)
                service = category == "transforms" ? service_class.new : service_class
                register(category, relative, service)
              rescue NameError => e
                Rails.logger.warn("[LcpRuby] Could not register service #{class_name}: #{e.message}") if defined?(Rails)
              end
            end
          end
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
