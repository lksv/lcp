module LcpRuby
  class ConditionServiceRegistry
    class << self
      def register(key, service)
        registry[key.to_s] = service
        Services::Registry.register("conditions", key, service) if defined?(Services::Registry)
      end

      def lookup(key)
        registry[key.to_s]
      end

      def registered?(key)
        registry.key?(key.to_s)
      end

      def discover!(base_path)
        services_path = File.join(base_path, "condition_services")
        return unless File.directory?(services_path)

        Dir[File.join(services_path, "**", "*.rb")].sort.each do |file|
          require file

          relative = file.sub("#{services_path}/", "").sub(/\.rb$/, "")
          class_name = "LcpRuby::HostConditionServices::#{relative.split('/').map(&:camelize).join('::')}"

          begin
            service_class = class_name.constantize
            register(relative, service_class)
          rescue NameError => e
            Rails.logger.warn("[LcpRuby] Could not register condition service #{class_name}: #{e.message}")
          end
        end
      end

      def clear!
        @registry = {}
      end

      private

      def registry
        @registry ||= {}
      end
    end
  end
end
