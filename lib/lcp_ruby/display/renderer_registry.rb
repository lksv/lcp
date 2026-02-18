module LcpRuby
  module Display
    class RendererRegistry
      class << self
        def renderer_for(key)
          registry[key.to_s]
        end

        def register(key, renderer_class)
          registry[key.to_s] = renderer_class.new
        end

        def registered?(key)
          registry.key?(key.to_s)
        end

        def discover!(base_path)
          renderers_path = File.join(base_path, "renderers")
          return unless File.directory?(renderers_path)

          Dir[File.join(renderers_path, "**", "*.rb")].sort.each do |file|
            require file

            relative = file.sub("#{renderers_path}/", "").sub(/\.rb$/, "")
            class_name = "LcpRuby::HostRenderers::#{relative.split('/').map(&:camelize).join('::')}"

            begin
              renderer_class = class_name.constantize
              register(relative, renderer_class)
            rescue NameError => e
              Rails.logger.warn("[LcpRuby] Could not register renderer #{class_name}: #{e.message}")
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
