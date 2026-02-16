module LcpRuby
  module Types
    class TypeRegistry
      class << self
        def register(name, type_definition)
          registry[name.to_s] = type_definition
        end

        def resolve(name)
          registry[name.to_s]
        end

        def registered?(name)
          registry.key?(name.to_s)
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
