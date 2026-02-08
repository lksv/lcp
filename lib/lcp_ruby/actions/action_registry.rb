module LcpRuby
  module Actions
    class ActionRegistry
      class << self
        def action_for(key)
          registry[key.to_s]
        end

        def register(key, action_class)
          registry[key.to_s] = action_class
        end

        def registered?(key)
          registry.key?(key.to_s)
        end

        def discover!(base_path)
          actions_path = File.join(base_path, "actions")
          return unless File.directory?(actions_path)

          Dir[File.join(actions_path, "**", "*.rb")].sort.each do |file|
            require file

            relative = file.sub("#{actions_path}/", "").sub(/\.rb$/, "")
            class_name = "LcpRuby::HostActions::#{relative.split('/').map(&:camelize).join('::')}"

            begin
              action_class = class_name.constantize
              register(relative, action_class)
            rescue NameError => e
              Rails.logger.warn("[LcpRuby] Could not register action #{class_name}: #{e.message}")
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
end
