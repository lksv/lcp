module LcpRuby
  module Events
    class HandlerRegistry
      class << self
        def handlers_for(model_name, event_name)
          registry.fetch(model_name.to_s, {}).fetch(event_name.to_s, [])
        end

        def register(model_name, event_name, handler_class)
          registry[model_name.to_s] ||= {}
          registry[model_name.to_s][event_name.to_s] ||= []
          registry[model_name.to_s][event_name.to_s] << handler_class
        end

        def discover!(base_path)
          handlers_path = File.join(base_path, "event_handlers")
          return unless File.directory?(handlers_path)

          Dir[File.join(handlers_path, "**", "*.rb")].sort.each do |file|
            require file

            relative = file.sub("#{handlers_path}/", "").sub(/\.rb$/, "")
            parts = relative.split("/")
            model_name = parts[0]
            class_name = "LcpRuby::HostEventHandlers::#{parts.map(&:camelize).join('::')}"

            begin
              handler_class = class_name.constantize
              event_name = handler_class.handles_event
              register(model_name, event_name, handler_class)
            rescue NameError, NotImplementedError => e
              Rails.logger.warn("[LcpRuby] Could not register event handler #{class_name}: #{e.message}")
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
